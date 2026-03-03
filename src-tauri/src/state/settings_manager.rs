use crate::models::settings::AppSettings;
use std::fs;
use std::path::PathBuf;
use std::sync::Mutex;

pub struct SettingsManager {
    settings: Mutex<AppSettings>,
    config_path: PathBuf,
}

impl SettingsManager {
    pub fn new(config_dir: PathBuf) -> Self {
        let config_path = config_dir.join("settings.json");

        let settings = if config_path.exists() {
            match fs::read_to_string(&config_path) {
                Ok(data) => serde_json::from_str(&data).unwrap_or_default(),
                Err(_) => AppSettings::default(),
            }
        } else {
            AppSettings::default()
        };

        Self {
            settings: Mutex::new(settings),
            config_path,
        }
    }

    pub fn get(&self) -> AppSettings {
        self.settings.lock().unwrap().clone()
    }

    pub fn update(&self, partial: serde_json::Value) {
        let mut settings = self.settings.lock().unwrap();

        // Merge partial values into current settings
        let mut current = serde_json::to_value(&*settings).unwrap();
        if let (Some(current_obj), Some(partial_obj)) =
            (current.as_object_mut(), partial.as_object())
        {
            for (key, value) in partial_obj {
                current_obj.insert(key.clone(), value.clone());
            }
        }

        if let Ok(updated) = serde_json::from_value::<AppSettings>(current) {
            *settings = updated;
            self.save_to_disk(&settings);
        }
    }

    pub fn set_vault_path(&self, path: Option<String>) {
        let mut settings = self.settings.lock().unwrap();
        settings.vault_path = path;
        self.save_to_disk(&settings);
    }

    pub fn vault_path(&self) -> Option<String> {
        self.settings.lock().unwrap().vault_path.clone()
    }

    fn save_to_disk(&self, settings: &AppSettings) {
        if let Some(parent) = self.config_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if let Ok(json) = serde_json::to_string_pretty(settings) {
            let _ = fs::write(&self.config_path, json);
        }
    }
}
