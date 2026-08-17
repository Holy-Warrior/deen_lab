// Copy this file to groq_config.rs and add your key locally.
// groq_config.rs is intentionally ignored by Git.
//
// A free key from https://console.groq.com is enough. Without one the app still runs and
// every other feature works -- only Feature Studio reports that it is not configured.
//
// The model id is NOT here on purpose: it lives in lib.rs as GROQ_MODEL so it stays under
// version control. This file holds the secret and nothing else.
pub const API_KEY: &str = "";
