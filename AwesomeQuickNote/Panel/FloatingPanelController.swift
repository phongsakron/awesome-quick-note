import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    var isVisible: Bool = false
    var isSearchActive: Bool = false
    var isSettingsActive: Bool = false
    var pendingNewNote: Bool = false

    private var panel: FloatingPanel?

    private static let frameKey = "panelFrame"

    func setPanel(_ panel: FloatingPanel) {
        self.panel = panel
        panel.delegate = self
        restoreFrame()
    }

    func togglePanel() {
        guard let panel else { return }

        if panel.isVisible {
            panel.orderOut(nil)
            isVisible = false
        } else {
            panel.orderFront(nil)
            panel.makeKeyAndOrderFront(nil)
            isVisible = true
        }
    }

    func showPanel() {
        guard let panel else { return }
        panel.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    func hidePanel() {
        guard let panel else { return }
        panel.orderOut(nil)
        isVisible = false
    }

    func createNewNote() {
        pendingNewNote = true
        showPanel()
    }

    func showSearch() {
        isSettingsActive = false
        isSearchActive = true
        showPanel()
    }

    func showSettings() {
        isSearchActive = false
        isSettingsActive = true
        showPanel()
    }

    func dismissOverlays() {
        isSearchActive = false
        isSettingsActive = false
    }

    func moveToPosition(_ position: PanelPosition) {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let frame = position.frame(for: panel.frame.size, on: screen)
        panel.setFrame(frame, display: true, animate: true)
    }

    // MARK: - Frame Persistence

    private func saveFrame() {
        guard let panel else { return }
        let frameString = NSStringFromRect(panel.frame)
        UserDefaults.standard.set(frameString, forKey: Self.frameKey)
    }

    private func restoreFrame() {
        guard let panel,
              let frameString = UserDefaults.standard.string(forKey: Self.frameKey) else {
            centerPanel()
            return
        }

        let frame = NSRectFromString(frameString)
        if frame.width > 0, frame.height > 0 {
            panel.setFrame(frame, display: true)
        } else {
            centerPanel()
        }
    }

    private func centerPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = PanelPosition.center.frame(for: panel.frame.size, on: screen)
        panel.setFrame(frame, display: true)
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            saveFrame()
        }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            saveFrame()
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            isVisible = false
        }
    }
}
