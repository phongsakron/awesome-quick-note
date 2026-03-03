use crate::state::pin_manager::PinManager;
use tauri::State;

#[tauri::command]
pub fn toggle_pin(note_id: String, pin_manager: State<'_, PinManager>) -> bool {
    pin_manager.toggle(&note_id)
}

#[tauri::command]
pub fn get_pinned_notes(pin_manager: State<'_, PinManager>) -> Vec<String> {
    pin_manager.pinned_ids()
}
