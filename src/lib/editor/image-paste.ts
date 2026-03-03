/**
 * Handle image paste/drop into the editor.
 * Converts clipboard/drop image data to bytes, sends to Rust backend.
 */

import { saveImage } from "../commands/image";

export async function handleImagePaste(
  clipboardData: DataTransfer,
): Promise<string | null> {
  const items = Array.from(clipboardData.items);
  const imageItem = items.find((item) => item.type.startsWith("image/"));

  if (!imageItem) return null;

  const file = imageItem.getAsFile();
  if (!file) return null;

  return await saveImageFile(file);
}

export async function handleImageDrop(
  dataTransfer: DataTransfer,
): Promise<string | null> {
  const files = Array.from(dataTransfer.files);
  const imageFile = files.find((f) => f.type.startsWith("image/"));

  if (!imageFile) return null;

  return await saveImageFile(imageFile);
}

async function saveImageFile(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const bytes = Array.from(new Uint8Array(buffer));
  return await saveImage(bytes);
}
