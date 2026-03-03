<script lang="ts">
  import { settings, type ShortcutSettings } from "../stores/settings";
  import { gitSyncStatus, lastCommitDate } from "../stores/git-sync";
  import { relativeDate } from "../utils/relative-date";
  import { vaultPath } from "../stores/vault";
  import { updateSettings } from "../commands/settings";
  import { selectVault, setVault } from "../commands/vault";
  import { setGitSyncEnabled } from "../commands/git-sync";
  import { revealInFileManager, setWindowPosition, getScreenBounds } from "../commands/window";
  import { registerShortcuts } from "../commands/shortcuts";

  interface Props {
    onDismiss: () => void;
  }

  let { onDismiss }: Props = $props();

  let recordingKey: keyof ShortcutSettings | null = $state(null);

  const shortcutLabels: Record<keyof ShortcutSettings, string> = {
    toggle_panel: "Toggle Panel",
    new_note: "New Note",
    search_notes: "Search Notes",
    toggle_pin: "Toggle Pin",
    reset_position: "Reset Position",
  };

  function formatShortcut(raw: string): string {
    const isMac = navigator.platform?.includes("Mac");
    return raw
      .replace(/CmdOrCtrl/g, isMac ? "\u2318" : "Ctrl")
      .replace(/\bCmd\b/g, isMac ? "\u2318" : "Cmd")
      .replace(/\bCtrl\b/g, isMac ? "\u2303" : "Ctrl")
      .replace(/Shift/g, isMac ? "\u21E7" : "Shift")
      .replace(/Alt/g, isMac ? "\u2325" : "Alt")
      .replace(/\+/g, " ");
  }

  async function handleShortcutKeydown(key: keyof ShortcutSettings, e: KeyboardEvent) {
    if (e.key === "Escape") {
      e.preventDefault();
      recordingKey = null;
      return;
    }

    // Ignore lone modifier presses
    if (["Meta", "Control", "Shift", "Alt"].includes(e.key)) return;

    e.preventDefault();

    const isMac = navigator.platform?.includes("Mac");
    const parts: string[] = [];

    if (isMac && e.metaKey && e.ctrlKey) {
      // Both Cmd and Ctrl pressed — use explicit names
      parts.push("Cmd");
      parts.push("Ctrl");
    } else if (e.metaKey || e.ctrlKey) {
      parts.push("CmdOrCtrl");
    }
    if (e.shiftKey) parts.push("Shift");
    if (e.altKey) parts.push("Alt");

    // Need at least one modifier
    if (parts.length === 0) return;

    parts.push(e.key.length === 1 ? e.key.toUpperCase() : e.key);
    const combo = parts.join("+");

    settings.update((s) => ({
      ...s,
      shortcuts: { ...s.shortcuts, [key]: combo },
    }));
    await updateSettings({ shortcuts: { ...$settings.shortcuts, [key]: combo } });
    await registerShortcuts();
    recordingKey = null;
  }

  function autoFocus(node: HTMLElement) {
    node.focus();
  }

  const fontFamilies = [
    "SF Mono",
    "JetBrains Mono",
    "Fira Code",
    "Source Code Pro",
    "Cascadia Code",
    "Menlo",
    "Monaco",
    "Consolas",
    "monospace",
  ];

  async function handleFontChange(e: Event) {
    const family = (e.target as HTMLSelectElement).value;
    settings.update((s) => ({ ...s, font_family: family }));
    await updateSettings({ font_family: family });
  }

  async function handleFontSizeChange(e: Event) {
    const size = parseInt((e.target as HTMLInputElement).value);
    if (size >= 8 && size <= 32) {
      settings.update((s) => ({ ...s, font_size: size }));
      await updateSettings({ font_size: size });
    }
  }

  async function handleOpacityChange(e: Event) {
    const opacity = parseFloat((e.target as HTMLInputElement).value);
    settings.update((s) => ({ ...s, panel_opacity: opacity }));
    await updateSettings({ panel_opacity: opacity });
  }

  async function handleGitSyncToggle(e: Event) {
    const enabled = (e.target as HTMLInputElement).checked;
    settings.update((s) => ({ ...s, git_sync_enabled: enabled }));
    await setGitSyncEnabled(enabled);
  }

  async function handleChangeVault() {
    const path = await selectVault();
    if (path) {
      await setVault(path);
      vaultPath.set(path);
      await updateSettings({ vault_path: path });
    }
  }

  const positionNames = [
    "top-left", "top-center", "top-right",
    "center-left", "center", "center-right",
    "bottom-left", "bottom-center", "bottom-right",
  ] as const;

  const positionLabels: Record<string, string> = {
    "top-left": "TL", "top-center": "TC", "top-right": "TR",
    "center-left": "CL", "center": "C", "center-right": "CR",
    "bottom-left": "BL", "bottom-center": "BC", "bottom-right": "BR",
  };

  async function handlePositionClick(position: string) {
    try {
      const bounds = await getScreenBounds();
      const panelW = $settings.panel_width || 480;
      const panelH = $settings.panel_height || 600;
      const margin = 20;

      let x = 0;
      let y = 0;

      if (position.includes("left")) x = bounds.x + margin;
      else if (position.includes("right")) x = bounds.x + bounds.width - panelW - margin;
      else x = bounds.x + Math.round((bounds.width - panelW) / 2);

      if (position.startsWith("top")) y = bounds.y + margin;
      else if (position.startsWith("bottom")) y = bounds.y + bounds.height - panelH - margin;
      else y = bounds.y + Math.round((bounds.height - panelH) / 2);

      await setWindowPosition(x, y);
      settings.update((s) => ({ ...s, panel_position: position }));
      await updateSettings({ panel_position: position, panel_x: x, panel_y: y });
    } catch {}
  }
