// Hadith storage, installation and querying over the downloaded SQLite bundles.
//
// See docs/hadith-data.md for the bundle format. In short: one gzipped SQLite file per
// collection, either `full` (readable text + search) or `index` (contentless locator index for
// collections the user has not downloaded). Both live under <app_data>/hadith/.
//
// Bundles are opened read-only, one connection per query. They are a few MB each and queries
// are user-driven, so a connection pool would add complexity for no measurable gain.
use rusqlite::{Connection, OpenFlags};
use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Manager};
use unicode_normalization::UnicodeNormalization;

const HADITH_DIR: &str = "hadith";

// ---------------------------------------------------------------------------------------------
// Arabic normalisation
// ---------------------------------------------------------------------------------------------

/// MUST stay byte-for-byte equivalent to `normalize_arabic()` in tools/hadith/build_bundles.py.
///
/// The corpus is fully vowelled and users type undiacritized Arabic; FTS5 cannot bridge that
/// (its `remove_diacritics 2` is Latin-only). Queries are therefore normalised the same way the
/// index was. A divergence between the two implementations raises no error -- searches just
/// silently return nothing -- which is exactly why this is spelled out rather than inlined.
pub fn normalize_arabic(input: &str) -> String {
    input
        .nfd()
        // Mn = "Mark, nonspacing". NFD splits hamza-carrying alefs (أ إ آ) into alef plus a
        // combining mark, so dropping Mn removes harakat and folds those forms in one pass.
        .filter(|ch| !is_nonspacing_mark(*ch))
        .filter(|ch| *ch != '\u{0640}') // tatweel: cosmetic letter-stretching, never semantic
        .map(|ch| match ch {
            '\u{0671}' => '\u{0627}', // alef wasla -> alef (not decomposable, needs mapping)
            '\u{0649}' => '\u{064A}', // alef maqsura -> yeh
            '\u{0629}' => '\u{0647}', // ta marbuta -> heh
            other => other,
        })
        .collect()
}

/// Combining-mark ranges that matter for Arabic. Checked explicitly rather than pulling in a
/// full Unicode-category table, which would be a large dependency for a handful of ranges.
fn is_nonspacing_mark(ch: char) -> bool {
    matches!(ch as u32,
        0x0300..=0x036F | // combining diacritical marks (from NFD-decomposed hamza forms)
        0x0610..=0x061A | // Arabic honorifics
        0x064B..=0x065F | // harakat: fathatan..wavy hamza below
        0x0670 |          // superscript alef
        0x06D6..=0x06DC | // Quranic annotation marks
        0x06DF..=0x06E8 |
        0x06EA..=0x06ED
    )
}

/// FTS5 treats bare terms as exact tokens, and Arabic fuses articles/prepositions onto words --
/// Bukhari 1 has `بالنيات`, never a standalone `النية`. Appending `*` recovers that recall.
/// Also strips FTS5 syntax so a user typing a quote or `*` can't produce a malformed query.
fn to_prefix_query(query: &str, arabic: bool) -> String {
    let cleaned: String = query
        .chars()
        .map(|ch| if "\"'*()^:-".contains(ch) { ' ' } else { ch })
        .collect();

    let terms: Vec<String> = cleaned
        .split_whitespace()
        .filter(|term| !term.is_empty())
        .map(|term| if arabic { format!("{term}*") } else { format!("\"{term}\"*") })
        .collect();

    terms.join(" ")
}

fn looks_arabic(text: &str) -> bool {
    text.chars().any(|ch| matches!(ch as u32, 0x0600..=0x06FF | 0x0750..=0x077F))
}

// ---------------------------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------------------------

fn hadith_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|error| format!("Unable to resolve app data directory: {error}"))?
        .join(HADITH_DIR);
    fs::create_dir_all(&dir).map_err(|error| format!("Unable to create hadith directory: {error}"))?;
    Ok(dir)
}

fn bundle_path(app: &AppHandle, slug: &str, kind: &str) -> Result<PathBuf, String> {
    if !slug.chars().all(|c| c.is_ascii_alphanumeric()) {
        return Err(format!("invalid collection slug: {slug}"));
    }
    if kind != "full" && kind != "index" {
        return Err(format!("invalid bundle kind: {kind}"));
    }
    Ok(hadith_dir(app)?.join(format!("{slug}.{kind}.db")))
}

