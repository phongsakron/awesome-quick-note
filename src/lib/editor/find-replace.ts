/**
 * Find and replace functionality for the editor.
 */

export interface FindState {
  query: string;
  replaceWith: string;
  currentIndex: number;
  matches: { start: number; end: number }[];
  isActive: boolean;
  showReplace: boolean;
}

export function createFindState(): FindState {
  return {
    query: "",
    replaceWith: "",
    currentIndex: -1,
    matches: [],
    isActive: false,
    showReplace: false,
  };
}

export function findMatches(text: string, query: string): { start: number; end: number }[] {
  if (!query) return [];

  const matches: { start: number; end: number }[] = [];
  const lowerText = text.toLowerCase();
  const lowerQuery = query.toLowerCase();
  let idx = 0;

  while (idx < lowerText.length) {
    const found = lowerText.indexOf(lowerQuery, idx);
    if (found === -1) break;
    matches.push({ start: found, end: found + query.length });
    idx = found + 1;
  }

  return matches;
}

export function replaceOne(
  text: string,
  match: { start: number; end: number },
  replaceWith: string,
): string {
  return text.slice(0, match.start) + replaceWith + text.slice(match.end);
}

export function replaceAll(
  text: string,
  query: string,
  replaceWith: string,
): string {
  if (!query) return text;
  // Case-insensitive replace all
  const regex = new RegExp(
    query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"),
    "gi",
  );
  return text.replace(regex, replaceWith);
}
