import { writable } from "svelte/store";

export type OverlayView = "editor" | "search" | "settings" | "vault-setup";

export const activeView = writable<OverlayView>("editor");
export const editorFocusTrigger = writable(false);
