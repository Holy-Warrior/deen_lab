use serde::{de::DeserializeOwned, Deserialize, Serialize};
use tauri::{
    ipc::Channel,
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

const PLUGIN_IDENTIFIER: &str = "com.deenlab.compass";

pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> crate::Result<Compass<R>> {
    let handle = api.register_android_plugin(PLUGIN_IDENTIFIER, "CompassPlugin")?;
    Ok(Compass(handle))
}

#[derive(Serialize)]
struct StartPayload {
    channel: Channel,
}

/// Which sensor(s) actually fed the heading stream on this device -- "sensor" means a real,
/// north-anchored magnetometer reading; "gyroscope" means a relative-only estimate (see the
/// Kotlin plugin source for how it's derived); "none" means no usable sensor exists at all.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StartResult {
    pub mode: String,
}

/// Access to native Android orientation sensors.
pub struct Compass<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> Compass<R> {
    pub fn start(&self, channel: Channel) -> crate::Result<StartResult> {
        self.0
            .run_mobile_plugin("start", StartPayload { channel })
            .map_err(Into::into)
    }

    pub fn stop(&self) -> crate::Result<()> {
        self.0.run_mobile_plugin("stop", ()).map_err(Into::into)
    }
}
