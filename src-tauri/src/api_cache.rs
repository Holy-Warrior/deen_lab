// Generic API request + disk cache for the frontend.
//
// Design: two commands, deliberately kept separate.
//   - api_request        always hits the network; optionally caches the
//                         response data to disk, keyed by the URL.
//                         Caching the same URL again overwrites whatever
//                         was cached before -- one value per URL, no
//                         history.
//   - get_cached_response only ever reads from disk, never touches the
//                         network. Pass the same URL you would fetch to
//                         look up whatever was last cached for it.
//
// Pattern this enables on the frontend: call get_cached_response(url)
// first to paint instantly with whatever we have, then call
// api_request(url, ..., cache: true) in the background to refresh it.
// If api_request fails (offline, server down), the UI already has the
// cached data and is unaffected.
use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::PathBuf;
use tauri::{AppHandle, Manager, State};
/// Shared HTTP client, reused across every call so we are not paying
/// TLS/DNS setup cost on every single request.
pub struct HttpClient(pub reqwest::Client);
impl Default for HttpClient {
    fn default() -> Self {
        HttpClient(reqwest::Client::new())
    }
}
/// Every URL maps to exactly one cache file. URLs contain characters
/// that are not safe in filenames and can be arbitrarily long, so we
/// hash them down to a fixed-length, filesystem-safe key. The same URL
/// always produces the same key, which is what lets get_cached_response
/// and api_request agree on where to look without the frontend having
/// to track a separate cache key.
fn cache_key_for_url(url: &str) -> String {
    let mut hasher = DefaultHasher::new();
    url.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}
fn cache_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|error| format!("Unable to resolve app data directory: {error}"))?
        .join("api_cache");
    fs::create_dir_all(&dir)
        .map_err(|error| format!("Unable to create cache directory: {error}"))?;
    Ok(dir)
}
fn cache_file_path(app: &AppHandle, url: &str) -> Result<PathBuf, String> {
    Ok(cache_dir(app)?.join(format!("{}.json", cache_key_for_url(url))))
}
fn write_cache(app: &AppHandle, url: &str, data: &serde_json::Value) -> Result<(), String> {
    let path = cache_file_path(app, url)?;
    let tmp_path = path.with_extension("json.tmp");
    let serialized = serde_json::to_vec(data)
        .map_err(|error| format!("Unable to serialize cache data: {error}"))?;
    fs::write(&tmp_path, serialized)
        .map_err(|error| format!("Unable to write cache file: {error}"))?;
    // Atomically replaces any existing cache file for this URL.
    fs::rename(&tmp_path, &path)
        .map_err(|error| format!("Unable to finalize cache file: {error}"))?;
    Ok(())
}
/// Makes an HTTP request to url and, optionally, caches the response
/// data to disk (keyed by the url itself) for later retrieval via
/// get_cached_response. Caching the same url again replaces whatever
/// was cached before.
///
/// This function ALWAYS hits the network. It never reads from the cache
/// itself -- pair it with get_cached_response on the frontend so the UI
/// can show cached data immediately while this call refreshes it.
#[tauri::command]
pub async fn api_request(
    app: AppHandle,
    client: State<'_, HttpClient>,
    url: String,
    method: Option<String>,
    headers: Option<HashMap<String, String>>,
    body: Option<serde_json::Value>,
    cache: bool,
) -> Result<serde_json::Value, String> {
    let http_method = match method
        .unwrap_or_else(|| "GET".to_string())
        .to_uppercase()
        .as_str()
    {
        "GET" => reqwest::Method::GET,
        "POST" => reqwest::Method::POST,
        "PUT" => reqwest::Method::PUT,
        "PATCH" => reqwest::Method::PATCH,
        "DELETE" => reqwest::Method::DELETE,
        "HEAD" => reqwest::Method::HEAD,
        other => return Err(format!("Unsupported HTTP method: {other}")),
    };
    let mut request = client.0.request(http_method, url.as_str());
    if let Some(headers) = headers {
        for (key, value) in headers {
            request = request.header(key, value);
        }
    }
    if let Some(body) = &body {
        request = request.json(body);
    }
    let response = request
        .send()
        .await
        .map_err(|error| format!("Request failed: {error}"))?;
    let status = response.status();
    let text = response
        .text()
        .await
        .map_err(|error| format!("Unable to read response body: {error}"))?;
    if !status.is_success() {
        let snippet: String = text.chars().take(500).collect();
        return Err(format!("Request failed with status {}: {snippet}", status.as_u16()));
    }
    let data: serde_json::Value =
        serde_json::from_str(&text).unwrap_or(serde_json::Value::String(text));
    if cache {
        write_cache(&app, &url, &data)?;
    }
    Ok(data)
}
/// Reads whatever was last cached for url from disk. Never touches the
/// network. Returns Ok(None) if nothing has been cached yet for this
/// url (or the cache entry was corrupted), so the frontend can treat
/// "no cache" as a normal state rather than an error.
#[tauri::command]
pub fn get_cached_response(app: AppHandle, url: String) -> Result<Option<serde_json::Value>, String> {
    let path = cache_file_path(&app, &url)?;
    if !path.exists() {
        return Ok(None);
    }
    let raw = match fs::read(&path) {
        Ok(raw) => raw,
        Err(_) => return Ok(None),
    };
    match serde_json::from_slice::<serde_json::Value>(&raw) {
        Ok(data) => Ok(Some(data)),
        Err(_) => {
            let _ = fs::remove_file(&path);
            Ok(None)
        }
    }
}
