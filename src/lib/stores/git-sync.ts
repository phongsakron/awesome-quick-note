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
export const lastCommitDate = writable<number | null>(null);

// Rust serde tagged enum produces { type: "idle" } or { type: "error", message: "..." }
// Convert to the frontend's simpler format
export function parseRustStatus(raw: unknown): GitSyncStatus {
  if (typeof raw === "string") return raw as GitSyncStatus;
  if (typeof raw === "object" && raw !== null && "type" in raw) {
    const obj = raw as { type: string; message?: string };
    if (obj.type === "error" && obj.message) return { error: obj.message };
    return obj.type as GitSyncStatus;
  }
  return "disabled";
}
