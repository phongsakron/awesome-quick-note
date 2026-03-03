/**
 * Handle Cmd+Click on links and images to open externally.
 */

import { open } from "@tauri-apps/plugin-shell";

export function handleLinkClick(
  event: MouseEvent,
  editor: HTMLDivElement,
): boolean {
  const isMac =
    typeof navigator !== "undefined" && navigator.platform?.includes("Mac");
  const modKey = isMac ? event.metaKey : event.ctrlKey;

  if (!modKey) return false;

  const target = event.target as HTMLElement;

  // Check if clicking on a link URL span
  if (
    target.classList.contains("md-link-url") ||
    target.classList.contains("md-link-text")
  ) {
    // Find the URL in the nearby spans
    const parent = target.parentElement;
    if (parent) {
      const urlSpan = parent.querySelector(".md-link-url");
      if (urlSpan) {
        const url = urlSpan.textContent?.trim();
        if (url) {
          open(url);
          return true;
        }
      }
    }
  }

  return false;
}
