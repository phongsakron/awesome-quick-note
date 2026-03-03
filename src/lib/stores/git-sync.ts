import { writable } from "svelte/store";

export type GitSyncStatus =
  | "disabled"
  | "not_a_repo"
  | "idle"
  | "syncing"
  | "no_remote"
  | { error: string };

export const gitSyncStatus = writable<GitSyncStatus>("disabled");
export const lastSyncDate = writable<number | null>(null);
