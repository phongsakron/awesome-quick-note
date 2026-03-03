import { invoke } from "@tauri-apps/api/core";

interface GitSyncEvent {
  status: unknown;
  last_commit_date: number | null;
}

export async function getGitSyncStatus(): Promise<GitSyncEvent> {
  return invoke<GitSyncEvent>("get_git_sync_status");
}

export async function manualSync(): Promise<void> {
  return invoke("manual_sync");
}

export async function setGitSyncEnabled(enabled: boolean): Promise<void> {
  return invoke("set_git_sync_enabled", { enabled });
}
