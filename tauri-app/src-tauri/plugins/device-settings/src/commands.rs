use tauri::{command, AppHandle, Runtime};

use crate::{DeviceSettingsExt, Result};

#[command]
pub(crate) async fn open_location_settings<R: Runtime>(app: AppHandle<R>) -> Result<()> {
    app.device_settings().open_location_settings()
}

#[command]
pub(crate) async fn open_app_settings<R: Runtime>(app: AppHandle<R>) -> Result<()> {
    app.device_settings().open_app_settings()
}

#[command]
pub(crate) async fn show_toast<R: Runtime>(app: AppHandle<R>, message: String) -> Result<()> {
    app.device_settings().show_toast(message)
}
