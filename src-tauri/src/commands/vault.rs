use crate::models::note::Note;
use crate::state::git_sync_manager::GitSyncManager;
use crate::state::settings_manager::SettingsManager;
use crate::state::vault_manager::VaultManager;
use std::path::PathBuf;
use std::sync::Arc;
use tauri::{AppHandle, State};
use tauri_plugin_dialog::DialogExt;

#[tauri::command]
pub async fn select_vault(app: AppHandle) -> Result<Option<String>, String> {
    let (tx, rx) = std::sync::mpsc::channel();

    app.dialog()
        .file()
        .set_title("Select Vault Folder")
        .pick_folder(move |path| {
            let _ = tx.send(path.map(|p| p.to_string()));
        });

    rx.recv().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn set_vault(
    path: String,
    vault_manager: State<'_, VaultManager>,
    settings_manager: State<'_, SettingsManager>,
    git_sync_manager: State<'_, Arc<GitSyncManager>>,
    app_handle: AppHandle,
) {
    let path_buf = PathBuf::from(&path);
    vault_manager.set_vault(path_buf.clone());
    settings_manager.set_vault_path(Some(path));
    git_sync_manager.configure(Some(path_buf), &app_handle);
}

#[tauri::command]
pub fn get_vault_path(settings_manager: State<'_, SettingsManager>) -> Option<String> {
    settings_manager.vault_path()
}

#[tauri::command]
pub fn get_notes(vault_manager: State<'_, VaultManager>) -> Vec<Note> {
    vault_manager.load_notes()
}

#[tauri::command]
pub fn create_note(
    vault_manager: State<'_, VaultManager>,
    git_sync_manager: State<'_, Arc<GitSyncManager>>,
) -> Result<Note, String> {
    let note = vault_manager
        .create_note()
        .ok_or_else(|| "Failed to create note".to_string())?;
    git_sync_manager.notify_file_changed();
    Ok(note)
}

#[tauri::command]
pub fn save_note(
    id: String,
    content: String,
    vault_manager: State<'_, VaultManager>,
    git_sync_manager: State<'_, Arc<GitSyncManager>>,
) -> Result<(), String> {
    vault_manager.save_note(&id, &content)?;
    git_sync_manager.notify_file_changed();
    Ok(())
}

#[tauri::command]
pub fn delete_note(
    id: String,
    vault_manager: State<'_, VaultManager>,
    git_sync_manager: State<'_, Arc<GitSyncManager>>,
) -> Result<(), String> {
    vault_manager.delete_note(&id)?;
    git_sync_manager.notify_file_changed();
    Ok(())
}
