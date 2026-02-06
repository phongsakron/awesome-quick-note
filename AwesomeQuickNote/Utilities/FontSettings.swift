import AppKit
import Observation

@Observable
final class FontSettings: @unchecked Sendable {
    var fontFamily: String {
        didSet { UserDefaults.standard.set(fontFamily, forKey: "editorFontFamily") }
    }

    var fontSize: CGFloat {
        didSet { UserDefaults.standard.set(fontSize, forKey: "editorFontSize") }
    }

    let availableMonospacedFonts: [String]

    init() {
        let families = NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 14) else { return false }
            return font.isFixedPitch || family.localizedCaseInsensitiveContains("mono")
        }.sorted()

        self.availableMonospacedFonts = families

        let savedFamily = UserDefaults.standard.string(forKey: "editorFontFamily")
        if let savedFamily, families.contains(savedFamily) {
            self.fontFamily = savedFamily
        } else {
            self.fontFamily = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular).familyName ?? "Menlo"
        }

        let savedSize = UserDefaults.standard.double(forKey: "editorFontSize")
        self.fontSize = savedSize > 0 ? CGFloat(savedSize) : 14
    }

    func editorFont() -> NSFont {
        NSFont(name: fontFamily, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    func font(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let font = NSFont(name: fontFamily, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        return font
    }

    func boldFont(ofSize size: CGFloat) -> NSFont {
        let fm = NSFontManager.shared
        let base = font(ofSize: size, weight: .bold)
        return fm.convert(base, toHaveTrait: .boldFontMask)
    }

    func italicFont(ofSize size: CGFloat) -> NSFont {
        let fm = NSFontManager.shared
        let base = font(ofSize: size)
        return fm.convert(base, toHaveTrait: .italicFontMask)
    }

    func boldItalicFont(ofSize size: CGFloat) -> NSFont {
        let fm = NSFontManager.shared
        let base = boldFont(ofSize: size)
        return fm.convert(base, toHaveTrait: .italicFontMask)
    }
}
