use crate::models::note::Note;
use crate::state::recent_manager::RecentManager;
use crate::state::search_manager::SearchManager;
use crate::state::vault_manager::VaultManager;
use serde::Serialize;
use tauri::State;

#[derive(Serialize)]
pub struct SearchResult {
    pub note: Note,
    pub score: u32,
    pub snippet: String,
}

fn make_snippet(content: &str) -> String {
    let mut snippet = String::new();
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("# ") {
            continue;
        }
        snippet = trimmed.to_string();
        break;
    }
    if snippet.len() > 80 {
        let truncated: String = snippet.chars().take(80).collect();
        format!("{}...", truncated)
    } else {
        snippet
    }
}

#[tauri::command]
pub fn search_notes(
    query: String,
    vault_manager: State<'_, VaultManager>,
    recent_manager: State<'_, RecentManager>,
) -> Vec<SearchResult> {
    let recent = recent_manager.all();
    let mut notes = vault_manager.load_notes();
    // Sort by last opened (fallback to modified_at)
    notes.sort_by(|a, b| {
        let a_time = recent.get(&a.id).copied().unwrap_or(a.modified_at);
        let b_time = recent.get(&b.id).copied().unwrap_or(b.modified_at);
        b_time.cmp(&a_time)
    });
    SearchManager::search(&notes, &query)
        .into_iter()
        .map(|(note, score)| {
            let snippet = make_snippet(&note.content);
            SearchResult { note, score, snippet }
        })
        .collect()
}
