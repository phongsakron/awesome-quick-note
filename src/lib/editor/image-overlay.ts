/**
 * Inline image preview overlay.
 * Shows image thumbnails for markdown image syntax when cursor is not on that line.
 */

export function updateImageOverlays(
  editorEl: HTMLDivElement,
  vaultPath: string | null,
): void {
  // Remove existing overlays
  editorEl.querySelectorAll(".image-overlay").forEach((el) => el.remove());

  if (!vaultPath) return;

  // Find image markers
  const imageMarkers = editorEl.querySelectorAll(".md-image-marker");
  const processed = new Set<Element>();

  for (const marker of imageMarkers) {
    const lineEl = marker.parentElement;
    if (!lineEl || processed.has(lineEl)) continue;
    processed.add(lineEl);

    // Extract image URL from the line
    const urlSpan = lineEl.querySelector(".md-link-url");
    if (!urlSpan) continue;

    const imgPath = urlSpan.textContent?.trim();
    if (!imgPath) continue;

    // Resolve relative path
    let fullPath: string;
    if (imgPath.startsWith("http://") || imgPath.startsWith("https://")) {
      fullPath = imgPath;
    } else {
      fullPath = `${vaultPath}/${imgPath}`;
    }

    // Create image overlay
    const overlay = document.createElement("div");
    overlay.className = "image-overlay";
    overlay.contentEditable = "false";

    const img = document.createElement("img");
    // For local files, use the asset protocol
    img.src = fullPath.startsWith("http")
      ? fullPath
      : `asset://localhost/${encodeURI(fullPath)}`;
    img.alt = "Image preview";
    img.style.maxWidth = "100%";
    img.style.maxHeight = "200px";
    img.style.borderRadius = "4px";
    img.style.marginTop = "4px";
    img.style.marginBottom = "4px";
    img.onerror = () => {
      overlay.remove();
    };

    overlay.appendChild(img);

    // Add button bar with Open and Copy Path buttons
    const btnBar = document.createElement("div");
    btnBar.className = "image-overlay-buttons";

    const openBtn = document.createElement("button");
    openBtn.className = "image-overlay-btn";
    openBtn.textContent = "Open";
    openBtn.contentEditable = "false";
    openBtn.onclick = async (e) => {
      e.preventDefault();
      e.stopPropagation();
      try {
        const { open } = await import("@tauri-apps/plugin-shell");
        await open(
          fullPath.startsWith("http") ? fullPath : `file://${fullPath}`,
        );
      } catch {
        // Silently fail if shell plugin is unavailable
      }
    };

    const copyBtn = document.createElement("button");
    copyBtn.className = "image-overlay-btn";
    copyBtn.textContent = "Copy Path";
    copyBtn.contentEditable = "false";
    copyBtn.onclick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      navigator.clipboard.writeText(imgPath);
      copyBtn.textContent = "Copied!";
      setTimeout(() => {
        copyBtn.textContent = "Copy Path";
      }, 1500);
    };

    btnBar.appendChild(openBtn);
    btnBar.appendChild(copyBtn);
    overlay.appendChild(btnBar);

    lineEl.after(overlay);
  }
}
