/**
 * Smart list continuation on Enter key.
 * - Bullets: -, *, +
 * - Numbered: 1. 2. etc.
 * - Checkboxes: - [ ] / - [x]
 * - Empty list item removes the marker
 */

export interface ListContinuationResult {
  handled: boolean;
  newText?: string;
  cursorOffset?: number;
}

export function handleListContinuation(
  text: string,
  cursorPos: number,
): ListContinuationResult {
  // Find the current line
  const beforeCursor = text.slice(0, cursorPos);
  const lastNewline = beforeCursor.lastIndexOf("\n");
  const currentLine = beforeCursor.slice(lastNewline + 1);

  // Check for empty list item (remove it)
  const emptyBullet = currentLine.match(/^(\s*)([-*+])\s*$/);
  if (emptyBullet) {
    const lineStart = lastNewline + 1;
    const newText = text.slice(0, lineStart) + text.slice(cursorPos);
    return { handled: true, newText, cursorOffset: lineStart };
  }

  const emptyNumber = currentLine.match(/^(\s*)(\d+)\.\s*$/);
  if (emptyNumber) {
    const lineStart = lastNewline + 1;
    const newText = text.slice(0, lineStart) + text.slice(cursorPos);
    return { handled: true, newText, cursorOffset: lineStart };
  }

  const emptyCheckbox = currentLine.match(/^(\s*)([-*+])\s\[[ xX]\]\s*$/);
  if (emptyCheckbox) {
    const lineStart = lastNewline + 1;
    const newText = text.slice(0, lineStart) + text.slice(cursorPos);
    return { handled: true, newText, cursorOffset: lineStart };
  }

  // Checkbox continuation
  const checkboxMatch = currentLine.match(/^(\s*)([-*+])\s\[[ xX]\]\s/);
  if (checkboxMatch) {
    const indent = checkboxMatch[1];
    const marker = checkboxMatch[2];
    const continuation = `\n${indent}${marker} [ ] `;
    const newText =
      text.slice(0, cursorPos) + continuation + text.slice(cursorPos);
    return {
      handled: true,
      newText,
      cursorOffset: cursorPos + continuation.length,
    };
  }

  // Bullet continuation
  const bulletMatch = currentLine.match(/^(\s*)([-*+])\s/);
  if (bulletMatch) {
    const indent = bulletMatch[1];
    const marker = bulletMatch[2];
    const continuation = `\n${indent}${marker} `;
    const newText =
      text.slice(0, cursorPos) + continuation + text.slice(cursorPos);
    return {
      handled: true,
      newText,
      cursorOffset: cursorPos + continuation.length,
    };
  }

  // Numbered list continuation
  const numberMatch = currentLine.match(/^(\s*)(\d+)\.\s/);
  if (numberMatch) {
    const indent = numberMatch[1];
    const num = parseInt(numberMatch[2]) + 1;
    const continuation = `\n${indent}${num}. `;
    const newText =
      text.slice(0, cursorPos) + continuation + text.slice(cursorPos);
    return {
      handled: true,
      newText,
      cursorOffset: cursorPos + continuation.length,
    };
  }

  return { handled: false };
}
