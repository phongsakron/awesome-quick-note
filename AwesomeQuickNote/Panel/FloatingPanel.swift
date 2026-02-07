import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = NSColor(hex: 0x272822)
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        minSize = NSSize(width: 320, height: 300)
        maxSize = NSSize(width: 800, height: 1200)

        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }

    override func resignKey() {
        super.resignKey()
        // Keep panel visible when losing key status
    }

    override func close() {
        orderOut(nil)
    }
}
