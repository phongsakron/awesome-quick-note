import { invoke } from "@tauri-apps/api/core";

export async function saveImage(imageData: number[]): Promise<string> {
  return invoke<string>("save_image", { imageData });
}
