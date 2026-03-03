/**
 * Editor keybinding handler for keyboard shortcuts within the editor.
 */

export interface KeybindingAction {
  key: string;
  mod?: boolean; // Cmd on macOS, Ctrl on Linux
  shift?: boolean;
  alt?: boolean;
  action: (editor: HTMLDivElement) => void;
}

const isMac =
  typeof navigator !== "undefined" && navigator.platform?.includes("Mac");

export function matchKeybinding(
  e: KeyboardEvent,
  bindings: KeybindingAction[],
): KeybindingAction | undefined {
  const mod = isMac ? e.metaKey : e.ctrlKey;

  return bindings.find((b) => {
    if (b.key.toLowerCase() !== e.key.toLowerCase()) return false;
    if (b.mod && !mod) return false;
    if (!b.mod && mod) return false;
    if (b.shift && !e.shiftKey) return false;
    if (!b.shift && e.shiftKey) return false;
    if (b.alt && !e.altKey) return false;
    if (!b.alt && e.altKey) return false;
    return true;
  });
}
