const COMMANDS: &[&str] = &["start", "stop"];

fn main() {
    tauri_plugin::Builder::new(COMMANDS)
        .android_path("android")
        .try_build()
        .expect("failed to run tauri-plugin build script");
}
