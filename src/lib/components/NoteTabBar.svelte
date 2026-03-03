<script lang="ts">
  import { openTabs, removeTab, setActiveTab } from "../stores/tabs";

  interface Props {
    onSelectTab: (id: string) => void;
    onCloseTab: (id: string) => string | null;
  }

  let { onSelectTab, onCloseTab }: Props = $props();

  function handleSelect(id: string) {
    setActiveTab(id);
    onSelectTab(id);
  }

  function handleClose(e: MouseEvent, id: string) {
    e.stopPropagation();
    const nextId = onCloseTab(id);
    if (nextId) {
      onSelectTab(nextId);
    }
  }
</script>

{#if $openTabs.length > 1}
  <div class="tab-bar">
    {#each $openTabs as tab (tab.id)}
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="tab"
        class:active={tab.isActive}
        onclick={() => handleSelect(tab.id)}
        onkeydown={(e) => { if (e.key === 'Enter') handleSelect(tab.id); }}
        title={tab.title}
      >
        <span class="tab-title">{tab.title}</span>
        <button
          class="tab-close"
          onclick={(e) => handleClose(e, tab.id)}
          title="Close tab"
        >
          <svg width="10" height="10" viewBox="0 0 16 16" fill="currentColor">
            <path d="M4.646 4.646a.5.5 0 0 1 .708 0L8 7.293l2.646-2.647a.5.5 0 0 1 .708.708L8.707 8l2.647 2.646a.5.5 0 0 1-.708.708L8 8.707l-2.646 2.647a.5.5 0 0 1-.708-.708L7.293 8 4.646 5.354a.5.5 0 0 1 0-.708z"/>
          </svg>
        </button>
      </div>
    {/each}
  </div>
{/if}

<style>
  .tab-bar {
    display: flex;
    overflow-x: auto;
    background: var(--monokai-toolbar-background);
    border-bottom: 1px solid var(--monokai-border);
    min-height: 28px;
    scrollbar-width: none;
  }

  .tab-bar::-webkit-scrollbar {
    display: none;
  }

  .tab {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 4px 8px;
    background: none;
    border: none;
    border-right: 1px solid var(--monokai-border);
    color: var(--monokai-comment);
    font-size: 11px;
    cursor: pointer;
    white-space: nowrap;
    max-width: 150px;
    transition: background 0.1s, color 0.1s;
    flex-shrink: 0;
  }

  .tab:hover {
    background: var(--monokai-tab-background);
    color: var(--monokai-foreground);
  }

  .tab.active {
    background: var(--monokai-tab-active-background);
    color: var(--monokai-foreground);
  }

  .tab-title {
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .tab-close {
    background: none;
    border: none;
    color: inherit;
    cursor: pointer;
    padding: 1px;
    border-radius: 3px;
    display: flex;
    opacity: 0.6;
  }

  .tab-close:hover {
    opacity: 1;
    background: rgba(255, 255, 255, 0.1);
  }
</style>
