<script lang="ts">
  import { gitSyncStatus } from "../stores/git-sync";
  import { modifierKey } from "../utils/platform";
  import GitSyncStatusView from "./GitSyncStatusView.svelte";

  interface Props {
    onNewNote: () => void;
    onSearch: () => void;
    onSettings: () => void;
    onTogglePin: () => void;
    isPinned: boolean;
    hasNote: boolean;
  }

  let { onNewNote, onSearch, onSettings, onTogglePin, isPinned, hasNote }: Props = $props();
  const mod = modifierKey();
</script>

<div class="toolbar">
  <div class="toolbar-left">
    <button class="toolbar-btn" onclick={onNewNote} title="{mod}+Alt+N">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
        <path d="M8 2a.5.5 0 0 1 .5.5v5h5a.5.5 0 0 1 0 1h-5v5a.5.5 0 0 1-1 0v-5h-5a.5.5 0 0 1 0-1h5v-5A.5.5 0 0 1 8 2z"/>
      </svg>
    </button>
    <button class="toolbar-btn" onclick={onSearch} title="{mod}+Shift+F">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
        <path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85zm-5.242.156a5 5 0 1 1 0-10 5 5 0 0 1 0 10z"/>
      </svg>
    </button>
  </div>
  <div class="toolbar-right">
    {#if hasNote}
      <button
        class="toolbar-btn"
        class:pinned={isPinned}
        onclick={onTogglePin}
        title="{mod}+Alt+P"
      >
        {#if isPinned}
          <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
            <path d="M4.146.146A.5.5 0 0 1 4.5 0h7a.5.5 0 0 1 .5.5c0 .68-.342 1.174-.646 1.479-.126.125-.25.224-.354.298v4.431l.078.048c.203.127.476.314.751.555C12.36 7.775 13 8.527 13 9.5a.5.5 0 0 1-.5.5h-4v4.5a.5.5 0 0 1-1 0V10h-4a.5.5 0 0 1-.5-.5c0-.973.64-1.725 1.17-2.189A5.921 5.921 0 0 1 5 6.708V2.277a2.77 2.77 0 0 1-.354-.298C4.342 1.674 4 1.179 4 .5a.5.5 0 0 1 .146-.354z"/>
          </svg>
        {:else}
          <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
            <path d="M4.146.146A.5.5 0 0 1 4.5 0h7a.5.5 0 0 1 .5.5c0 .68-.342 1.174-.646 1.479-.126.125-.25.224-.354.298v4.431l.078.048c.203.127.476.314.751.555C12.36 7.775 13 8.527 13 9.5a.5.5 0 0 1-.5.5h-4v4.5a.5.5 0 0 1-1 0V10h-4a.5.5 0 0 1-.5-.5c0-.973.64-1.725 1.17-2.189A5.921 5.921 0 0 1 5 6.708V2.277a2.77 2.77 0 0 1-.354-.298C4.342 1.674 4 1.179 4 .5a.5.5 0 0 1 .146-.354zm1.58 1.408l-.002-.001.002.001zm-.002-.001A1.13 1.13 0 0 1 5.287 1h5.426a1.13 1.13 0 0 1-.437.553L10 1.735V6.85a.5.5 0 0 1-.223.416l-.166.104a4.944 4.944 0 0 0-.625.463A3.158 3.158 0 0 0 8.2 8.8h-.4a3.158 3.158 0 0 0-.786-.967 4.944 4.944 0 0 0-.625-.463l-.166-.104A.5.5 0 0 1 6 6.85V1.735l-.276-.182z"/>
          </svg>
        {/if}
      </button>
    {/if}
    <GitSyncStatusView />
    <button class="toolbar-btn" onclick={onSettings} title="{mod}+,">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
        <path d="M8 4.754a3.246 3.246 0 1 0 0 6.492 3.246 3.246 0 0 0 0-6.492zM5.754 8a2.246 2.246 0 1 1 4.492 0 2.246 2.246 0 0 1-4.492 0z"/>
        <path d="M9.796 1.343c-.527-1.79-3.065-1.79-3.592 0l-.094.319a.873.873 0 0 1-1.255.52l-.292-.16c-1.64-.892-3.433.902-2.54 2.541l.159.292a.873.873 0 0 1-.52 1.255l-.319.094c-1.79.527-1.79 3.065 0 3.592l.319.094a.873.873 0 0 1 .52 1.255l-.16.292c-.892 1.64.901 3.434 2.541 2.54l.292-.159a.873.873 0 0 1 1.255.52l.094.319c.527 1.79 3.065 1.79 3.592 0l.094-.319a.873.873 0 0 1 1.255-.52l.292.16c1.64.893 3.434-.902 2.54-2.541l-.159-.292a.873.873 0 0 1 .52-1.255l.319-.094c1.79-.527 1.79-3.065 0-3.592l-.319-.094a.873.873 0 0 1-.52-1.255l.16-.292c.893-1.64-.902-3.433-2.541-2.54l-.292.159a.873.873 0 0 1-1.255-.52l-.094-.319zm-2.633.283c.246-.835 1.428-.835 1.674 0l.094.319a1.873 1.873 0 0 0 2.693 1.115l.291-.16c.764-.415 1.6.42 1.184 1.185l-.159.292a1.873 1.873 0 0 0 1.116 2.692l.318.094c.835.246.835 1.428 0 1.674l-.319.094a1.873 1.873 0 0 0-1.115 2.693l.16.291c.415.764-.42 1.6-1.185 1.184l-.291-.159a1.873 1.873 0 0 0-2.693 1.116l-.094.318c-.246.835-1.428.835-1.674 0l-.094-.319a1.873 1.873 0 0 0-2.692-1.115l-.292.16c-.764.415-1.6-.42-1.184-1.185l.159-.291A1.873 1.873 0 0 0 1.945 8.93l-.319-.094c-.835-.246-.835-1.428 0-1.674l.319-.094A1.873 1.873 0 0 0 3.06 4.377l-.16-.292c-.415-.764.42-1.6 1.185-1.184l.292.159a1.873 1.873 0 0 0 2.692-1.115l.094-.319z"/>
      </svg>
    </button>
  </div>
</div>

<style>
  .toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 10px;
    background: var(--monokai-toolbar-background);
    -webkit-app-region: drag;
    min-height: 36px;
  }

  .toolbar-left, .toolbar-right {
    display: flex;
    align-items: center;
    gap: 4px;
    -webkit-app-region: no-drag;
  }

  .toolbar-btn {
    background: none;
    border: none;
    color: var(--monokai-comment);
    cursor: pointer;
    padding: 4px 6px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    transition: color 0.15s, background 0.15s;
  }

  .toolbar-btn:hover {
    color: var(--monokai-foreground);
    background: var(--monokai-tab-background);
  }

  .toolbar-btn.pinned {
    color: var(--monokai-number);
  }
</style>
