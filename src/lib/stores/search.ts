import { writable } from "svelte/store";
import type { Note } from "./vault";

export interface SearchResult {
  note: Note;
  score: number;
  snippet: string;
}

export const searchQuery = writable("");
export const searchResults = writable<SearchResult[]>([]);
export const selectedIndex = writable(0);
