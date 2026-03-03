use crate::models::git_status::GitSyncEvent;
use crate::state::git_sync_manager::GitSyncManager;
use crate::state::settings_manager::SettingsManager;
use std::sync::Arc;
use tauri::{AppHandle, State};

#[tauri::command]
pub fn get_git_sync_status(
    git_sync_manager: State<'_, Arc<GitSyncManager>>,
) -> GitSyncEvent {
    git_sync_manager.get_status_event()
}

#[tauri::command]
pub fn manual_sync(
    git_sync_manager: State<'_, Arc<GitSyncManager>>,
    app_handle: AppHandle,
) {
    git_sync_manager.manual_sync(&app_handle);
}

#[tauri::command]
pub fn set_git_sync_enabled(
    enabled: bool,
    git_sync_manager: State<'_, Arc<GitSyncManager>>,
    settings_manager: State<'_, SettingsManager>,
    app_handle: AppHandle,
) {
    settings_manager.update(serde_json::json!({ "git_sync_enabled": enabled }));
    git_sync_manager.set_enabled(enabled, &app_handle);
}
