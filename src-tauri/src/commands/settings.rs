use crate::models::settings::AppSettings;
use crate::state::settings_manager::SettingsManager;
use tauri::State;

#[tauri::command]
pub fn get_settings(settings_manager: State<'_, SettingsManager>) -> AppSettings {
    settings_manager.get()
}

#[tauri::command]
pub fn update_settings(
    settings: serde_json::Value,
    settings_manager: State<'_, SettingsManager>,
) {
    settings_manager.update(settings);
}

#[tauri::command]
pub fn get_platform_info() -> serde_json::Value {
    let os = if cfg!(target_os = "macos") {
        "macos"
    } else if cfg!(target_os = "linux") {
        "linux"
    } else if cfg!(target_os = "windows") {
        "windows"
    } else {
        "unknown"
    };

    let display_server = if cfg!(target_os = "macos") {
        "macos".to_string()
    } else {
        std::env::var("WAYLAND_DISPLAY")
            .map(|_| "wayland".to_string())
            .unwrap_or_else(|_| "x11".to_string())
    };

    serde_json::json!({
        "os": os,
        "display_server": display_server
    })
}
