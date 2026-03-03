import { invoke } from "@tauri-apps/api/core";

export async function saveImage(imageData: number[]): Promise<string> {
  return invoke<string>("save_image", { imageData });
}

export async function copyImageToClipboard(imagePath: string): Promise<void> {
  return invoke<void>("copy_image_to_clipboard", { imagePath });
}

export async function openFile(path: string): Promise<void> {
  return invoke<void>("open_file", { path });
}
