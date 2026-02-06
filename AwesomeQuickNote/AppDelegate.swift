import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.n, modifiers: [.command, .shift]))
    static let newNote = Self("newNote", default: .init(.n, modifiers: [.command, .option]))
    static let searchNotes = Self("searchNotes", default: .init(.f, modifiers: [.command, .shift]))
    static let resetPosition = Self("resetPosition", default: .init(.r, modifiers: [.command, .shift]))
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let vaultManager = VaultManager()
    let panelController = FloatingPanelController()
    let searchManager = SearchManager()
    let fontSettings = FontSettings()
    lazy var imageManager = ImageManager(vaultManager: vaultManager)

    private var panel: FloatingPanel?
    private var localEventMonitor: Any?
    private var shortcutChangeObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (LSUIElement equivalent)
        NSApp.setActivationPolicy(.accessory)

        setupPanel()
        setupKeyboardShortcuts()
    }

    private func setupPanel() {
        let contentView = FloatingPanelView(
            vaultManager: vaultManager,
            panelController: panelController,
            searchManager: searchManager,
            imageManager: imageManager,
            fontSettings: fontSettings
        )
        .environment(\.colorScheme, .dark)

        let panel = FloatingPanel(contentView: contentView)
        panelController.setPanel(panel)
        self.panel = panel

        // Show panel on first launch
        panelController.showPanel()
    }

    private func setupKeyboardShortcuts() {
        // Only togglePanel is global
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.panelController.togglePanel()
        }

        // Disable the other shortcuts from being global Carbon hotkeys
        disableLocalShortcuts()

        // Handle newNote, searchNotes, resetPosition locally (only when panel is focused)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalShortcut(event) ? nil : event
        }

        // Re-disable after user changes shortcuts via Recorder
        shortcutChangeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.disableLocalShortcuts()
            }
        }
    }

    private func disableLocalShortcuts() {
        KeyboardShortcuts.disable(.newNote)
        KeyboardShortcuts.disable(.searchNotes)
        KeyboardShortcuts.disable(.resetPosition)
    }

    private func handleLocalShortcut(_ event: NSEvent) -> Bool {
        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else { return false }

        if shortcut == KeyboardShortcuts.getShortcut(for: .newNote) {
            panelController.createNewNote()
            return true
        }
        if shortcut == KeyboardShortcuts.getShortcut(for: .searchNotes) {
            panelController.showSearch()
            return true
        }
        if shortcut == KeyboardShortcuts.getShortcut(for: .resetPosition) {
            panelController.resetPosition()
            return true
        }

        return false
    }

    deinit {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        if let shortcutChangeObserver {
            NotificationCenter.default.removeObserver(shortcutChangeObserver)
        }
    }
}
