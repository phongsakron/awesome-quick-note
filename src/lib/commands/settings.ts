import { invoke } from "@tauri-apps/api/core";
import type { AppSettings } from "../stores/settings";

export async function getSettings(): Promise<AppSettings> {
  return invoke<AppSettings>("get_settings");
}

export async function updateSettings(settings: Partial<AppSettings>): Promise<void> {
  return invoke("update_settings", { settings });
}
