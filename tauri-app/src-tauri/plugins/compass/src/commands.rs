use tauri::{command, ipc::Channel, AppHandle, Runtime};

use crate::{CompassExt, Result, StartResult};

#[command]
pub(crate) async fn start<R: Runtime>(app: AppHandle<R>, channel: Channel) -> Result<StartResult> {
    app.compass().start(channel)
}

#[command]
pub(crate) async fn stop<R: Runtime>(app: AppHandle<R>) -> Result<()> {
    app.compass().stop()
}
