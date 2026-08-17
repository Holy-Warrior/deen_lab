const COMMANDS: &[&str] = &["open_location_settings", "open_app_settings", "show_toast"];

fn main() {
    tauri_plugin::Builder::new(COMMANDS)
        .android_path("android")
        .try_build()
        .expect("failed to run tauri-plugin build script");
}
