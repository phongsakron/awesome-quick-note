import { invoke } from "@tauri-apps/api/core";
import type { SearchResult } from "../stores/search";

export async function searchNotes(query: string): Promise<SearchResult[]> {
  return invoke<SearchResult[]>("search_notes", { query });
}
