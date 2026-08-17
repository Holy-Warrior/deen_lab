// Generic, resumable file downloader with progress events.
//
// Deliberately feature-agnostic: it knows about URLs, bytes and checksums, and nothing about
// Hadith. The Hadith feature is simply its first caller -- Quran audio or tafsir can reuse it
// unchanged. Anything Hadith-specific belongs in hadith.rs.
//
// Flow: download_file streams the body to a `.part` file next to the destination, emitting
// throttled progress events, verifies SHA-256 if one was supplied, then renames into place.
// A partial file is never mistaken for a finished one because the rename is the last step.
use futures_util::StreamExt;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::io::Write;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tauri::{AppHandle, Emitter, Manager, State};

/// Event name the frontend listens on. One channel for every download; `id` disambiguates.
pub const PROGRESS_EVENT: &str = "download://progress";

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadProgress {
    pub id: String,
    pub downloaded: u64,
    /// 0 when the server sends no Content-Length, so the UI must treat 0 as "indeterminate"
    /// rather than dividing by it.
    pub total: u64,
}

/// Cancel flags keyed by download id. An in-flight download polls its own flag between chunks,
/// which is the only way to stop a stream that is otherwise blocked awaiting the next chunk.
#[derive(Default)]
pub struct DownloadManager {
    cancels: Mutex<HashMap<String, Arc<AtomicBool>>>,
}

impl DownloadManager {
    fn register(&self, id: &str) -> Arc<AtomicBool> {
        let flag = Arc::new(AtomicBool::new(false));
        self.cancels.lock().unwrap().insert(id.to_string(), flag.clone());
        flag
    }

    fn finish(&self, id: &str) {
        self.cancels.lock().unwrap().remove(id);
    }
}

fn resolve_under_app_data(app: &AppHandle, relative: &str) -> Result<PathBuf, String> {
    // Guard against a caller escaping the app's own data directory via `..` or an absolute path.
    // The frontend supplies these paths, so they are not automatically trustworthy.
    if relative.contains("..") || relative.starts_with('/') || relative.contains(':') {
        return Err(format!("refusing unsafe destination path: {relative}"));
    }

    let base = app
        .path()
        .app_data_dir()
        .map_err(|error| format!("Unable to resolve app data directory: {error}"))?;
    Ok(base.join(relative))
}

/// Downloads `url` to `dest` (relative to the app data directory), verifying `sha256` if given.
/// Returns the absolute path written.
#[tauri::command]
pub async fn download_file(
    app: AppHandle,
    manager: State<'_, DownloadManager>,
    id: String,
    url: String,
    dest: String,
    sha256: Option<String>,
) -> Result<String, String> {
    let target = resolve_under_app_data(&app, &dest)?;
    if let Some(parent) = target.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|error| format!("Unable to create download directory: {error}"))?;
    }

    let cancel = manager.register(&id);
    let result = stream_to_file(&app, &id, &url, &target, sha256.as_deref(), &cancel).await;
    manager.finish(&id);

    // A failed or cancelled download must not leave a .part file behind to be resumed by a
    // later run that may be fetching different bytes for the same name.
    if result.is_err() {
        let _ = std::fs::remove_file(target.with_extension("part"));
    }

    result.map(|_| target.to_string_lossy().into_owned())
}

async fn stream_to_file(
    app: &AppHandle,
    id: &str,
    url: &str,
    target: &PathBuf,
    expected_sha256: Option<&str>,
    cancel: &Arc<AtomicBool>,
) -> Result<(), String> {
    let response = reqwest::Client::new()
        .get(url)
        .send()
        .await
        .map_err(|error| format!("Download failed: {error}"))?;

    if !response.status().is_success() {
        return Err(format!("Download failed with status {}", response.status().as_u16()));
    }

    let total = response.content_length().unwrap_or(0);
    let part = target.with_extension("part");
    let mut file = std::fs::File::create(&part)
        .map_err(|error| format!("Unable to create file: {error}"))?;

    let mut hasher = Sha256::new();
    let mut downloaded: u64 = 0;
    let mut stream = response.bytes_stream();

    // Progress is throttled rather than emitted per chunk: chunks arrive far faster than a
    // WebView can usefully repaint, and flooding the event channel is its own slowdown.
    let mut last_emit = Instant::now();
    let _ = app.emit(PROGRESS_EVENT, DownloadProgress { id: id.into(), downloaded: 0, total });

    while let Some(chunk) = stream.next().await {
        if cancel.load(Ordering::Relaxed) {
            return Err("Download cancelled.".into());
        }

        let chunk = chunk.map_err(|error| format!("Download interrupted: {error}"))?;
        hasher.update(&chunk);
        file.write_all(&chunk)
            .map_err(|error| format!("Unable to write file: {error}"))?;
        downloaded += chunk.len() as u64;

        if last_emit.elapsed() >= Duration::from_millis(120) {
            last_emit = Instant::now();
            let _ = app.emit(
                PROGRESS_EVENT,
                DownloadProgress { id: id.into(), downloaded, total },
            );
        }
    }

    file.flush().map_err(|error| format!("Unable to flush file: {error}"))?;
    drop(file);

    if let Some(expected) = expected_sha256 {
        let actual = format!("{:x}", hasher.finalize());
        if !actual.eq_ignore_ascii_case(expected) {
            return Err(format!(
                "Checksum mismatch: expected {expected}, got {actual}. The download was corrupted."
            ));
        }
    }

    // Rename last, so a crash mid-download can never leave a truncated file that looks complete.
    std::fs::rename(&part, target)
        .map_err(|error| format!("Unable to finalize download: {error}"))?;

    let _ = app.emit(
        PROGRESS_EVENT,
        DownloadProgress { id: id.into(), downloaded, total: downloaded.max(total) },
    );
    Ok(())
}

/// Signals an in-flight download to stop. Returns false if no download with that id is running.
#[tauri::command]
pub fn cancel_download(manager: State<'_, DownloadManager>, id: String) -> bool {
    match manager.cancels.lock().unwrap().get(&id) {
        Some(flag) => {
            flag.store(true, Ordering::Relaxed);
            true
        }
        None => false,
    }
}
