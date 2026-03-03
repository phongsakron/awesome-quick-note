import { writable, get } from "svelte/store";

export interface Tab {
  id: string;         // note id
  title: string;
  isActive: boolean;
}

export const openTabs = writable<Tab[]>([]);

export function addTab(id: string, title: string): void {
  const tabs = get(openTabs);
  const existing = tabs.find(t => t.id === id);
  if (existing) {
    // Just activate it
    openTabs.set(tabs.map(t => ({ ...t, isActive: t.id === id })));
  } else {
    openTabs.set([
      ...tabs.map(t => ({ ...t, isActive: false })),
      { id, title, isActive: true }
    ]);
  }
}

export function removeTab(id: string): string | null {
  const tabs = get(openTabs);
  const idx = tabs.findIndex(t => t.id === id);
  if (idx === -1) return null;

  const wasActive = tabs[idx].isActive;
  const newTabs = tabs.filter(t => t.id !== id);

  if (wasActive && newTabs.length > 0) {
    // Activate the nearest tab
    const newIdx = Math.min(idx, newTabs.length - 1);
    newTabs[newIdx].isActive = true;
    openTabs.set(newTabs);
    return newTabs[newIdx].id;
  }

  openTabs.set(newTabs);
  return newTabs.length > 0 ? null : null;
}

export function updateTabTitle(id: string, title: string): void {
  openTabs.update(tabs => tabs.map(t => t.id === id ? { ...t, title } : t));
}

export function setActiveTab(id: string): void {
  openTabs.update(tabs => tabs.map(t => ({ ...t, isActive: t.id === id })));
}
