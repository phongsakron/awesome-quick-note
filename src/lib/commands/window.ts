import { invoke } from "@tauri-apps/api/core";

export interface WindowPosition {
  x: number;
  y: number;
}

export interface ScreenBounds {
  x: number;
  y: number;
  width: number;
  height: number;
  scale_factor: number;
}

export async function getWindowPosition(): Promise<WindowPosition> {
  return invoke<WindowPosition>("get_window_position");
}

export async function setWindowPosition(x: number, y: number): Promise<void> {
  return invoke("set_window_position", { x, y });
}

export async function getScreenBounds(): Promise<ScreenBounds> {
  return invoke<ScreenBounds>("get_screen_bounds");
}

export async function revealInFileManager(path: string): Promise<void> {
  return invoke("reveal_in_file_manager", { path });
}
