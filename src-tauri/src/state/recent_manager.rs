use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::Mutex;

pub struct RecentManager {
    /// Map of note_id -> last_opened_at (Unix timestamp ms)
    recent: Mutex<HashMap<String, i64>>,
    config_path: PathBuf,
}

impl RecentManager {
    pub fn new(config_dir: PathBuf) -> Self {
        let config_path = config_dir.join("recent_notes.json");

        let recent = if config_path.exists() {
            fs::read_to_string(&config_path)
                .ok()
                .and_then(|data| serde_json::from_str::<HashMap<String, i64>>(&data).ok())
                .unwrap_or_default()
        } else {
            HashMap::new()
        };

        Self {
            recent: Mutex::new(recent),
            config_path,
        }
    }

    pub fn record_opened(&self, note_id: &str) -> i64 {
        let now = chrono::Utc::now().timestamp_millis();
        let mut recent = self.recent.lock().unwrap();
        recent.insert(note_id.to_string(), now);
        self.save_to_disk(&recent);
        now
    }

    pub fn last_opened(&self, note_id: &str) -> Option<i64> {
        self.recent.lock().unwrap().get(note_id).copied()
    }

    pub fn all(&self) -> HashMap<String, i64> {
        self.recent.lock().unwrap().clone()
    }

    fn save_to_disk(&self, recent: &HashMap<String, i64>) {
        if let Some(parent) = self.config_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if let Ok(json) = serde_json::to_string_pretty(recent) {
            let _ = fs::write(&self.config_path, json);
        }
    }
}
