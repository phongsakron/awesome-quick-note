# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
swift build
swift build -c release
```

macOS 14.0+ required. No test targets exist yet.

## Release

Releases are automated via GitHub Actions. Push a tag to trigger:

```bash
git tag v1.x.x && git push origin v1.x.x
```

The workflow builds a release binary, assembles a `.app` bundle, ad-hoc code signs it, packages it as a `.dmg`, and creates a GitHub Release. See `.github/workflows/release.yml`.

## Architecture

**AwesomeQuickNote** is a macOS menu bar app (no Dock icon) for quick markdown note-taking via a floating panel. Built with SwiftUI.

### Core Layers

- **AppDelegate** — Initializes all managers, creates the `FloatingPanel`, registers global keyboard shortcuts (Cmd+Shift+N toggle, Cmd+Option+N new note, Cmd+Shift+F search, Cmd+Option+P pin, Cmd+Shift+R reset position)
- **FloatingPanelController** (`@Observable`) — Manages panel visibility, overlay state (`isSearchActive`, `isSettingsActive`, `pendingNewNote`), panel positioning, and panel opacity
- **FloatingPanel** — Custom `NSPanel` subclass (`.nonactivatingPanel`, floating level, joins all spaces, `isOpaque = false` for opacity support)
- **VaultManager** (`@Observable`) — File-based CRUD for `.md` notes in a user-selected vault folder, file watching via `DispatchSource`, security-scoped bookmarks for persistent access
- **SearchManager** (`@Observable`) — Fuzzy search via Fuse library (threshold 0.4), searches title + content, secondary sort by `modifiedAt`
- **ImageManager** — Paste/drag image handling, saves PNGs to `attachments/` subfolder, returns markdown image syntax
- **PinManager** — Persists pinned note IDs in UserDefaults, pinned notes sort to top
- **FontSettings** (`@Observable`) — Persists editor font family and size in UserDefaults

### View Hierarchy

`FloatingPanelView` is the main container. It switches between:
- **NoteEditorView** — `NSViewRepresentable` wrapping a custom `NSTextView` subclass with image paste/drop support, syntax highlighting, checkbox toggling, and auto list continuation
- **NotePreviewView** — MarkdownUI rendering with custom Monokai theme and local image resolution
- **SearchView** — Fuzzy search with keyboard navigation (arrows + enter/escape on the TextField), pin indicators
- **SettingsView** — Keyboard shortcuts, panel position grid, opacity slider, font settings, vault management
- **VaultSetupView**

### Data Flow

Notes are plain `.md` files. `VaultManager` scans the vault directory, creates `Note` structs (with `id`, `fileURL`, `content`, `createdAt`, `modifiedAt`). `FloatingPanelView` holds `@State` for `selectedNote` and `editingContent`, with debounced auto-save (500ms). External file changes are detected by the file watcher and trigger `loadNotes()`.

### State Management

All managers use modern `@Observable` macro with `@MainActor` isolation (not legacy `ObservableObject`). Managers are passed explicitly to views (no environment objects).

Focus is controlled via `editorFocusTrigger: Bool` state — set `true` to focus editor, `false` before showing overlays.

### Dependencies (Package.swift)

- **KeyboardShortcuts** (v2.0.0+) — Global hotkey registration
- **MarkdownUI** (v2.4.0+) — Markdown preview rendering
- **Fuse** (v1.4.0+) — Fuzzy string matching
- **swift-markdown** (v0.4.0+) — AST-based markdown parsing for syntax highlighting
- **Highlightr** (v2.2.1+) — Code block syntax highlighting

### Theme

All colors defined in `MonokaiTheme.swift` as static properties on `Monokai`. Markdown preview theme in `MarkdownThemeConfig.swift`.

## Conventions

- Note switching is done exclusively through search (no tab bar)
- `Note.title` is derived from the first `# Heading` line or the filename
- Images are stored in `attachments/` inside the vault and referenced with relative markdown paths
- The app runs as `LSUIElement` (menu bar only, `Info.plist`)
- Panel opacity and position are persisted in UserDefaults
- Pinned note IDs are persisted in UserDefaults
