import { invoke } from "@tauri-apps/api/core";
import type { GitSyncStatus } from "../stores/git-sync";

export async function getGitSyncStatus(): Promise<GitSyncStatus> {
  return invoke<GitSyncStatus>("get_git_sync_status");
}

export async function manualSync(): Promise<void> {
  return invoke("manual_sync");
}

export async function setGitSyncEnabled(enabled: boolean): Promise<void> {
  return invoke("set_git_sync_enabled", { enabled });
}
