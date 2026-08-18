use serde::{ser::Serializer, Serialize};

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Io(#[from] std::io::Error),

    #[error(transparent)]
    Json(#[from] serde_json::Error),

    // tauri::plugin::mobile is only compiled into the `tauri` crate itself
    // when targeting Android/iOS - this variant (only ever constructed from
    // src/mobile.rs, which is itself Android-only) has to match that gate or
    // desktop builds fail to resolve the type at all.
    #[cfg(target_os = "android")]
    #[error(transparent)]
    PluginInvoke(#[from] tauri::plugin::mobile::PluginInvokeError),

    #[error(transparent)]
    Tauri(#[from] tauri::Error),

    /// Returned by every command when running on a platform other than
    /// Android, since this plugin wraps Android-only APIs (foreground
    /// services, exact alarms, ringer mode, on-device sensors).
    #[error("silence-of-salah-engine is only supported on Android ({0})")]
    UnsupportedPlatform(String),
}

impl Serialize for Error {
    fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.to_string().as_ref())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unsupported_platform_message_mentions_the_reason() {
        let error = Error::UnsupportedPlatform("this plugin only runs on Android".into());
        let message = error.to_string();
        assert!(message.contains("only supported on Android"));
        assert!(message.contains("this plugin only runs on Android"));
    }

    #[test]
    fn error_serializes_to_a_plain_json_string() {
        let error = Error::UnsupportedPlatform("no foreground service on this platform".into());
        let json = serde_json::to_value(&error).unwrap();
        assert!(json.is_string());
        assert_eq!(json.as_str().unwrap(), error.to_string());
    }
}
