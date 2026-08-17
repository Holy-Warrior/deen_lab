use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

mod commands;
mod error;
mod mobile;

pub use error::{Error, Result};
pub use mobile::{Compass, StartResult};

/// Extension trait to access the compass APIs from [`tauri::App`]/[`tauri::AppHandle`].
pub trait CompassExt<R: Runtime> {
    fn compass(&self) -> &Compass<R>;
}

impl<R: Runtime, T: Manager<R>> CompassExt<R> for T {
    fn compass(&self) -> &Compass<R> {
        self.state::<Compass<R>>().inner()
    }
}

/// Initializes the plugin.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("compass")
        .invoke_handler(tauri::generate_handler![commands::start, commands::stop])
        .setup(|app, api| {
            let compass = mobile::init(app, api)?;
            app.manage(compass);
            Ok(())
        })
        .build()
}
