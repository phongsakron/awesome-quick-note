use crate::state::settings_manager::SettingsManager;
use tauri::{AppHandle, Emitter, Manager};
use tauri_plugin_global_shortcut::GlobalShortcutExt;

#[tauri::command]
pub fn register_shortcuts(app: AppHandle) -> Result<(), String> {
    let settings_manager: tauri::State<SettingsManager> = app.state();
    let settings = settings_manager.get();
    let sc = &settings.shortcuts;

    // Unregister all existing shortcuts first
    let _ = app.global_shortcut().unregister_all();

    let combos: Vec<(&str, &str)> = vec![
        (&sc.toggle_panel, "shortcut:toggle_panel"),
        (&sc.new_note, "shortcut:new_note"),
        (&sc.search_notes, "shortcut:search_notes"),
        (&sc.toggle_pin, "shortcut:toggle_pin"),
        (&sc.reset_position, "shortcut:reset_position"),
    ];

    for (combo_str, event_name) in combos {
        let handle = app.clone();
        let evt = event_name.to_string();
        if let Err(e) = app.global_shortcut().on_shortcut(combo_str, move |_app, _shortcut, event| {
            if event.state == tauri_plugin_global_shortcut::ShortcutState::Pressed {
                let _ = handle.emit(&evt, ());
            }
        }) {
            eprintln!("[shortcuts] Failed to register '{}': {}", combo_str, e);
        }
    }

    Ok(())
}
