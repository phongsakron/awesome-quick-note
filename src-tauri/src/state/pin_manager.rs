use std::collections::HashSet;
use std::fs;
use std::path::PathBuf;
use std::sync::Mutex;

pub struct PinManager {
    pinned: Mutex<HashSet<String>>,
    config_path: PathBuf,
}

impl PinManager {
    pub fn new(config_dir: PathBuf) -> Self {
        let config_path = config_dir.join("pinned_notes.json");

        let pinned = if config_path.exists() {
            fs::read_to_string(&config_path)
                .ok()
                .and_then(|data| serde_json::from_str::<Vec<String>>(&data).ok())
                .map(|v| v.into_iter().collect())
                .unwrap_or_default()
        } else {
            HashSet::new()
        };

        Self {
            pinned: Mutex::new(pinned),
            config_path,
        }
    }

    pub fn toggle(&self, note_id: &str) -> bool {
        let mut pinned = self.pinned.lock().unwrap();
        let is_pinned = if pinned.contains(note_id) {
            pinned.remove(note_id);
            false
        } else {
            pinned.insert(note_id.to_string());
            true
        };
        self.save_to_disk(&pinned);
        is_pinned
    }

    pub fn is_pinned(&self, note_id: &str) -> bool {
        self.pinned.lock().unwrap().contains(note_id)
    }

    pub fn pinned_ids(&self) -> Vec<String> {
        self.pinned.lock().unwrap().iter().cloned().collect()
    }

    fn save_to_disk(&self, pinned: &HashSet<String>) {
        if let Some(parent) = self.config_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let ids: Vec<&String> = pinned.iter().collect();
        if let Ok(json) = serde_json::to_string_pretty(&ids) {
            let _ = fs::write(&self.config_path, json);
        }
    }
}
