use crate::models::git_status::GitSyncStatus;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tauri::{AppHandle, Emitter};

pub struct GitSyncManager {
    status: Mutex<GitSyncStatus>,
    enabled: Mutex<bool>,
    vault_path: Mutex<Option<PathBuf>>,
    has_remote: Mutex<bool>,
    last_sync: Mutex<Option<i64>>,
    file_changed: AtomicBool,
}

impl GitSyncManager {
    pub fn new() -> Self {
        Self {
            status: Mutex::new(GitSyncStatus::Disabled),
            enabled: Mutex::new(false),
            vault_path: Mutex::new(None),
            has_remote: Mutex::new(false),
            last_sync: Mutex::new(None),
            file_changed: AtomicBool::new(false),
        }
    }

    pub fn status(&self) -> GitSyncStatus {
        self.status.lock().unwrap().clone()
    }

    pub fn last_sync(&self) -> Option<i64> {
        *self.last_sync.lock().unwrap()
    }

    pub fn is_enabled(&self) -> bool {
        *self.enabled.lock().unwrap()
    }

    fn set_status(&self, status: GitSyncStatus) {
        *self.status.lock().unwrap() = status;
    }

    pub fn configure(&self, vault_path: Option<PathBuf>, app_handle: &AppHandle) {
        *self.vault_path.lock().unwrap() = vault_path.clone();

        if !self.is_enabled() {
            self.set_status(GitSyncStatus::Disabled);
            return;
        }

        let vault = match vault_path {
            Some(v) => v,
            None => {
                self.set_status(GitSyncStatus::NotARepo);
                return;
            }
        };

        if !Self::check_is_git_repo(&vault) {
            self.set_status(GitSyncStatus::NotARepo);
            return;
        }

        let has_remote = Self::check_has_remote(&vault);
        *self.has_remote.lock().unwrap() = has_remote;

        if has_remote {
            self.set_status(GitSyncStatus::Idle);
            // Do initial pull
            let _ = Self::run_git(&["pull", "--rebase", "--autostash"], &vault);
        } else {
            self.set_status(GitSyncStatus::NoRemote);
        }

        self.emit_status(app_handle);
    }

    pub fn set_enabled(&self, enabled: bool, app_handle: &AppHandle) {
        *self.enabled.lock().unwrap() = enabled;
        if enabled {
            let vault = self.vault_path.lock().unwrap().clone();
            self.configure(vault, app_handle);
        } else {
            self.set_status(GitSyncStatus::Disabled);
            self.emit_status(app_handle);
        }
    }

    pub fn notify_file_changed(&self) {
        if !self.is_enabled() {
            return;
        }
        self.file_changed.store(true, Ordering::Relaxed);
    }

    pub fn manual_sync(&self, app_handle: &AppHandle) {
        if !self.is_enabled() {
            return;
        }
        let vault = self.vault_path.lock().unwrap().clone();
        if let Some(vault) = vault {
            if !Self::check_is_git_repo(&vault) {
                self.set_status(GitSyncStatus::NotARepo);
                self.emit_status(app_handle);
                return;
            }
            *self.has_remote.lock().unwrap() = Self::check_has_remote(&vault);
            self.run_sync_cycle(&vault, app_handle);
        }
    }

    fn run_sync_cycle(&self, vault: &Path, app_handle: &AppHandle) {
        self.set_status(GitSyncStatus::Syncing);
        self.emit_status(app_handle);

        let has_remote = *self.has_remote.lock().unwrap();

        // Pull with rebase if remote exists
        if has_remote {
            if let Err(e) = Self::run_git(&["pull", "--rebase", "--autostash"], vault) {
                if e.contains("CONFLICT") || e.contains("conflict") {
                    self.set_status(GitSyncStatus::Error(
                        "Merge conflict — resolve in terminal, then retry".to_string(),
                    ));
                } else {
                    self.set_status(GitSyncStatus::Error(e));
                }
                self.emit_status(app_handle);
                return;
            }
        }

        // Stage all changes
        if let Err(e) = Self::run_git(&["add", "-A"], vault) {
            self.set_status(GitSyncStatus::Error(e));
            self.emit_status(app_handle);
            return;
        }

        // Check if there's anything to commit
        let has_staged = Self::run_git(&["diff", "--cached", "--quiet"], vault).is_err();

        if has_staged {
            let timestamp = chrono::Utc::now().format("%Y-%m-%d %H:%M:%S").to_string();
            let msg = format!("Auto-sync: {}", timestamp);
            if let Err(e) = Self::run_git(&["commit", "-m", &msg], vault) {
                self.set_status(GitSyncStatus::Error(e));
                self.emit_status(app_handle);
                return;
            }
        }

        // Push if remote exists
        if has_remote {
            if let Err(e) = Self::run_git(&["push"], vault) {
                self.set_status(GitSyncStatus::Error(e));
                self.emit_status(app_handle);
                return;
            }
        }

        *self.last_sync.lock().unwrap() = Some(chrono::Utc::now().timestamp_millis());
        self.set_status(if has_remote {
            GitSyncStatus::Idle
        } else {
            GitSyncStatus::NoRemote
        });
        self.emit_status(app_handle);
    }

    pub fn start_background_tasks(self: &Arc<Self>, app_handle: AppHandle) {
        // Combined background thread: checks for file changes every 5s, periodic pull every 5min
        let manager = Arc::clone(self);
        let handle = app_handle.clone();

        std::thread::spawn(move || {
            let mut ticks_since_pull: u64 = 0;
            loop {
                std::thread::sleep(Duration::from_secs(5));
                ticks_since_pull += 1;

                if !manager.is_enabled() {
                    continue;
                }

                // Check if file changed (debounced sync)
                if manager.file_changed.swap(false, Ordering::Relaxed) {
                    let vault = manager.vault_path.lock().unwrap().clone();
                    if let Some(vault) = vault {
                        manager.run_sync_cycle(&vault, &handle);
                    }
                }

                // Periodic pull every 5 minutes (60 ticks * 5s = 300s)
                if ticks_since_pull >= 60 {
                    ticks_since_pull = 0;
                    let has_remote = *manager.has_remote.lock().unwrap();
                    if !has_remote {
                        continue;
                    }

                    let vault = manager.vault_path.lock().unwrap().clone();
                    if let Some(vault) = vault {
                        let prev = manager.status();
                        manager.set_status(GitSyncStatus::Syncing);
                        manager.emit_status(&handle);

                        let _ = Self::run_git(&["pull", "--rebase", "--autostash"], &vault);

                        if *manager.status.lock().unwrap() == GitSyncStatus::Syncing {
                            manager.set_status(if prev == GitSyncStatus::Syncing {
                                GitSyncStatus::Idle
                            } else {
                                prev
                            });
                            manager.emit_status(&handle);
                        }
                    }
                }
            }
        });
    }

    fn emit_status(&self, app_handle: &AppHandle) {
        let status = self.status();
        let _ = app_handle.emit("git:status-changed", &status);
    }

    fn check_is_git_repo(path: &Path) -> bool {
        Self::run_git(&["rev-parse", "--is-inside-work-tree"], path).is_ok()
    }

    fn check_has_remote(path: &Path) -> bool {
        match Self::run_git(&["remote"], path) {
            Ok(output) => !output.trim().is_empty(),
            Err(_) => false,
        }
    }

    fn run_git(args: &[&str], working_dir: &Path) -> Result<String, String> {
        let output = Command::new("git")
            .args(args)
            .current_dir(working_dir)
            .output()
            .map_err(|e| e.to_string())?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            Err(if stderr.is_empty() { stdout } else { stderr })
        }
    }
}