fn open_readonly(path: &Path) -> Result<Connection, String> {
    Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY)
        .map_err(|error| format!("Unable to open {}: {error}", path.display()))
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InstalledBundle {
    pub slug: String,
    pub kind: String,
    pub bytes: u64,
}

/// Everything currently on disk, with real byte sizes -- the storage screen is built from this
/// rather than from the manifest, so it reflects what is actually occupying space.
#[tauri::command]
pub fn hadith_installed(app: AppHandle) -> Result<Vec<InstalledBundle>, String> {
    let dir = hadith_dir(&app)?;
    let mut out = Vec::new();

    for entry in fs::read_dir(&dir).map_err(|error| format!("Unable to read storage: {error}"))? {
        let entry = entry.map_err(|error| format!("Unable to read entry: {error}"))?;
        let name = entry.file_name().to_string_lossy().into_owned();
        // "<slug>.<kind>.db" -- anything else (a stray .part, say) is ignored rather than
        // reported as an installed bundle
        let parts: Vec<&str> = name.trim_end_matches(".db").split('.').collect();
        if !name.ends_with(".db") || parts.len() != 2 {
            continue;
        }
        let bytes = entry.metadata().map(|m| m.len()).unwrap_or(0);
        out.push(InstalledBundle { slug: parts[0].into(), kind: parts[1].into(), bytes });
    }

    out.sort_by(|a, b| a.slug.cmp(&b.slug).then(a.kind.cmp(&b.kind)));
    Ok(out)
}

/// Decompresses a downloaded `.gz` into place and verifies it is a usable bundle before
/// committing. Deletes the archive afterwards -- keeping it would double the space used for no
/// benefit, since a re-download is cheap and checksummed.
#[tauri::command]
pub fn hadith_install(app: AppHandle, slug: String, kind: String, archive: String) -> Result<u64, String> {
    let target = bundle_path(&app, &slug, &kind)?;
    let archive_path = PathBuf::from(&archive);

    let file = fs::File::open(&archive_path)
        .map_err(|error| format!("Unable to open downloaded archive: {error}"))?;
    let mut decoder = flate2::read::GzDecoder::new(file);

    let staging = target.with_extension("staging");
    let mut out = fs::File::create(&staging)
        .map_err(|error| format!("Unable to create bundle file: {error}"))?;
    std::io::copy(&mut decoder, &mut out)
        .map_err(|error| format!("Unable to decompress bundle: {error}"))?;
    drop(out);

    // Prove it opens and has the expected shape before replacing anything already installed.
    let verify = || -> Result<(), String> {
        let conn = open_readonly(&staging)?;
        let table = if kind == "full" { "hadiths" } else { "refs" };
        conn.query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |row| row.get::<_, i64>(0))
            .map_err(|error| format!("Bundle failed validation: {error}"))?;
        Ok(())
    };
    if let Err(error) = verify() {
        let _ = fs::remove_file(&staging);
        return Err(error);
    }

    fs::rename(&staging, &target)
        .map_err(|error| format!("Unable to install bundle: {error}"))?;
    let _ = fs::remove_file(&archive_path);

    fs::metadata(&target).map(|m| m.len()).map_err(|error| format!("Unable to stat bundle: {error}"))
}

/// Removes a collection. Its search index goes with it -- the two are one unit, so search can
/// never reference text the device no longer has.
#[tauri::command]
pub fn hadith_delete(app: AppHandle, slug: String) -> Result<u64, String> {
    let mut freed = 0u64;
    for kind in ["full", "index"] {
        let path = bundle_path(&app, &slug, kind)?;
        if path.exists() {
            freed += fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
            fs::remove_file(&path).map_err(|error| format!("Unable to delete bundle: {error}"))?;
        }
    }
    Ok(freed)
}

// ---------------------------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------------------------

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Book {
    pub book_no: String,
    pub book_en: String,
    pub book_ar: String,
    pub hadith_count: i64,
    pub chapter_count: i64,
}

