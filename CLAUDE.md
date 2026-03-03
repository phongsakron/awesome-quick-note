# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
bun install
bun run tauri dev        # Development with hot reload
bun run tauri build      # Production build
```

Cross-platform: macOS 10.15+, Linux (Wayland/X11). No test targets exist yet.

## Release

Releases are automated via GitHub Actions. Push a tag to trigger:

```bash
git tag v1.x.x && git push origin v1.x.x
```

The workflow builds platform-specific bundles (`.dmg` for macOS, `.AppImage`/`.deb` for Linux) and creates a GitHub Release. See `.github/workflows/release.yml`.

## Architecture

**SideNote** is a cross-platform menu bar / system tray app for quick markdown note-taking via a floating panel. Built with Tauri v2 (Rust backend) + Svelte 5 (TypeScript frontend).

### Backend (Rust — `src-tauri/`)

#### State Managers (`src-tauri/src/state/`)

- **VaultManager** — File-based CRUD for `.md` notes, ID tracking, attachments directory
- **SettingsManager** — JSON config persistence in `app_config_dir()`, partial updates
- **SearchManager** — Fuzzy search via `nucleo` crate (Helix editor's engine)
- **GitSyncManager** — Git operations via `std::process::Command`, 5s debounced sync, 5min periodic pull, status events
- **PinManager** — Pinned note IDs persisted to JSON file
- **ImageManager** — Saves pasted/dropped images to `attachments/` subfolder

#### Tauri Commands (`src-tauri/src/commands/`)

Commands are the Tauri IPC boundary. Each module wraps its state manager:
- `vault.rs` — `select_vault`, `set_vault`, `get_notes`, `create_note`, `save_note`, `delete_note`
- `search.rs` — `search_notes`
- `git_sync.rs` — `get_git_sync_status`, `manual_sync`, `set_git_sync_enabled`
- `settings.rs` — `get_settings`, `update_settings`, `get_platform_info`
- `image.rs` — `save_image`
- `pin.rs` — `toggle_pin`, `get_pinned_notes`

#### Models (`src-tauri/src/models/`)

- `Note` — id, file_name, file_path, content, title (derived from first `# Heading`), timestamps
- `AppSettings` — vault_path, font, opacity, position, shortcuts, git_sync_enabled
- `GitSyncStatus` — Disabled, NotARepo, Idle, Syncing, NoRemote, Error(String)

#### App Setup (`src-tauri/src/lib.rs`)

- System tray with Show/Hide + Quit menu
- macOS `ActivationPolicy::Accessory` (no Dock icon)
- File watcher via `notify` crate → emits `vault:notes-changed` events
- Git sync background tasks (debounced sync + periodic pull)

### Frontend (Svelte 5 — `src/`)

#### Component Hierarchy

`App.svelte` → `FloatingPanelView.svelte` → switches between:
- **MarkdownEditor** (`src/lib/editor/`) — Custom contenteditable with live syntax highlighting
- **SearchView** — Fuzzy search with keyboard navigation (↑/↓/Enter/Escape)
- **SettingsView** — Font, opacity, vault, git sync configuration
- **VaultSetupView** — Initial vault folder selection

#### Editor (`src/lib/editor/`)

- `MarkdownEditor.svelte` — Main editor component, cursor preservation across re-highlights
- `highlighter.ts` — Line-by-line markdown → HTML with Monokai CSS classes
- `list-continuation.ts` — Smart Enter for bullets/numbers/checkboxes
- `checkbox-toggle.ts` — Click `[ ]`↔`[x]` toggle
- `image-paste.ts` — Clipboard/drop image → Rust save → insert markdown
- `find-replace.ts` — Cmd+F find, Cmd+H replace
- `link-handler.ts` — Cmd+Click opens URLs externally
- `code-blocks.ts` — Copy button overlay on code blocks
- `image-overlay.ts` — Inline image preview

#### Stores (`src/lib/stores/`)

Svelte writable stores for reactive state:
- `vault.ts` — notes, selectedNote, editingContent, vaultPath
- `settings.ts` — AppSettings with defaults
- `ui.ts` — activeView overlay state, editorFocusTrigger
- `search.ts`, `pin.ts`, `git-sync.ts`, `editor.ts`

#### Command Wrappers (`src/lib/commands/`)

Typed `invoke()` wrappers matching each Rust command module.

### Theme

Monokai color palette defined as CSS custom properties in `src/lib/theme/monokai.css`:
- Background: `#272822`, Foreground: `#F8F8F2`
- Keyword: `#F92672`, String: `#E6DB74`, Function: `#A6E22E`
- Type: `#66D9EF`, Number: `#AE81FF`, Comment: `#75715E`

### Dependencies

**Rust** (`src-tauri/Cargo.toml`): tauri v2, tauri-plugin-dialog/shell/global-shortcut/fs, serde, tokio, notify v7, nucleo v0.5, uuid, chrono, trash, dirs, image

**Frontend** (`package.json`): @tauri-apps/api v2 + plugins, svelte v5, vite v6, markdown-it v14, highlight.js v11

## Conventions

- Note switching is done exclusively through search (no tab bar)
- `Note.title` is derived from the first `# Heading` line or the filename
- Images are stored in `attachments/` inside the vault and referenced with relative markdown paths
- The app runs as a system tray app (no Dock/taskbar icon)
- Settings are persisted to JSON in the app config directory
- Pinned note IDs are persisted to a separate JSON file
- Git sync uses `git` CLI via `std::process::Command`
- Debounced auto-save: 500ms for note content, 5s for git sync

## Cross-Platform

| Concern | macOS | Linux (Wayland) |
|---------|-------|-----------------|
| Tray | Native NSStatusItem | StatusNotifierItem |
| Hide from Dock | `ActivationPolicy::Accessory` | `skipTaskbar: true` |
| Global shortcuts | Carbon hotkeys | xdg-desktop-portal |
| Window positioning | Position grid | Let compositor handle |
| File watching | FSEvents | inotify |
| Trash | Finder trash | freedesktop spec |
| Modifier keys | Cmd (⌘) | Ctrl |

Wayland detection: Rust `get_platform_info` command checks `WAYLAND_DISPLAY` env var.
