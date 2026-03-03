<script lang="ts">
  import { selectVault, setVault, getNotes } from "../commands/vault";
  import { vaultPath, notes, selectedNote, editingContent } from "../stores/vault";
  import { activeView, editorFocusTrigger } from "../stores/ui";
  import { updateSettings } from "../commands/settings";

  async function handleSelectVault() {
    const path = await selectVault();
    if (path) {
      // Initialize the Rust VaultManager with the selected path
      await setVault(path);
      vaultPath.set(path);
      await updateSettings({ vault_path: path });

      // Load notes from the newly set vault
      const loaded = await getNotes();
      notes.set(loaded);
      if (loaded.length > 0) {
        selectedNote.set(loaded[0]);
        editingContent.set(loaded[0].content);
        editorFocusTrigger.set(true);
      }

      activeView.set("editor");
    }
  }
</script>

<div class="vault-setup">
  <div class="vault-setup-content">
    <svg width="48" height="48" viewBox="0 0 16 16" fill="currentColor" class="icon">
      <path d="M.54 3.87.5 3a2 2 0 0 1 2-2h3.672a2 2 0 0 1 1.414.586l.828.828A2 2 0 0 0 9.828 3h3.982a2 2 0 0 1 1.992 2.181l-.637 7A2 2 0 0 1 13.174 14H2.826a2 2 0 0 1-1.991-1.819l-.637-7a1.99 1.99 0 0 1 .342-1.31zM2.19 4a1 1 0 0 0-.996 1.09l.637 7a1 1 0 0 0 .995.91h10.348a1 1 0 0 0 .995-.91l.637-7A1 1 0 0 0 13.81 4H2.19zm4.69-1.707A1 1 0 0 0 6.172 2H2.5a1 1 0 0 0-1 .981l.006.139C1.72 3.042 1.95 3 2.19 3h5.396l-.707-.707z"/>
    </svg>
    <h2>Welcome to SideNote</h2>
    <p>Select a folder to store your markdown notes.</p>
    <button class="select-btn" onclick={handleSelectVault}>
      Select Vault Folder
    </button>
  </div>
</div>

<style>
  .vault-setup {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    padding: 24px;
  }

  .vault-setup-content {
    text-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }

  .icon {
    color: var(--monokai-comment);
    margin-bottom: 8px;
  }

  h2 {
    color: var(--monokai-foreground);
    font-size: 18px;
    font-weight: 600;
  }

  p {
    color: var(--monokai-comment);
    font-size: 13px;
  }

  .select-btn {
    background: var(--monokai-keyword);
    color: var(--monokai-foreground);
    border: none;
    padding: 8px 20px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    transition: opacity 0.15s;
  }

  .select-btn:hover {
    opacity: 0.85;
  }
</style>
