import { invoke } from "@tauri-apps/api/core";

export async function registerShortcuts(): Promise<void> {
  return invoke("register_shortcuts");
}