#[tauri::command]
pub fn hadith_books(app: AppHandle, slug: String) -> Result<Vec<Book>, String> {
    let conn = open_readonly(&bundle_path(&app, &slug, "full")?)?;
    let mut stmt = conn
        .prepare("SELECT book_no, book_en, book_ar, hadith_count, chapter_count FROM books ORDER BY sort_order")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map([], |row| {
            Ok(Book {
                book_no: row.get(0)?,
                book_en: row.get(1)?,
                book_ar: row.get(2)?,
                hadith_count: row.get(3)?,
                chapter_count: row.get(4)?,
            })
        })
        .map_err(|e| e.to_string())?;
    rows.collect::<Result<_, _>>().map_err(|e| e.to_string())
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Hadith {
    pub rowid: i64,
    pub hadith_id: String,
    pub hadith_no_in_book: String,
    pub book_no: String,
    pub chapter_no: String,
    pub narrator_en: String,
    pub text_en: String,
    pub arabic_sanad: String,
    pub arabic_matn: String,
    pub gradings: String,
    pub ref_raw: String,
}

const HADITH_COLUMNS: &str = "rowid_, hadith_id, hadith_no_in_book, book_no, chapter_no, \
     narrator_en, text_en, arabic_sanad, arabic_matn, gradings, ref_raw";

fn map_hadith(row: &rusqlite::Row) -> rusqlite::Result<Hadith> {
    Ok(Hadith {
        rowid: row.get(0)?,
        hadith_id: row.get(1)?,
        hadith_no_in_book: row.get(2)?,
        book_no: row.get(3)?,
        chapter_no: row.get(4)?,
        narrator_en: row.get(5)?,
        text_en: row.get(6)?,
        arabic_sanad: row.get(7)?,
        arabic_matn: row.get(8)?,
        gradings: row.get(9)?,
        ref_raw: row.get(10)?,
    })
}

/// A book's hadiths, paged. Books run to a few hundred entries, so paging keeps the first paint
/// fast rather than serialising an entire book across the IPC boundary at once.
#[tauri::command]
pub fn hadith_by_book(
    app: AppHandle, slug: String, book_no: String, limit: i64, offset: i64,
) -> Result<Vec<Hadith>, String> {
    let conn = open_readonly(&bundle_path(&app, &slug, "full")?)?;
    let mut stmt = conn
        .prepare(&format!(
            "SELECT {HADITH_COLUMNS} FROM hadiths WHERE book_no = ?1 ORDER BY rowid_ LIMIT ?2 OFFSET ?3"
        ))
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(rusqlite::params![book_no, limit, offset], map_hadith)
        .map_err(|e| e.to_string())?;
    rows.collect::<Result<_, _>>().map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------------------------

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SearchHit {
    pub slug: String,
    pub hadith_id: String,
    pub book_no: String,
    pub chapter_no: String,
    pub ref_raw: String,
    /// Empty for index-only collections: a contentless FTS index stores no text, so a hit there
    /// can be located but not previewed. The UI turns this into a "download to read" prompt.
    pub text_en: String,
    pub narrator_en: String,
    /// False when the hit came from an index-only bundle.
    pub readable: bool,
}

/// Searches one installed bundle. `book_no` scopes to a single book when supplied, which is what
/// makes the search bar inside a book default to that book.
fn search_bundle(
    path: &Path, slug: &str, query: &str, book_no: Option<&str>, limit: i64, readable: bool,
) -> Result<Vec<SearchHit>, String> {
    let conn = open_readonly(path)?;
    let arabic = looks_arabic(query);
    let match_expr = if arabic {
        to_prefix_query(&normalize_arabic(query), true)
    } else {
        to_prefix_query(query, false)
    };
    if match_expr.is_empty() {
        return Ok(Vec::new());
    }

    let fts_table = if arabic { "search_ar" } else { "search" };
    // `full` bundles carry the text in `hadiths`; `index` bundles only have locators in `refs`.
    let sql = if readable {
        format!(
            "SELECT h.hadith_id, h.book_no, h.chapter_no, h.ref_raw, h.text_en, h.narrator_en \
             FROM {fts_table} f JOIN hadiths h ON h.rowid_ = f.rowid \
             WHERE {fts_table} MATCH ?1 {} ORDER BY rank LIMIT ?2",
            if book_no.is_some() { "AND h.book_no = ?3" } else { "" }
        )
    } else {
        format!(
            "SELECT r.hadith_id, r.book_no, r.chapter_no, r.ref_raw, '' , '' \
             FROM {fts_table} f JOIN refs r ON r.rowid_ = f.rowid \
             WHERE {fts_table} MATCH ?1 {} ORDER BY rank LIMIT ?2",
            if book_no.is_some() { "AND r.book_no = ?3" } else { "" }
        )
    };

    let mut stmt = conn.prepare(&sql).map_err(|e| e.to_string())?;
    let build = |row: &rusqlite::Row| -> rusqlite::Result<SearchHit> {
        Ok(SearchHit {
            slug: slug.to_string(),
            hadith_id: row.get(0)?,
            book_no: row.get(1)?,
            chapter_no: row.get(2)?,
            ref_raw: row.get(3)?,
            text_en: row.get(4)?,
            narrator_en: row.get(5)?,
            readable,
        })
    };

    let rows: Result<Vec<SearchHit>, _> = match book_no {
        Some(book) => stmt
            .query_map(rusqlite::params![match_expr, limit, book], build)
            .map_err(|e| e.to_string())?
            .collect(),
        None => stmt
            .query_map(rusqlite::params![match_expr, limit], build)
            .map_err(|e| e.to_string())?
            .collect(),
    };
    rows.map_err(|e| e.to_string())
}

/// Searches across installed bundles.
///
/// `slugs` empty means "everything installed". Scoping to one collection or one book is the
/// same code path with a narrower input, which is what lets the search bar change scope by
/// context (whole library / one collection / one book) without a separate query for each.
#[tauri::command]
pub fn hadith_search(
    app: AppHandle, query: String, slugs: Vec<String>, book_no: Option<String>, limit: Option<i64>,
) -> Result<Vec<SearchHit>, String> {
    if query.trim().is_empty() {
        return Ok(Vec::new());
    }
    let limit = limit.unwrap_or(50).clamp(1, 200);
    let installed = hadith_installed(app.clone())?;

    let wanted: Vec<String> = if slugs.is_empty() {
        let mut all: Vec<String> = installed.iter().map(|b| b.slug.clone()).collect();
        all.sort();
        all.dedup();
        all
    } else {
        slugs
    };

    let mut hits = Vec::new();
    for slug in wanted {
        // Prefer the full bundle: it can show the matching text. Fall back to index-only, which
        // still locates the hadith so the UI can offer the download.
        let full = bundle_path(&app, &slug, "full")?;
        let index = bundle_path(&app, &slug, "index")?;
        let (path, readable) = if full.exists() {
            (full, true)
        } else if index.exists() {
            (index, false)
        } else {
            continue;
        };

        match search_bundle(&path, &slug, &query, book_no.as_deref(), limit, readable) {
            Ok(mut found) => hits.append(&mut found),
            // One corrupt bundle shouldn't sink a whole-library search.
            Err(error) => eprintln!("hadith search failed for {slug}: {error}"),
        }
    }

    hits.truncate(limit as usize * 2);
    Ok(hits)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_harakat_and_folds_letter_variants() {
        // "الْأَعْمَالُ" as it appears in Bukhari 1 -> what a user actually types
        assert_eq!(normalize_arabic("الْأَعْمَالُ"), "الاعمال");
        assert_eq!(normalize_arabic("ٱلصَّلَاةِ"), "الصلاه"); // alef wasla + ta marbuta folded
        assert_eq!(normalize_arabic("عَلَىٰ"), "علي"); // alef maqsura -> yeh
        assert_eq!(normalize_arabic("مُحَمَّـــد"), "محمد"); // tatweel removed
    }

    #[test]
    fn builds_prefix_queries_and_rejects_fts_syntax() {
        assert_eq!(to_prefix_query("الاعمال", true), "الاعمال*");
        assert_eq!(to_prefix_query("intentions", false), "\"intentions\"*");
        // a stray quote must not produce a malformed MATCH expression
        assert_eq!(to_prefix_query("a\"b", false), "\"a\"* \"b\"*");
        assert_eq!(to_prefix_query("   ", false), "");
    }
}
