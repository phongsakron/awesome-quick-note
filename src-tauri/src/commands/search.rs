use crate::models::note::Note;
use crate::state::search_manager::SearchManager;
use crate::state::vault_manager::VaultManager;
use serde::Serialize;
use tauri::State;

#[derive(Serialize)]
pub struct SearchResult {
    pub note: Note,
    pub score: u32,
}

#[tauri::command]
pub fn search_notes(query: String, vault_manager: State<'_, VaultManager>) -> Vec<SearchResult> {
    let notes = vault_manager.load_notes();
    SearchManager::search(&notes, &query)
        .into_iter()
        .map(|(note, score)| SearchResult { note, score })
        .collect()
}
