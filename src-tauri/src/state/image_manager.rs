use crate::state::vault_manager::VaultManager;
use std::fs;
use uuid::Uuid;

pub struct ImageManager;

impl ImageManager {
    pub fn save_image(vault_manager: &VaultManager, image_data: &[u8]) -> Result<String, String> {
        let attachments_dir = vault_manager
            .attachments_dir()
            .ok_or_else(|| "No vault configured".to_string())?;

        let filename = format!("{}.png", Uuid::new_v4());
        let file_path = attachments_dir.join(&filename);

        fs::write(&file_path, image_data).map_err(|e| e.to_string())?;

        // Return relative markdown image syntax
        Ok(format!("![image](attachments/{})", filename))
    }

    pub fn copy_image_to_clipboard(image_path: &str) -> Result<(), String> {
        let img = image::open(image_path)
            .map_err(|e| format!("Failed to open image: {}", e))?;
        let rgba = img.to_rgba8();
        let (width, height) = rgba.dimensions();

        let img_data = arboard::ImageData {
            width: width as usize,
            height: height as usize,
            bytes: std::borrow::Cow::Owned(rgba.into_raw()),
        };

        let mut clipboard = arboard::Clipboard::new()
            .map_err(|e| format!("Failed to access clipboard: {}", e))?;
        clipboard
            .set_image(img_data)
            .map_err(|e| format!("Failed to copy image: {}", e))?;

        Ok(())
    }
}
