use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub vault_path: Option<String>,
    pub font_family: String,
    pub font_size: u32,
    pub panel_opacity: f64,
    pub panel_position: String,
    pub panel_width: u32,
    pub panel_height: u32,
    pub panel_x: Option<i32>,
    pub panel_y: Option<i32>,
    pub git_sync_enabled: bool,
    pub shortcuts: ShortcutSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShortcutSettings {
    pub toggle_panel: String,
    pub new_note: String,
    pub search_notes: String,
    pub toggle_pin: String,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            vault_path: None,
            font_family: "SF Mono".to_string(),
            font_size: 14,
            panel_opacity: 1.0,
            panel_position: "center".to_string(),
            panel_width: 480,
            panel_height: 600,
            panel_x: None,
            panel_y: None,
            git_sync_enabled: false,
            shortcuts: ShortcutSettings::default(),
        }
    }
}

impl Default for ShortcutSettings {
    fn default() -> Self {
        Self {
            toggle_panel: "CmdOrCtrl+Shift+N".to_string(),
            new_note: "CmdOrCtrl+Alt+N".to_string(),
            search_notes: "CmdOrCtrl+Shift+F".to_string(),
            toggle_pin: "CmdOrCtrl+Alt+P".to_string(),
        }
    }
}
