import { invoke } from "@tauri-apps/api/core";
import type { Note } from "../stores/vault";

export async function selectVault(): Promise<string | null> {
  return invoke<string | null>("select_vault");
}

export async function setVault(path: string): Promise<void> {
  return invoke("set_vault", { path });
}

export async function getNotes(): Promise<Note[]> {
  return invoke<Note[]>("get_notes");
}

export async function createNote(): Promise<Note> {
  return invoke<Note>("create_note");
}

export async function saveNote(id: string, content: string): Promise<void> {
  return invoke("save_note", { id, content });
}

export async function deleteNote(id: string): Promise<void> {
  return invoke("delete_note", { id });
}

export async function getVaultPath(): Promise<string | null> {
  return invoke<string | null>("get_vault_path");
}
