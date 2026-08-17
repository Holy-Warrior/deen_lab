mod api_cache;
mod groq_config;
mod ip_location;
use serde::{Deserialize, Serialize};
/// One model in the fallback chain.
struct ModelSpec {
    id: &'static str,
    /// `gpt-oss` models think before answering and bill that thinking against the completion
    /// budget, so "low" spends the budget on markup instead. Not universal: qwen uses a
    /// different mechanism entirely and `groq/compound` rejects the parameter with a 400,
    /// so it is per-model rather than a global setting.
    reasoning_effort: Option<&'static str>,
}

// groq: the chain lives here rather than in groq_config.rs so it stays under version control --
// groq_config.rs is gitignored and holds only the secret. Groq retires models fairly often, so
// a 404 from the API usually means this list needs updating against
// https://api.groq.com/openai/v1/models rather than anything being wrong locally; the previously
// configured llama-3.3-70b-versatile was decommissioned exactly that way.
//
// The order is best-for-the-job first, and for this job that means fastest-at-equal-quality
// rather than largest: gpt-oss-20b answers in ~1.2s against ~1.8-2.5s for the 120b, and across
// the validation prompts neither produced a measurably better feature. 120b sits second as the
// heavier backstop, and qwen last -- it writes the most detailed markup but takes ~5s.
//
// Falling back is worth doing at all because the per-minute token allowance is measured to be
// **per model, not per account**: with gpt-oss-120b returning 429, both gpt-oss-20b and qwen
// still answered immediately. Three models therefore carry roughly three times the capacity of
// one, and a 429 costs only ~0.2s before the next model is tried.
const MODEL_CHAIN: &[ModelSpec] = &[
    ModelSpec { id: "openai/gpt-oss-20b", reasoning_effort: Some("low") },
    ModelSpec { id: "openai/gpt-oss-120b", reasoning_effort: Some("low") },
    ModelSpec { id: "qwen/qwen3.6-27b", reasoning_effort: None },
];

/// How many times to walk the whole chain before giving up.
const MAX_ROUNDS: usize = 2;

/// Ceiling on any single wait between rounds. Without background execution the user is watching
/// a spinner, so a long wait is worse than an honest "try again in a moment".
const MAX_WAIT_SECONDS: u64 = 45;

// groq: the free plan reserves prompt + max_completion_tokens against one per-minute allowance
// (8000 TPM per model) before generating anything, so this budget is a throughput decision as
// much as a size cap -- a larger number here means fewer builds per minute, not better output.
//
// It is sized against the system prompt, which is ~920 tokens: two builds have to fit inside
// 8000, so the ceiling is about (8000 / 2) - 920 - room for the user's own words. At 6500 only
// one build lands per minute. Real features come in far under this anyway -- measured between
// 580 and 950 completion tokens -- so the headroom costs nothing.
const MAX_COMPLETION_TOKENS: u32 = 2700;

// design: the html field is deliberately body-only markup. Tailwind is injected by the
// frontend from a bundled copy (static/vendor/tailwind-browser.js), so the model is told the
// classes already work and must never reach for a CDN. That keeps the promise that a
// generated feature makes no network requests, regardless of what the model would have done.
// design: split into an opening that differs per task and an environment block shared by both,
// so a change to how the sandbox behaves is made once and cannot drift between building a tool
// and revising one. Assembled by system_prompt() below.
const BUILD_INTRO: &str = r#"You are the DeenLab Feature Studio. Someone using a Muslim daily-practice app has described a small tool they want, and you build it for them. Design it yourself -- what follows describes the setting you are building into, not a specification to fill in. Where it gives a reason, weigh the reason; you can see the actual request and these notes cannot.

WHETHER TO BUILD IT
Build whatever would genuinely help someone practise: dhikr and worship aids, duas, Quran study helpers, fasting and habit trackers, Islamic date tools, zakat and charity calculators, Arabic or tajweed learning aids, reflection journals, and plenty this list has not thought of.
Decline when building it would do the person a disservice:
- It is not Deen-related.
- It needs a login, a payment, a server or live data. None of those exist here, so what you built would look like it worked and quietly would not.
- It amounts to a religious ruling. That is not ours to give.
- It is prayer times, Hijri dates or Qibla direction. The app already provides these from verified sources, so anything you generate would be a less accurate copy of something they already have.
When you decline, say why in a sentence."#;

const UPGRADE_INTRO: &str = r#"You are the DeenLab Feature Studio. Someone is using a small tool that was built for them earlier, and has asked for a change to it. You will be given the tool's current markup and what they want done.

