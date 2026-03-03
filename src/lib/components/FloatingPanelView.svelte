<script lang="ts">
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { activeView, editorFocusTrigger } from "../stores/ui";
  import { notes, selectedNote, editingContent, vaultPath } from "../stores/vault";
  import { settings } from "../stores/settings";
  import { getNotes, createNote, saveNote, getVaultPath } from "../commands/vault";
  import { getSettings, updateSettings } from "../commands/settings";
  import { getPinnedNotes, togglePin } from "../commands/pin";
  import { pinnedNoteIds } from "../stores/pin";
  import { setWindowPosition, getScreenBounds } from "../commands/window";
  import { debounce } from "../utils/debounce";
  import { listen } from "@tauri-apps/api/event";
  import { getCurrentWindow } from "@tauri-apps/api/window";
  import ToolbarView from "./ToolbarView.svelte";
  import SearchView from "./SearchView.svelte";
  import SettingsView from "./SettingsView.svelte";
  import VaultSetupView from "./VaultSetupView.svelte";
  import MarkdownEditor from "../editor/MarkdownEditor.svelte";
  import type { Note } from "../stores/vault";

  const debouncedSave = debounce(async (id: string, content: string) => {
    await saveNote(id, content);
  }, 500);

  onMount(() => {
    // Load initial data
    (async () => {
      // Load settings
      try {
        const s = await getSettings();
        settings.set(s);
        vaultPath.set(s.vault_path);
      } catch {}

      // Load vault
      try {
        const path = await getVaultPath();
        if (path) {
          vaultPath.set(path);
          await loadNotes();
        } else {
          activeView.set("vault-setup");
        }
      } catch {
        activeView.set("vault-setup");
      }

      // Load pinned notes
      try {
        const pinned = await getPinnedNotes();
        pinnedNoteIds.set(new Set(pinned));
      } catch {}
    })();

    // Listen for vault changes from file watcher
    listen("vault:notes-changed", async () => {
      await loadNotes();
    });

    // Listen for git status changes
    listen("git:status-changed", (event) => {
      // Will be handled by git sync store
    });

    // Listen for tray events
    listen("new-note", () => handleNewNote());
    listen("toggle-search", () => handleSearch());

    // Listen for global shortcut events
    const currentWindow = getCurrentWindow();
    listen("shortcut:toggle_panel", () => {
      currentWindow.isVisible().then((visible) => {
        if (visible) currentWindow.hide();
        else {
          currentWindow.show();
          currentWindow.setFocus();
        }
      });
    });
    listen("shortcut:new_note", () => handleNewNote());
    listen("shortcut:search_notes", () => handleSearch());
    listen("shortcut:toggle_pin", () => handleTogglePin());
    listen("shortcut:reset_position", async () => {
      const s = get(settings);
      const position = s.panel_position || "center";
      const panelW = s.panel_width || 480;
      const panelH = s.panel_height || 600;
      const margin = 20;
      try {
        const bounds = await getScreenBounds();
        let x = 0;
        let y = 0;
        if (position.includes("left")) x = bounds.x + margin;
        else if (position.includes("right")) x = bounds.x + bounds.width - panelW - margin;
        else x = bounds.x + Math.round((bounds.width - panelW) / 2);
        if (position.startsWith("top")) y = bounds.y + margin;
        else if (position.startsWith("bottom")) y = bounds.y + bounds.height - panelH - margin;
        else y = bounds.y + Math.round((bounds.height - panelH) / 2);
        await setWindowPosition(x, y);
        await updateSettings({ panel_x: x, panel_y: y });
      } catch {}
    });

    // Persist panel position on move (debounced 1s)
    let positionSaveTimeout: ReturnType<typeof setTimeout> | undefined;
    currentWindow.onMoved(({ payload }) => {
      clearTimeout(positionSaveTimeout);
      positionSaveTimeout = setTimeout(() => {
        updateSettings({ panel_x: payload.x, panel_y: payload.y });
      }, 1000);
    });

    // Global in-app keyboard shortcuts
    const isMac = navigator.platform?.includes("Mac");
    function handleGlobalKeydown(e: KeyboardEvent) {
      const mod = isMac ? e.metaKey : e.ctrlKey;
      if (mod && e.key === ",") {
        e.preventDefault();
        if ($activeView === "settings") {
          handleDismissOverlay();
        } else {
          handleSettings();
        }
      }
    }
    window.addEventListener("keydown", handleGlobalKeydown);
    return () => window.removeEventListener("keydown", handleGlobalKeydown);
  });

  async function loadNotes() {
    try {
      const loaded = await getNotes();
      notes.set(loaded);

      // Auto-select first note if none selected
      if (!$selectedNote && loaded.length > 0) {
        selectNoteById(loaded[0]);
      }

      // If selected note was deleted externally, select first
      if ($selectedNote && !loaded.find((n) => n.id === $selectedNote!.id)) {
        if (loaded.length > 0) {
          selectNoteById(loaded[0]);
        } else {
          selectedNote.set(null);
          editingContent.set("");
        }
      }
    } catch {}
  }

  function selectNoteById(note: Note) {
    selectedNote.set(note);
    editingContent.set(note.content);
    editorFocusTrigger.set(true);
  }

  async function handleNewNote() {
    activeView.set("editor");
    try {
      const note = await createNote();
      notes.update((n) => [note, ...n]);
      selectNoteById(note);
    } catch {}
  }

  function handleSearch() {
    editorFocusTrigger.set(false);
    activeView.set("search");
  }

  function handleSettings() {
    editorFocusTrigger.set(false);
    activeView.set("settings");
  }

  function handleDismissOverlay() {
    activeView.set("editor");
    editorFocusTrigger.set(true);
  }

  async function handleTogglePin() {
    const note = get(selectedNote);
    if (note) {
      const pinned = await togglePin(note.id);
      pinnedNoteIds.update((s) => {
        pinned ? s.add(note.id) : s.delete(note.id);
        return new Set(s);
      });
    }
  }

  function handleSelectNote(note: Note) {
    // Save current note before switching
    if ($selectedNote && $editingContent !== $selectedNote.content) {
      debouncedSave($selectedNote.id, $editingContent);
    }
    selectNoteById(note);
  }

  function handleContentChange(newContent: string) {
    editingContent.set(newContent);
    if ($selectedNote) {
      debouncedSave($selectedNote.id, newContent);
    }
  }

