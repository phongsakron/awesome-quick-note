/**
 * Toggle checkbox state: [ ] <-> [x]
 */

export function handleCheckboxClick(
  text: string,
  clickOffset: number,
): { newText: string; changed: boolean } {
  // Find which line the click is on
  const lines = text.split("\n");
  let offset = 0;
  for (let i = 0; i < lines.length; i++) {
    const lineEnd = offset + lines[i].length;
    if (clickOffset >= offset && clickOffset <= lineEnd) {
      const line = lines[i];
      // Check if clicked near a checkbox
      const checkboxMatch = line.match(/^(\s*[-*+]\s)\[( |x|X)\]/);
      if (checkboxMatch) {
        const checkboxStart = offset + checkboxMatch[1].length;
        const checkboxEnd = checkboxStart + 3; // [x] or [ ]
        if (clickOffset >= checkboxStart && clickOffset <= checkboxEnd) {
          const isChecked = checkboxMatch[2] !== " ";
          const newCheckbox = isChecked ? "[ ]" : "[x]";
          const newLine =
            line.slice(0, checkboxMatch[1].length) +
            newCheckbox +
            line.slice(checkboxMatch[1].length + 3);
          lines[i] = newLine;
          return { newText: lines.join("\n"), changed: true };
        }
      }
      break;
    }
    offset = lineEnd + 1; // +1 for newline
  }
  return { newText: text, changed: false };
}
