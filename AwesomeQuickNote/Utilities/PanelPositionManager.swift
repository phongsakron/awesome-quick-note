import AppKit

enum PanelPosition: String, CaseIterable {
    case center
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var displayName: String {
        switch self {
        case .center: "Center"
        case .left: "Left"
        case .right: "Right"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        }
    }

    func frame(for panelSize: NSSize, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let padding: CGFloat = 20

        let x: CGFloat
        let y: CGFloat

        switch self {
        case .center:
            x = visible.midX - panelSize.width / 2
            y = visible.midY - panelSize.height / 2
        case .left:
            x = visible.minX + padding
            y = visible.midY - panelSize.height / 2
        case .right:
            x = visible.maxX - panelSize.width - padding
            y = visible.midY - panelSize.height / 2
        case .topLeft:
            x = visible.minX + padding
            y = visible.maxY - panelSize.height - padding
        case .topRight:
            x = visible.maxX - panelSize.width - padding
            y = visible.maxY - panelSize.height - padding
        case .bottomLeft:
            x = visible.minX + padding
            y = visible.minY + padding
        case .bottomRight:
            x = visible.maxX - panelSize.width - padding
            y = visible.minY + padding
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: panelSize)
    }
}