</script>

<div class="floating-panel" style="opacity: {$settings.panel_opacity}; background: var(--monokai-background)">
  {#if $activeView === "vault-setup"}
    <VaultSetupView />
  {:else}
    <ToolbarView
      onNewNote={handleNewNote}
      onSearch={handleSearch}
      onSettings={handleSettings}
      onTogglePin={handleTogglePin}
      isPinned={$selectedNote ? $pinnedNoteIds.has($selectedNote.id) : false}
      hasNote={!!$selectedNote}
    />
    <div class="divider"></div>

    {#if $activeView === "settings"}
      <div class="overlay-content">
        <SettingsView onDismiss={handleDismissOverlay} />
      </div>
    {:else if $activeView === "search"}
      <div class="overlay-content">
        <SearchView onSelectNote={handleSelectNote} onDismiss={handleDismissOverlay} />
      </div>
    {:else if $selectedNote}
      <div class="editor-content">
        <MarkdownEditor
          content={$editingContent}
          vaultPath={$vaultPath}
          shouldFocus={$editorFocusTrigger}
          onContentChange={handleContentChange}
        />
      </div>
    {:else}
      <div class="empty-state">
        <svg width="36" height="36" viewBox="0 0 16 16" fill="currentColor" class="empty-icon">
          <path d="M5 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2 2 2 0 0 1-2 2H3a2 2 0 0 1-2-2h1a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V4a1 1 0 0 0-1-1H3a1 1 0 0 0-1 1H1a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z"/>
        </svg>
        <p>No notes yet</p>
        <button class="create-btn" onclick={handleNewNote}>Create Note</button>
      </div>
    {/if}
  {/if}
</div>

<style>
  .floating-panel {
    display: flex;
    flex-direction: column;
    height: 100vh;
  }

  .divider {
    height: 1px;
    background: var(--monokai-border);
  }

  .overlay-content {
    flex: 1;
    overflow: hidden;
  }

  .editor-content {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .empty-state {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
  }

  .empty-icon {
    color: var(--monokai-comment);
  }

  .empty-state p {
    color: var(--monokai-comment);
    font-size: 14px;
  }

  .create-btn {
    background: var(--monokai-keyword);
    color: var(--monokai-foreground);
    border: none;
    padding: 6px 16px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
  }

  .create-btn:hover {
    opacity: 0.85;
  }
</style>
