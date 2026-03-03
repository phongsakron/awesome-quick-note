import { invoke } from "@tauri-apps/api/core";

export async function togglePin(noteId: string): Promise<boolean> {
  return invoke<boolean>("toggle_pin", { noteId });
}

export async function getPinnedNotes(): Promise<string[]> {
  return invoke<string[]>("get_pinned_notes");
}
