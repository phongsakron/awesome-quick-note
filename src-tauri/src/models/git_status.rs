use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", content = "message")]
pub enum GitSyncStatus {
    #[serde(rename = "disabled")]
    Disabled,
    #[serde(rename = "not_a_repo")]
    NotARepo,
    #[serde(rename = "idle")]
    Idle,
    #[serde(rename = "syncing")]
    Syncing,
    #[serde(rename = "no_remote")]
    NoRemote,
    #[serde(rename = "error")]
    Error(String),
}
