import SwiftUI

enum Monokai {
    static let background = Color(hex: 0x272822)
    static let foreground = Color(hex: 0xF8F8F2)
    static let keyword = Color(hex: 0xF92672)
    static let string = Color(hex: 0xE6DB74)
    static let function = Color(hex: 0xA6E22E)
    static let type = Color(hex: 0x66D9EF)
    static let number = Color(hex: 0xAE81FF)
    static let comment = Color(hex: 0x75715E)

    static let backgroundNS = NSColor(hex: 0x272822)
    static let foregroundNS = NSColor(hex: 0xF8F8F2)
    static let keywordNS = NSColor(hex: 0xF92672)
    static let stringNS = NSColor(hex: 0xE6DB74)
    static let functionNS = NSColor(hex: 0xA6E22E)
    static let typeNS = NSColor(hex: 0x66D9EF)
    static let numberNS = NSColor(hex: 0xAE81FF)
    static let commentNS = NSColor(hex: 0x75715E)
    static let codeBlockBgNS = NSColor(hex: 0x1E1F1C)
    static let inlineCodeBgNS = NSColor(hex: 0x3E3D32)

    static let panelBackground = Color(hex: 0x272822).opacity(0.9)
    static let toolbarBackground = Color(hex: 0x1E1F1C)
    static let tabBackground = Color(hex: 0x3E3D32)
    static let tabActiveBackground = Color(hex: 0x49483E)
    static let border = Color(hex: 0x75715E).opacity(0.3)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

extension NSColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
