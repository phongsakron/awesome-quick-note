import { writable } from "svelte/store";

export const pinnedNoteIds = writable<Set<string>>(new Set());
