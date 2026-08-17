use serde::{de::DeserializeOwned, Serialize};
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

const PLUGIN_IDENTIFIER: &str = "com.deenlab.devicesettings";

pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> crate::Result<DeviceSettings<R>> {
    let handle = api.register_android_plugin(PLUGIN_IDENTIFIER, "DeviceSettingsPlugin")?;
    Ok(DeviceSettings(handle))
}

#[derive(Serialize)]
struct ToastPayload {
    message: String,
}

/// Access to native Android device-settings screens.
pub struct DeviceSettings<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> DeviceSettings<R> {
    pub fn open_location_settings(&self) -> crate::Result<()> {
        self.0
            .run_mobile_plugin("openLocationSettings", ())
            .map_err(Into::into)
    }

    /// Opens this app's own "App info" settings screen -- the only way for the user to
    /// re-grant a permission once Android has stopped showing its own request dialog for it.
    pub fn open_app_settings(&self) -> crate::Result<()> {
        self.0
            .run_mobile_plugin("openAppSettings", ())
            .map_err(Into::into)
    }

    /// Shows a native Android Toast -- the small system-level hint text apps use to guide the
    /// user right before handing them off to a settings screen.
    pub fn show_toast(&self, message: String) -> crate::Result<()> {
        self.0
            .run_mobile_plugin("showToast", ToastPayload { message })
            .map_err(Into::into)
    }
}
