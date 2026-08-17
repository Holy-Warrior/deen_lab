// Network (IP-based) geolocation -- the middle rung of the frontend's location ladder.
//
// Design: this exists purely as a fallback for when the device's real GPS stack can't be
// used (location services switched off, permission denied, no location provider at all).
// It is deliberately NOT a substitute for tauri-plugin-geolocation: an IP lookup resolves to
// roughly the right city, which is good enough to compute prayer times and a Qibla bearing
// that are usefully close, but it is not a position fix and must never be presented as one.
// See DeviceLocation.svelte, which labels this state "approximate" rather than "active".
//
// Why Rust rather than a fetch() on the frontend: it keeps the provider URL, the response
// shape, and the success/failure semantics in one place the WebView can't see or tamper
// with, and it reuses the shared reqwest client that every other backend request already
// goes through.
use crate::api_cache::HttpClient;
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tauri::State;

/// ipwho.is: free, no API key, HTTPS, and returns coordinates plus a city/country label in
/// one call. Chosen over ipapi.co and freeipapi.com, both of which sit behind a Cloudflare
/// challenge that a plain client can't get past.
const PROVIDER_URL: &str = "https://ipwho.is/";

/// A lookup shouldn't be able to hang the UI -- this path only runs after GPS has already
/// failed, so the user is waiting on it with nothing else on screen.
const TIMEOUT: Duration = Duration::from_secs(8);

#[derive(Serialize)]
pub struct IpLocation {
    pub latitude: f64,
    pub longitude: f64,
    pub city: String,
    pub country: String,
}

#[derive(Deserialize)]
struct ProviderResponse {
    /// ipwho.is signals failure in the body with `success: false` and HTTP 200, so the status
    /// code alone is not enough to tell a good response from a bad one.
    success: Option<bool>,
    message: Option<String>,
    latitude: Option<f64>,
    longitude: Option<f64>,
    city: Option<String>,
    country: Option<String>,
}

/// Resolves an approximate position from the caller's public IP address.
///
/// Errors are plain strings, matching the convention the other commands use, so the frontend
/// can surface them the same way.
#[tauri::command]
pub async fn ip_location(client: State<'_, HttpClient>) -> Result<IpLocation, String> {
    let response = client
        .0
        .get(PROVIDER_URL)
        .timeout(TIMEOUT)
        .send()
        .await
        .map_err(|error| format!("Network location lookup failed: {error}"))?;

    if !response.status().is_success() {
        return Err(format!(
            "Network location lookup failed with status {}",
            response.status().as_u16()
        ));
    }

    let body: ProviderResponse = response
        .json()
        .await
        .map_err(|error| format!("Unable to read the network location response: {error}"))?;

    if body.success == Some(false) {
        let detail = body.message.unwrap_or_else(|| "unknown reason".into());
        return Err(format!("Network location unavailable: {detail}"));
    }

    // A response missing coordinates is useless to every caller, so treat it as a failure here
    // rather than handing back a (0, 0) position that would silently point at the Gulf of Guinea.
    let (latitude, longitude) = match (body.latitude, body.longitude) {
        (Some(latitude), Some(longitude)) => (latitude, longitude),
        _ => return Err("Network location response had no coordinates.".into()),
    };

    Ok(IpLocation {
        latitude,
        longitude,
        city: body.city.unwrap_or_default(),
        country: body.country.unwrap_or_default(),
    })
}
