import { writable } from "svelte/store";

export interface AppSettings {
  vault_path: string | null;
  font_family: string;
  font_size: number;
  panel_opacity: number;
  panel_position: string;
  panel_width: number;
  panel_height: number;
  panel_x: number | null;
  panel_y: number | null;
  git_sync_enabled: boolean;
  shortcuts: ShortcutSettings;
}

export interface ShortcutSettings {
  toggle_panel: string;
  new_note: string;
  search_notes: string;
  toggle_pin: string;
  reset_position: string;
}

export const DEFAULT_SETTINGS: AppSettings = {
  vault_path: null,
  font_family: "SF Mono",
  font_size: 14,
  panel_opacity: 1.0,
  panel_position: "center",
  panel_width: 480,
  panel_height: 600,
  panel_x: null,
  panel_y: null,
  git_sync_enabled: false,
  shortcuts: {
    toggle_panel: "CmdOrCtrl+Shift+N",
    new_note: "CmdOrCtrl+Alt+N",
    search_notes: "CmdOrCtrl+Shift+F",
    toggle_pin: "CmdOrCtrl+Alt+P",
    reset_position: "CmdOrCtrl+Shift+R",
  },
};

export const settings = writable<AppSettings>(DEFAULT_SETTINGS);
