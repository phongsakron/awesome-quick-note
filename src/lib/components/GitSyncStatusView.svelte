<script lang="ts">
  import { gitSyncStatus, lastSyncDate } from "../stores/git-sync";
  import { manualSync } from "../commands/git-sync";

  let statusClass = $derived.by(() => {
    const s = $gitSyncStatus;
    if (s === "disabled") return "hidden";
    if (s === "syncing") return "syncing";
    if (s === "idle") return "idle";
    if (s === "no_remote") return "no-remote";
    if (s === "not_a_repo") return "hidden";
    if (typeof s === "object" && "error" in s) return "error";
    return "hidden";
  });

  let statusTitle = $derived.by(() => {
    const s = $gitSyncStatus;
    if (s === "disabled") return "";
    if (s === "syncing") return "Syncing...";
    if (s === "idle") return "Git synced" + ($lastSyncDate ? ` (${new Date($lastSyncDate).toLocaleTimeString()})` : "");
    if (s === "no_remote") return "No remote configured";
    if (s === "not_a_repo") return "";
    if (typeof s === "object" && "error" in s) return `Error: ${s.error}`;
    return "";
  });

  function handleClick() {
    manualSync();
  }
</script>

{#if statusClass !== "hidden"}
  <button
    class="git-status {statusClass}"
    title={statusTitle}
    onclick={handleClick}
  >
    <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" class:spinning={statusClass === "syncing"}>
      <path d="M8 3a5 5 0 1 0 4.546 2.914.5.5 0 0 1 .908-.417A6 6 0 1 1 8 2v1z"/>
      <path d="M8 4.466V.534a.25.25 0 0 1 .41-.192l2.36 1.966c.12.1.12.284 0 .384L8.41 4.658A.25.25 0 0 1 8 4.466z"/>
    </svg>
  </button>
{/if}

<style>
  .git-status {
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px 6px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    transition: color 0.15s;
  }

  .git-status.idle { color: var(--monokai-function); }
  .git-status.syncing { color: var(--monokai-type); }
  .git-status.no-remote { color: var(--monokai-comment); }
  .git-status.error { color: var(--monokai-keyword); }

  .git-status:hover { opacity: 0.8; }

  .spinning {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
