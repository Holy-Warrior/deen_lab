//! Tauri v2 port of the `silence_of_salah_engine` Flutter plugin.
//!
//! Detects salah via on-device sensor ML inference running inside an Android
//! foreground service, then silences the phone automatically. See the crate
//! README for the full command reference and setup steps.
//!
//! This crate only contains real functionality on Android - the same as the
//! original Flutter plugin, which never implemented iOS. On every other
//! target every command simply returns [`Error::UnsupportedPlatform`], so a
//! project that also builds for desktop or iOS, and `cargo test`/`cargo
//! check` on your own machine, both work without an Android toolchain.

use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

pub use models::*;

mod commands;
#[cfg(not(target_os = "android"))]
mod desktop;
mod error;
#[cfg(target_os = "android")]
mod mobile;
mod models;

pub use error::{Error, Result};

#[cfg(target_os = "android")]
use mobile::SilenceOfSalahEngine;

#[cfg(not(target_os = "android"))]
use desktop::SilenceOfSalahEngine;

/// Extension trait on [`tauri::App`], [`tauri::AppHandle`], [`tauri::WebviewWindow`],
/// [`tauri::Webview`] and [`tauri::Window`] to access the silence-of-salah-engine APIs.
pub trait SilenceOfSalahEngineExt<R: Runtime> {
    fn silence_of_salah_engine(&self) -> &SilenceOfSalahEngine<R>;
}

impl<R: Runtime, T: Manager<R>> SilenceOfSalahEngineExt<R> for T {
    fn silence_of_salah_engine(&self) -> &SilenceOfSalahEngine<R> {
        self.state::<SilenceOfSalahEngine<R>>().inner()
    }
}

/// Initializes the plugin. Safe to register unconditionally even on
/// non-Android targets - every command will just resolve to
/// [`Error::UnsupportedPlatform`] there instead of doing anything.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("silence-of-salah-engine")
        .invoke_handler(tauri::generate_handler![
            commands::get_platform_version,
            commands::start_native_task,
            commands::stop_native_task,
            commands::get_native_status,
            commands::schedule_daily_alarms,
            commands::get_scheduled_alarms,
            commands::cancel_all_alarms,
            commands::trigger_ml_processing,
            commands::submit_ml_decision_output,
            commands::debug_set_audio_silent,
            commands::debug_restore_audio_default,
            commands::get_permission_status,
            commands::request_exact_alarm_permission,
            commands::request_dnd_access,
            commands::request_battery_optimization,
            commands::request_notification_permission,
        ])
        .setup(|app, api| {
            #[cfg(target_os = "android")]
            let silence_of_salah_engine = mobile::init(app, api)?;
            #[cfg(not(target_os = "android"))]
            let silence_of_salah_engine = desktop::init(app, api)?;

            app.manage(silence_of_salah_engine);
            Ok(())
        })
        .build()
}
