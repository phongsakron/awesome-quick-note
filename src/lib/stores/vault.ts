import { writable } from "svelte/store";

export interface Note {
  id: string;
  file_name: string;
  file_path: string;
  content: string;
  title: string;
  created_at: number;
  modified_at: number;
}

export const notes = writable<Note[]>([]);
export const selectedNote = writable<Note | null>(null);
export const editingContent = writable("");
export const vaultPath = writable<string | null>(null);
