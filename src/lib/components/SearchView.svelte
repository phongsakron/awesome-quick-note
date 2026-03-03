<script lang="ts">
  import { searchQuery, searchResults, selectedIndex } from "../stores/search";
  import { pinnedNoteIds } from "../stores/pin";
  import { searchNotes } from "../commands/search";
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

  async function loadResults(query: string) {
    const results = await searchNotes(query);
    searchResults.set(results);
    selectedIndex.set(0);
  }

  async function handleInput(e: Event) {
    const query = (e.target as HTMLInputElement).value;
    searchQuery.set(query);
    await loadResults(query);
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
  </div>
  <div class="search-results">
    {#each $searchResults as result, i}
      <button
        class="search-result"
        class:selected={i === $selectedIndex}
        onclick={() => { onSelectNote(result.note); onDismiss(); }}
        onmouseenter={() => selectedIndex.set(i)}
      >
        <span class="result-title">
          {#if $pinnedNoteIds.has(result.note.id)}
            <span class="pin-indicator" title="Pinned">&#128204;</span>
          {/if}
          {result.note.title}
        </span>
        <span class="result-date">
          {new Date(result.note.modified_at).toLocaleDateString()}
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

  .search-results {
    flex: 1;
    overflow-y: auto;
  }

  .search-result {
    display: flex;
    align-items: center;
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

  .result-title {
    display: flex;
    align-items: center;
    gap: 4px;
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
