use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Note {
    pub id: String,
    pub file_name: String,
    pub file_path: String,
    pub content: String,
    pub title: String,
    pub created_at: i64,  // Unix timestamp ms
    pub modified_at: i64, // Unix timestamp ms
}

impl Note {
    pub fn derive_title(content: &str, file_name: &str) -> String {
        for line in content.lines() {
            let trimmed = line.trim();
            if !trimmed.is_empty() {
                if let Some(heading) = trimmed.strip_prefix("# ") {
                    return heading.trim().to_string();
                }
                break;
            }
        }
        // Fallback to filename without extension
        file_name
            .strip_suffix(".md")
            .unwrap_or(file_name)
            .to_string()
    }
}
