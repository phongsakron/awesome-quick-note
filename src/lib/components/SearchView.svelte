<script lang="ts">
  import { get } from "svelte/store";
  import { searchQuery, searchResults, selectedIndex } from "../stores/search";
  import { pinnedNoteIds } from "../stores/pin";
  import { searchNotes } from "../commands/search";
  import { relativeDate } from "../utils/relative-date";
  import type { Note } from "../stores/vault";

  interface Props {
    onSelectNote: (note: Note) => void;
    onDismiss: () => void;
  }

  let { onSelectNote, onDismiss }: Props = $props();
  let inputEl: HTMLInputElement | undefined = $state();

  $effect(() => {
    if (inputEl) {
      inputEl.focus();
      // Load all notes when search opens
      loadResults("");
    }
  });

  // B13: Auto-scroll selected result into view
  $effect(() => {
    const idx = $selectedIndex;
    const resultContainer = document.querySelector('.search-results');
    if (resultContainer) {
      const selected = resultContainer.children[idx] as HTMLElement;
      if (selected) {
        selected.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      }
    }
  });

  async function loadResults(query: string) {
    const results = await searchNotes(query);
    // B10: Sort pinned notes to top
    const pinned = get(pinnedNoteIds);
    results.sort((a, b) => {
      const aPinned = pinned.has(a.note.id) ? 1 : 0;
      const bPinned = pinned.has(b.note.id) ? 1 : 0;
      return bPinned - aPinned;
    });
    searchResults.set(results);
    selectedIndex.set(0);
  }

  async function handleInput(e: Event) {
    const query = (e.target as HTMLInputElement).value;
    searchQuery.set(query);
    await loadResults(query);
  }

  function clearSearch() {
    searchQuery.set("");
    loadResults("");
    if (inputEl) {
      inputEl.value = "";
      inputEl.focus();
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") {
      e.preventDefault();
      onDismiss();
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      selectedIndex.update((i) => Math.min(i + 1, $searchResults.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      selectedIndex.update((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      const result = $searchResults[$selectedIndex];
      if (result) {
        onSelectNote(result.note);
        onDismiss();
      }
    }
  }
</script>

<div class="search-view">
  <div class="search-input-container">
    <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" class="search-icon">
      <path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85zm-5.242.156a5 5 0 1 1 0-10 5 5 0 0 1 0 10z"/>
    </svg>
    <input
      bind:this={inputEl}
      type="text"
      class="search-input"
      placeholder="Search notes..."
      value={$searchQuery}
      oninput={handleInput}
      onkeydown={handleKeydown}
    />
    {#if $searchQuery}
      <button class="clear-btn" onclick={clearSearch}>
        <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor">
          <path d="M4.646 4.646a.5.5 0 0 1 .708 0L8 7.293l2.646-2.647a.5.5 0 0 1 .708.708L8.707 8l2.647 2.646a.5.5 0 0 1-.708.708L8 8.707l-2.646 2.647a.5.5 0 0 1-.708-.708L7.293 8 4.646 5.354a.5.5 0 0 1 0-.708z"/>
        </svg>
      </button>
    {/if}
  </div>
  <div class="search-results">
    {#each $searchResults as result, i}
      <button
        class="search-result"
        class:selected={i === $selectedIndex}
        onclick={() => { onSelectNote(result.note); onDismiss(); }}
        onmouseenter={() => selectedIndex.set(i)}
      >
        <div class="result-main">
          <span class="result-title">
            {#if $pinnedNoteIds.has(result.note.id)}
              <span class="pin-indicator" title="Pinned">&#128204;</span>
            {/if}
            {result.note.title}
          </span>
          {#if result.snippet}
            <span class="result-snippet">{result.snippet}</span>
          {/if}
        </div>
        <span class="result-date">
          {relativeDate(result.note.modified_at)}
        </span>
      </button>
    {/each}
    {#if $searchResults.length === 0}
      <div class="no-results">{$searchQuery ? "No notes found" : "No notes yet"}</div>
    {/if}
  </div>
</div>

<style>
  .search-view {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 8px;
  }

  .search-input-container {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    background: var(--monokai-tab-background);
    border-radius: 6px;
    margin-bottom: 8px;
  }

  .search-icon {
    color: var(--monokai-comment);
    flex-shrink: 0;
  }

  .search-input {
    background: none;
    border: none;
    color: var(--monokai-foreground);
    font-size: 14px;
    width: 100%;
    outline: none;
    font-family: inherit;
  }

  .search-input::placeholder {
    color: var(--monokai-comment);
  }

  .clear-btn {
    background: none;
    border: none;
    color: var(--monokai-comment);
    cursor: pointer;
    padding: 2px;
    border-radius: 4px;
    display: flex;
    flex-shrink: 0;
  }

  .clear-btn:hover {
    color: var(--monokai-foreground);
  }

  .search-results {
    flex: 1;
    overflow-y: auto;
  }

  .search-result {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    width: 100%;
    padding: 8px 12px;
    background: none;
    border: none;
    color: var(--monokai-foreground);
    cursor: pointer;
    border-radius: 4px;
    text-align: left;
    font-size: 13px;
    transition: background 0.1s;
  }

  .search-result.selected,
  .search-result:hover {
    background: var(--monokai-tab-active-background);
  }

  .result-main {
    display: flex;
    flex-direction: column;
    gap: 2px;
    overflow: hidden;
    flex: 1;
  }

  .result-title {
    display: flex;
    align-items: center;
    gap: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .result-snippet {
    font-size: 11px;
    color: var(--monokai-comment);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .pin-indicator {
    font-size: 11px;
  }

  .result-date {
    color: var(--monokai-comment);
    font-size: 11px;
    flex-shrink: 0;
    margin-left: 8px;
  }

  .no-results {
    text-align: center;
    color: var(--monokai-comment);
    padding: 24px;
    font-size: 13px;
  }
</style>
