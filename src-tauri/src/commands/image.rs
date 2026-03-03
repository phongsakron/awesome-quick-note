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
