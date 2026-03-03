import { invoke } from "@tauri-apps/api/core";

export interface PlatformInfo {
  os: string;
  display_server: "wayland" | "x11" | "macos";
}

let cachedPlatformInfo: PlatformInfo | null = null;

export async function getPlatformInfo(): Promise<PlatformInfo> {
  if (cachedPlatformInfo) return cachedPlatformInfo;
  cachedPlatformInfo = await invoke<PlatformInfo>("get_platform_info");
  return cachedPlatformInfo;
}

export async function isWayland(): Promise<boolean> {
  const info = await getPlatformInfo();
  return info.display_server === "wayland";
}

export async function isMacOS(): Promise<boolean> {
  const info = await getPlatformInfo();
  return info.os === "macos";
}

export function modifierKey(): string {
  // Navigator check for quick sync detection
  if (typeof navigator !== "undefined" && navigator.platform?.includes("Mac")) {
    return "⌘";
  }
  return "Ctrl";
}
