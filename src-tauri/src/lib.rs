mod api_cache;
mod groq_config;
use serde::{Deserialize, Serialize};
const FEATURE_STUDIO_PROMPT: &str = r#"
You are the DeenLab Feature Studio. Decide whether a request is for a small, useful Deen-related interactive feature.
Accept only Islamic learning, worship, reflection, habits, Quran, Hadith, duas, dhikr, prayer, fasting, qibla, charity, or similar beneficial utilities. Reject anything involving authentication, payment, external APIs, remote assets, external scripts, backend servers, or unrelated content.
If accepted, generate one polished, self-contained HTML document. It must use no network resources, no external scripts, and no external stylesheets. Make it keyboard-friendly and responsive. Use a dark zinc-and-emerald visual system that matches DeenLab. Include any required CSS and JavaScript in the document itself.
Respond with JSON only in exactly this shape:
{"decision":"generate"|"decline","title":"short title","message":"brief explanation","html":"complete HTML or empty string"}
"#;
#[derive(Deserialize)]
struct GroqMessage {
    content: String,
}
#[derive(Deserialize)]
struct GroqChoice {
    message: GroqMessage,
}
#[derive(Deserialize)]
struct GroqResponse {
    choices: Vec<GroqChoice>,
}
#[derive(Serialize, Deserialize)]
struct FeatureBuildResult {
    decision: String,
    title: String,
    message: String,
    html: String,
}
#[tauri::command]
async fn build_feature(prompt: String) -> Result<FeatureBuildResult, String> {
    let prompt = prompt.trim();
    if prompt.is_empty() {
        return Err("Describe the feature you would like to create.".into());
    }
    if groq_config::API_KEY.trim().is_empty() {
        return Err("Groq is not configured. Copy src-tauri/src/groq_config.example.rs to groq_config.rs and add your API key.".into());
    }
    let request_body = serde_json::json!({
        "model": groq_config::MODEL,
        "temperature": 0.3,
        "max_completion_tokens": 3000,
        "response_format": { "type": "json_object" },
        "messages": [
            { "role": "system", "content": FEATURE_STUDIO_PROMPT },
            { "role": "user", "content": prompt }
        ]
    });
    let response = reqwest::Client::new()
        .post("https://api.groq.com/openai/v1/chat/completions")
        .bearer_auth(groq_config::API_KEY)
        .json(&request_body)
        .send()
        .await
        .map_err(|error| format!("Unable to contact Groq: {error}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let detail = response.text().await.unwrap_or_default();
        return Err(format!("Groq request failed ({status}): {detail}"));
    }
    let response: GroqResponse = response
        .json()
        .await
        .map_err(|error| format!("Unable to read the Groq response: {error}"))?;
    let content = response
        .choices
        .first()
        .map(|choice| choice.message.content.as_str())
        .ok_or("Groq returned no response.")?;
    let result: FeatureBuildResult = serde_json::from_str(content)
        .map_err(|error| format!("Groq returned invalid feature data: {error}"))?;
    if result.decision != "generate" && result.decision != "decline" {
        return Err("Groq returned an unsupported decision.".into());
    }
    if result.decision == "generate" && result.html.trim().is_empty() {
        return Err("Groq generated a feature without HTML.".into());
    }
    Ok(result)
}
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|_app| {
            // rust: _app is only used inside this cfg-gated block -- the underscore
            // prefix keeps desktop builds (where the block compiles out) warning-free
            #[cfg(target_os = "android")]
            {
                _app.handle().plugin(tauri_plugin_geolocation::init())?;
            }
            Ok(())
        })
        .manage(api_cache::HttpClient::default())
        .invoke_handler(tauri::generate_handler![
            build_feature,
            api_cache::api_request,
            api_cache::get_cached_response
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}