HOW TO REVISE IT
Return the complete revised markup, not a patch or a description of the change -- what you return replaces the whole body.
Keep what they did not ask you to change. Someone asking for a reset button has not asked you to redesign the layout, and finding the rest rearranged is worse than not getting the button. If something genuinely has to change to make the request work, that is fine; changing things because you would have built it differently is not.
Anything the tool has saved through localStorage will still be there when your version loads, so keep using the same key names unless the change makes that impossible. Changing them silently loses the person's data.
Decline only if the change is not something this tool can do -- it needs live data or a server, it is no longer Deen-related, or it amounts to a religious ruling. A request you merely find odd is not a reason to decline; it is their tool."#;

const PROMPT_ENVIRONMENT: &str = r#"WHERE YOUR WORK RUNS
This is a phone app, and your tool opens full-screen inside it. There is no desktop version, so you never have to design for a wide window.
Your markup is placed inside the <body> of a page the app builds around it. Write only what belongs inside <body> -- a <!doctype>, <html>, <head> or <body> tag of your own would be a second copy of something already there.
Tailwind CSS is already loaded and working, so use its utility classes freely. Adding a CDN link or stylesheet would not just be redundant, it would fail: the frame is sealed off from the network by a Content-Security-Policy, and any external URL is blocked before it loads. That same seal is why remote images, web fonts, fetch and XMLHttpRequest cannot work here. Inline SVG, text and emoji can.
localStorage works normally here and its contents survive closing the app, so anything worth remembering between visits -- a running count, a day reached, saved settings -- can just be written to it with the ordinary getItem and setItem. The app keeps each tool's data separate, so you can use whatever key names suit you. Storing state is worth thinking about for anything a person builds up over time; a tool that silently forgets a month of progress is worse than one that never offered to remember.
Behaviour goes in a single <script> at the end, in plain JavaScript. Nothing bundles this page, so imports and frameworks would have nothing to resolve against.

WHAT TENDS TO WORK WELL HERE
The page is already dark -- zinc-950 behind zinc-100 text. Zinc shades for surfaces and borders, emerald for accents, will look like it belongs alongside the rest of the app.
Phone screens are narrow, so a vertical flow usually reads better than columns, and you may find a row of three or more controls is where a layout starts to break. Judge that against what you are actually building; the one thing to avoid is anything running off the edge, since there is nowhere sideways to scroll to.
People tap this with a thumb rather than clicking with a cursor, so controls want to be a good deal bigger than they would be on desktop.
Real <button> elements, visible focus rings, and aria-labels where the purpose is not obvious from the text cost you nothing and make the tool usable by people navigating with a keyboard or screen reader.
Arabic reads right to left, so it needs dir="rtl" to render correctly at all. It also tends to want a larger size and roomier line-height than Latin text, since the script carries more detail per character.

Respond with JSON only, in exactly this shape:
{"decision":"generate"|"decline","title":"short title","message":"one or two plain sentences for the user","html":"body markup, or an empty string when declining"}
The message is read by someone who is not a programmer, so keep it plain and honest."#;

/// Which of the two jobs the model is being asked to do.
#[derive(Clone, Copy, PartialEq)]
enum Task {
    Build,
    Upgrade,
}

