use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

mod commands;
mod error;
mod mobile;

pub use error::{Error, Result};
pub use mobile::DeviceSettings;

/// Extension trait to access the device-settings APIs from [`tauri::App`]/[`tauri::AppHandle`].
pub trait DeviceSettingsExt<R: Runtime> {
    fn device_settings(&self) -> &DeviceSettings<R>;
}

impl<R: Runtime, T: Manager<R>> DeviceSettingsExt<R> for T {
    fn device_settings(&self) -> &DeviceSettings<R> {
        self.state::<DeviceSettings<R>>().inner()
    }
}

/// Initializes the plugin.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("device-settings")
        .invoke_handler(tauri::generate_handler![
            commands::open_location_settings,
            commands::open_app_settings,
            commands::show_toast
        ])
        .setup(|app, api| {
            let device_settings = mobile::init(app, api)?;
            app.manage(device_settings);
            Ok(())
        })
        .build()
}