</script>

<div class="settings-view">
  <div class="settings-header">
    <h3>Settings</h3>
    <button class="close-btn" onclick={onDismiss}>
      <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor">
        <path d="M4.646 4.646a.5.5 0 0 1 .708 0L8 7.293l2.646-2.647a.5.5 0 0 1 .708.708L8.707 8l2.647 2.646a.5.5 0 0 1-.708.708L8 8.707l-2.646 2.647a.5.5 0 0 1-.708-.708L7.293 8 4.646 5.354a.5.5 0 0 1 0-.708z"/>
      </svg>
    </button>
  </div>

  <div class="settings-content">
    <section class="settings-section">
      <h4>Editor</h4>
      <div class="setting-row">
        <label>Font Family</label>
        <select value={$settings.font_family} onchange={handleFontChange}>
          {#each fontFamilies as font}
            <option value={font}>{font}</option>
          {/each}
        </select>
      </div>
      <div class="setting-row">
        <label>Font Size</label>
        <input
          type="number"
          min="8"
          max="32"
          value={$settings.font_size}
          onchange={handleFontSizeChange}
        />
      </div>
    </section>

    <section class="settings-section">
      <h4>Appearance</h4>
      <div class="setting-row">
        <label>Panel Position</label>
        <div class="position-grid">
          {#each positionNames as pos}
            <button
              class="position-cell"
              class:active={$settings.panel_position === pos}
              onclick={() => handlePositionClick(pos)}
              title={pos}
            >
              {positionLabels[pos]}
            </button>
          {/each}
        </div>
      </div>
      <div class="setting-row">
        <label>Panel Opacity</label>
        <div class="slider-row">
          <input
            type="range"
            min="0.3"
            max="1"
            step="0.05"
            value={$settings.panel_opacity}
            oninput={handleOpacityChange}
          />
          <span class="opacity-value">{Math.round($settings.panel_opacity * 100)}%</span>
        </div>
      </div>
    </section>

    <section class="settings-section">
      <h4>Keyboard Shortcuts</h4>
      {#each Object.entries(shortcutLabels) as [key, label]}
        <div class="setting-row">
          <label>{label}</label>
          {#if recordingKey === key}
            <button
              class="shortcut-btn recording"
              use:autoFocus
              onkeydown={(e) => handleShortcutKeydown(key as keyof ShortcutSettings, e)}
              onblur={() => (recordingKey = null)}
            >
              Press keys...
            </button>
          {:else}
            <button
              class="shortcut-btn"
              onclick={() => (recordingKey = key as keyof ShortcutSettings)}
              title="Click to change"
            >
              {formatShortcut($settings.shortcuts[key as keyof ShortcutSettings])}
            </button>
          {/if}
        </div>
      {/each}
      <p class="setting-description">Click a shortcut to rebind. Press Escape to cancel.</p>
    </section>

    <section class="settings-section">
      <h4>Vault</h4>
      <div class="setting-row">
        <label>Current Vault</label>
        <div class="vault-path">
          <span class="path-text">{$vaultPath ?? "Not set"}</span>
          {#if $vaultPath}
            <button class="small-btn" onclick={() => revealInFileManager($vaultPath!)}>Reveal</button>
          {/if}
          <button class="small-btn" onclick={handleChangeVault}>Change</button>
        </div>
      </div>
    </section>

    <section class="settings-section">
      <h4>Git Sync</h4>
      <div class="setting-row">
        <label>Enable Git Sync</label>
        <input
          type="checkbox"
          checked={$settings.git_sync_enabled}
          onchange={handleGitSyncToggle}
        />
      </div>
      {#if $lastCommitDate}
        <div class="setting-row">
          <label>Last Commit</label>
          <span class="last-commit-value">{relativeDate($lastCommitDate)}</span>
        </div>
      {/if}
      <p class="setting-description">
        Automatically commit and push changes to a git remote.
        Your vault must be a git repository with a configured remote.
      </p>
    </section>

    <section class="settings-section about">
      <h4>About</h4>
      <p>SideNote v0.1.0</p>
      <p class="setting-description">A quick markdown note-taking app.</p>
    </section>
  </div>
</div>

<style>
  .settings-view {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .settings-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    border-bottom: 1px solid var(--monokai-border);
  }

  .settings-header h3 {
    font-size: 14px;
    font-weight: 600;
  }

  .close-btn {
    background: none;
    border: none;
    color: var(--monokai-comment);
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    display: flex;
  }

  .close-btn:hover {
    color: var(--monokai-foreground);
  }

  .settings-content {
    flex: 1;
    overflow-y: auto;
    padding: 12px 16px;
  }

  .settings-section {
    margin-bottom: 20px;
  }

  .settings-section h4 {
    font-size: 12px;
    font-weight: 600;
    color: var(--monokai-comment);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 8px;
  }

  .setting-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 0;
  }

  .setting-row label {
    font-size: 13px;
    color: var(--monokai-foreground);
  }

  .setting-row select,
  .setting-row input[type="number"] {
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-foreground);
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 12px;
  }

  .setting-row input[type="number"] {
    width: 60px;
    text-align: center;
  }

  .setting-row input[type="checkbox"] {
    accent-color: var(--monokai-function);
  }

  .slider-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .slider-row input[type="range"] {
    width: 120px;
    accent-color: var(--monokai-function);
  }

  .opacity-value {
    font-size: 12px;
    color: var(--monokai-comment);
    min-width: 36px;
  }

  .vault-path {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .path-text {
    font-size: 11px;
    color: var(--monokai-comment);
    max-width: 180px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .small-btn {
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-foreground);
    padding: 2px 8px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 11px;
  }

  .small-btn:hover {
    background: var(--monokai-tab-active-background);
  }

  .setting-description {
    font-size: 11px;
    color: var(--monokai-comment);
    margin-top: 4px;
    line-height: 1.4;
  }

  .last-commit-value {
    font-size: 12px;
    color: var(--monokai-comment);
  }

  .shortcut-btn {
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-foreground);
    padding: 3px 10px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    font-family: inherit;
    min-width: 80px;
    text-align: center;
    letter-spacing: 1px;
  }

  .shortcut-btn:hover {
    border-color: var(--monokai-type);
  }

  .shortcut-btn.recording {
    border-color: var(--monokai-keyword);
    color: var(--monokai-keyword);
    animation: pulse 1s infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.6; }
  }

  .position-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 3px;
    width: 78px;
  }

  .position-cell {
    width: 24px;
    height: 20px;
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-comment);
    border-radius: 3px;
    cursor: pointer;
    font-size: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    transition: background 0.1s, border-color 0.1s;
  }

  .position-cell:hover {
    border-color: var(--monokai-type);
    color: var(--monokai-foreground);
  }

  .position-cell.active {
    background: var(--monokai-function);
    border-color: var(--monokai-function);
    color: var(--monokai-background);
    font-weight: 600;
  }

  .about p {
    font-size: 13px;
  }
</style>
