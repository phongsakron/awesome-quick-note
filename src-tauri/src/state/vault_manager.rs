use crate::models::note::Note;
use chrono::Utc;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

pub struct VaultManager {
    vault_path: Mutex<Option<PathBuf>>,
}

impl VaultManager {
    pub fn new() -> Self {
        Self {
            vault_path: Mutex::new(None),
        }
    }

    pub fn set_vault(&self, path: PathBuf) {
        *self.vault_path.lock().unwrap() = Some(path);
    }

    pub fn vault_path(&self) -> Option<PathBuf> {
        self.vault_path.lock().unwrap().clone()
    }

    pub fn load_notes(&self) -> Vec<Note> {
        let vault = match self.vault_path() {
            Some(v) => v,
            None => return Vec::new(),
        };

        let entries = match fs::read_dir(&vault) {
            Ok(e) => e,
            Err(_) => return Vec::new(),
        };

        let mut notes = Vec::new();

        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().map_or(false, |ext| ext == "md") {
                if let Some(note) = Self::load_note_from_path(&path) {
                    notes.push(note);
                }
            }
        }

        notes.sort_by(|a, b| b.modified_at.cmp(&a.modified_at));
        notes
    }

    fn load_note_from_path(path: &Path) -> Option<Note> {
        let content = fs::read_to_string(path).ok()?;
        let metadata = fs::metadata(path).ok()?;

        let file_name = path.file_name()?.to_str()?.to_string();

        // Use filename without extension as stable ID
        let id = file_name
            .strip_suffix(".md")
            .unwrap_or(&file_name)
            .to_string();

        let created_at = metadata
            .created()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_millis() as i64)
            .unwrap_or_else(|| Utc::now().timestamp_millis());

        let modified_at = metadata
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_millis() as i64)
            .unwrap_or_else(|| Utc::now().timestamp_millis());

        let title = Note::derive_title(&content, &file_name);

        Some(Note {
            id,
            file_name,
            file_path: path.to_str()?.to_string(),
            content,
            title,
            created_at,
            modified_at,
        })
    }

    pub fn create_note(&self) -> Option<Note> {
        let vault = self.vault_path()?;
        let now = Utc::now();
        let filename = now.format("%Y%m%d-%H%M%S.md").to_string();
        let file_path = vault.join(&filename);
        let default_content = "# New Note\n\n".to_string();

        fs::write(&file_path, &default_content).ok()?;

        let id = filename
            .strip_suffix(".md")
            .unwrap_or(&filename)
            .to_string();
        let ts = now.timestamp_millis();

        Some(Note {
            id,
            file_name: filename,
            file_path: file_path.to_str()?.to_string(),
            content: default_content.clone(),
            title: "New Note".to_string(),
            created_at: ts,
            modified_at: ts,
        })
    }

    pub fn save_note(&self, id: &str, content: &str) -> Result<(), String> {
        let vault = self.vault_path().ok_or("No vault set")?;
        let path = vault.join(format!("{}.md", id));
        if path.exists() {
            fs::write(&path, content).map_err(|e| e.to_string())
        } else {
            Err("Note not found".to_string())
        }
    }

    pub fn delete_note(&self, id: &str) -> Result<(), String> {
        let vault = self.vault_path().ok_or("No vault set")?;
        let path = vault.join(format!("{}.md", id));
        if path.exists() {
            trash::delete(&path).map_err(|e| e.to_string())
        } else {
            Err("Note not found".to_string())
        }
    }

    pub fn attachments_dir(&self) -> Option<PathBuf> {
        let vault = self.vault_path()?;
        let dir = vault.join("attachments");
        if !dir.exists() {
            let _ = fs::create_dir_all(&dir);
        }
        Some(dir)
    }
}