fn system_prompt(task: Task) -> String {
    let intro = match task {
        Task::Build => BUILD_INTRO,
        Task::Upgrade => UPGRADE_INTRO,
    };
    format!("{intro}\n\n{PROMPT_ENVIRONMENT}")
}
#[derive(Deserialize)]
struct GroqMessage {
    content: String,
}
#[derive(Deserialize)]
struct GroqChoice {
    message: GroqMessage,
    // serde(default): Groq omits this on some responses, and a missing field would otherwise
    // fail the whole deserialize -- Option lets "not reported" stay distinct from "stopped"
    #[serde(default)]
    finish_reason: Option<String>,
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
/// Pulls the "Please try again in 30.15s" hint out of a Groq rate-limit body, rounded up.
/// The rest of that message is organization ids, service tiers and an upgrade link.
fn retry_after_seconds(detail: &str) -> Option<u64> {
    serde_json::from_str::<serde_json::Value>(detail)
        .ok()
        .and_then(|body| body["error"]["message"].as_str().map(str::to_owned))
        .and_then(|message| {
            let rest = message.split_once("try again in ")?.1.to_owned();
            let digits: String = rest
                .chars()
                .take_while(|character| character.is_ascii_digit() || *character == '.')
                .collect();
            digits.parse::<f32>().ok().map(|value| value.ceil() as u64)
        })
}

/// Why one model's attempt failed, and whether trying a different one could help.
enum AttemptError {
    /// Another model may well succeed -- the allowance is per model, not per account.
    /// `rate_limited` separates "this model is busy" from "this model produced something
    /// unusable", so the final message can say which actually happened rather than guessing.
    /// `retry_after` is Groq's own hint, used to size the wait if every model is exhausted.
    Retryable { rate_limited: bool, retry_after: Option<u64> },
    /// Nothing further will help; report it and stop.
    Fatal(String),
}

impl AttemptError {
    /// A failure unrelated to rate limiting that another model might not repeat.
    fn retry() -> Self {
        AttemptError::Retryable { rate_limited: false, retry_after: None }
    }
}

/// Progress sent to the UI while the chain runs, so a wait is explained rather than silent.
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase", tag = "kind")]
enum BuildProgress {
    /// Attempt `attempt` of `total` is under way.
    Trying { attempt: usize, total: usize },
    /// Every model is rate-limited; waiting before going round again.
    Waiting { seconds: u64 },
}

/// One request to one model.
async fn attempt_build(
    client: &reqwest::Client,
    model: &ModelSpec,
    system: &str,
    prompt: &str,
) -> Result<FeatureBuildResult, AttemptError> {
    let mut request_body = serde_json::json!({
        "model": model.id,
        "temperature": 0.3,
        "max_completion_tokens": MAX_COMPLETION_TOKENS,
        "response_format": { "type": "json_object" },
        "messages": [
            { "role": "system", "content": system },
            { "role": "user", "content": prompt }
        ]
    });
    // only sent to models that accept it -- see ModelSpec::reasoning_effort
    if let Some(effort) = model.reasoning_effort {
        request_body["reasoning_effort"] = effort.into();
    }

    let response = client
        .post("https://api.groq.com/openai/v1/chat/completions")
        .bearer_auth(groq_config::API_KEY)
        .json(&request_body)
        .send()
        .await
        // a network blip on one attempt says nothing about the next, so this stays retryable
        .map_err(|_| AttemptError::retry())?;

    if !response.status().is_success() {
        let status = response.status();
        let detail = response.text().await.unwrap_or_default();

        // 429 is "this minute's tokens are gone", 413 is "this one request exceeds the whole
        // minute's allowance". Both mean: this model is unavailable right now, try the next.
        if status == reqwest::StatusCode::TOO_MANY_REQUESTS
            || status == reqwest::StatusCode::PAYLOAD_TOO_LARGE
        {
            return Err(AttemptError::Retryable { rate_limited: true, retry_after: retry_after_seconds(&detail) });
        }
        // Groq validates the reply against the requested JSON shape and rejects the call when it
        // doesn't hold, usually because the model ran out of budget mid-object. A different model
        // may well produce valid JSON, so this is worth retrying rather than reporting.
        if detail.contains("failed_generation") || detail.contains("to generate JSON") {
            return Err(AttemptError::retry());
        }
        // 401/403 mean the key itself is wrong -- no other model will fix that.
        if status == reqwest::StatusCode::UNAUTHORIZED || status == reqwest::StatusCode::FORBIDDEN {
            return Err(AttemptError::Fatal(
                "Groq rejected the API key in src-tauri/src/groq_config.rs.".into(),
            ));
        }
        return Err(AttemptError::Fatal(format!("Groq request failed ({status}): {detail}")));
    }

    let response: GroqResponse = response
        .json()
        .await
        .map_err(|_| AttemptError::retry())?;
    let choice = response
        .choices
        .first()
        .ok_or(AttemptError::retry())?;

    // checked before parsing: a truncated reply is invalid JSON, and the parse error it causes
    // ("EOF while parsing a string") would explain nothing
    if choice.finish_reason.as_deref() == Some("length") {
        return Err(AttemptError::retry());
    }

    let result: FeatureBuildResult = serde_json::from_str(&choice.message.content)
        .map_err(|_| AttemptError::retry())?;

    if result.decision != "generate" && result.decision != "decline" {
        return Err(AttemptError::retry());
    }
    if result.decision == "generate" && result.html.trim().is_empty() {
        return Err(AttemptError::retry());
    }
    Ok(result)
}

/// Walks the model chain until one succeeds.
///
/// Because the per-minute allowance is per model, a 429 from one model says nothing about the
/// next, so the chain is tried straight through with no delay first. Only when every model is
/// exhausted is there anything to wait for, and then the wait uses Groq's own retry hint.
///
/// Shared by both commands below -- building a tool and revising one differ only in which system
/// prompt they send and what they put in the user message.
async fn run_chain(
    system: &str,
    prompt: &str,
    progress: &tauri::ipc::Channel<BuildProgress>,
) -> Result<FeatureBuildResult, String> {
    // one client for every attempt -- rebuilding it per request would throw away the connection
    // pool and TLS session, which is most of the cost of a second attempt
    let client = reqwest::Client::new();
    let total = MODEL_CHAIN.len() * MAX_ROUNDS;
    let mut saw_rate_limit = false;
    let mut attempt = 0;

    for round in 0..MAX_ROUNDS {
        let mut shortest_retry: Option<u64> = None;

        for model in MODEL_CHAIN {
            attempt += 1;
            // ignored deliberately: the channel is closed when the UI has navigated away, which
            // is not a reason to abandon a build that is already in flight
            let _ = progress.send(BuildProgress::Trying { attempt, total });

            match attempt_build(&client, model, system, prompt).await {
                Ok(result) => return Ok(result),
                Err(AttemptError::Fatal(message)) => return Err(message),
                Err(AttemptError::Retryable { rate_limited, retry_after }) => {
                    saw_rate_limit |= rate_limited;
                    shortest_retry = match (shortest_retry, retry_after) {
                        (Some(current), Some(hint)) => Some(current.min(hint)),
                        (current, hint) => current.or(hint),
                    };
                }
            }
        }

        // every model in the chain refused; wait before going round again, unless this was the
        // last round -- sleeping only to then give up would waste the user's time
        if round + 1 < MAX_ROUNDS {
            let wait = shortest_retry.unwrap_or(20).clamp(1, MAX_WAIT_SECONDS);
            let _ = progress.send(BuildProgress::Waiting { seconds: wait });
            tokio::time::sleep(std::time::Duration::from_secs(wait)).await;
        }
    }

    // two different failures, told apart rather than blurred into one vague message: being
    // rate-limited is worth waiting out, whereas repeated unusable replies usually mean the
    // request itself needs rewording
    Err(if saw_rate_limit {
        "Every model is busy right now. Groq's free plan limits how much can be built each minute — wait a moment and try again.".into()
    } else {
        "The models could not produce a working feature for this. Try describing it differently, or ask for something smaller.".to_string()
    })
}

fn missing_key() -> String {
    "Groq is not configured. Copy src-tauri/src/groq_config.example.rs to groq_config.rs and add your API key.".into()
}

/// Builds a new tool from a plain-English description.
#[tauri::command]
async fn build_feature(
    prompt: String,
    progress: tauri::ipc::Channel<BuildProgress>,
) -> Result<FeatureBuildResult, String> {
    let prompt = prompt.trim();
    if prompt.is_empty() {
        return Err("Describe the feature you would like to create.".into());
    }
    if groq_config::API_KEY.trim().is_empty() {
        return Err(missing_key());
    }

    run_chain(&system_prompt(Task::Build), prompt, &progress).await
}

/// Revises an existing tool. Returns a new version; it is the front-end that decides whether to
/// keep it, so nothing is overwritten here.
#[tauri::command]
async fn upgrade_feature(
    request: String,
    current_html: String,
    progress: tauri::ipc::Channel<BuildProgress>,
) -> Result<FeatureBuildResult, String> {
    let request = request.trim();
    if request.is_empty() {
        return Err("Describe the change you would like.".into());
    }
    if current_html.trim().is_empty() {
        return Err("This tool has no markup to revise.".into());
    }
    if groq_config::API_KEY.trim().is_empty() {
        return Err(missing_key());
    }

    // the current markup rides in the user message rather than the system prompt: it changes on
    // every request, while the system prompt is the part worth keeping identical between calls
    let prompt = format!(
        "Here is the tool's current markup:\n\n{current_html}\n\nThe change they want:\n\n{request}"
    );

    run_chain(&system_prompt(Task::Upgrade), &prompt, &progress).await
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
                _app.handle().plugin(tauri_plugin_device_settings::init())?;
                _app.handle().plugin(tauri_plugin_compass::init())?;
            }
            Ok(())
        })
        .manage(api_cache::HttpClient::default())
        .invoke_handler(tauri::generate_handler![
            build_feature,
            upgrade_feature,
            api_cache::api_request,
            api_cache::get_cached_response,
            ip_location::ip_location
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}