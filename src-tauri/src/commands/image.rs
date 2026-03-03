use crate::state::image_manager::ImageManager;
use crate::state::vault_manager::VaultManager;
use tauri::State;

#[tauri::command]
pub fn save_image(
    image_data: Vec<u8>,
    vault_manager: State<'_, VaultManager>,
) -> Result<String, String> {
    ImageManager::save_image(&vault_manager, &image_data)
}

#[tauri::command]
pub fn copy_image_to_clipboard(image_path: String) -> Result<(), String> {
    ImageManager::copy_image_to_clipboard(&image_path)
}

#[tauri::command]
pub fn open_file(path: String) -> Result<(), String> {
    open::that(&path).map_err(|e| format!("Failed to open file: {}", e))
}
