import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.n, modifiers: [.command, .shift]))
    static let newNote = Self("newNote", default: .init(.n, modifiers: [.command, .option]))
    static let searchNotes = Self("searchNotes", default: .init(.f, modifiers: [.command, .shift]))
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let vaultManager = VaultManager()
    let panelController = FloatingPanelController()
    let searchManager = SearchManager()
    lazy var imageManager = ImageManager(vaultManager: vaultManager)

    private var panel: FloatingPanel?

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
            imageManager: imageManager
        )
        .environment(\.colorScheme, .dark)

        let panel = FloatingPanel(contentView: contentView)
        panelController.setPanel(panel)
        self.panel = panel

        // Show panel on first launch
        panelController.showPanel()
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.panelController.togglePanel()
        }

        KeyboardShortcuts.onKeyUp(for: .newNote) { [weak self] in
            self?.panelController.createNewNote()
        }

        KeyboardShortcuts.onKeyUp(for: .searchNotes) { [weak self] in
            self?.panelController.showSearch()
        }
    }
}
