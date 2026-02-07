import AppKit

final class EditorOverlayManager {
    private weak var textView: NSTextView?
    private var vaultURL: URL?

    private var copyOverlays: [CopyOverlay] = []
    private var imageOverlays: [ImageOverlay] = []
    private var imageCache: [String: NSImage] = [:]

    func configure(textView: NSTextView, vaultURL: URL?) {
        self.textView = textView
        self.vaultURL = vaultURL
    }

    func updateVaultURL(_ url: URL?) {
        self.vaultURL = url
    }

    func updateOverlays(from result: HighlightResult) {
        guard let textView else { return }

        // Remove stale overlays
        clearOverlays()

        // Add code block copy buttons
        for codeBlock in result.codeBlocks {
            addCopyButton(for: codeBlock, in: textView)
        }

        // Add inline images
        for imageInfo in result.images {
            addInlineImage(for: imageInfo, in: textView)
        }
    }

    func repositionOverlays() {
        guard let textView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let containerOrigin = textView.textContainerInset

        for overlay in copyOverlays {
            guard overlay.range.location + overlay.range.length <= (textView.string as NSString).length else {
                overlay.button.isHidden = true
                continue
            }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: overlay.range, actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            let buttonSize = overlay.button.fittingSize
            let x = boundingRect.maxX + containerOrigin.width - buttonSize.width - 8
            let y = boundingRect.minY + containerOrigin.height + 2

            overlay.button.frame = NSRect(
                x: max(x, boundingRect.minX + containerOrigin.width),
                y: y,
                width: buttonSize.width,
                height: buttonSize.height
            )
            overlay.button.isHidden = false
        }

        for overlay in imageOverlays {
            guard overlay.range.location + overlay.range.length <= (textView.string as NSString).length else {
                overlay.imageView.isHidden = true
                continue
            }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: overlay.range, actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            let maxWidth = textContainer.containerSize.width - 24
            let imageSize = overlay.originalSize
            let scale = min(maxWidth / imageSize.width, 200 / imageSize.height, 1.0)
            let displayWidth = imageSize.width * scale
            let displayHeight = imageSize.height * scale

            let x = boundingRect.minX + containerOrigin.width
            let y = boundingRect.maxY + containerOrigin.height + 4

            overlay.imageView.frame = NSRect(x: x, y: y, width: displayWidth, height: displayHeight)
            overlay.imageView.isHidden = false
        }
    }

    func clearOverlays() {
        for overlay in copyOverlays {
            overlay.button.removeFromSuperview()
        }
        copyOverlays.removeAll()

        for overlay in imageOverlays {
            overlay.imageView.removeFromSuperview()
        }
        imageOverlays.removeAll()
    }

    // MARK: - Code Block Copy Button

    private func addCopyButton(for codeBlock: HighlightResult.CodeBlockInfo, in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        guard codeBlock.fullRange.location + codeBlock.fullRange.length <= (textView.string as NSString).length else { return }

        let button = NSButton(frame: .zero)
        let label = codeBlock.language ?? "Copy"
        button.title = label
        button.bezelStyle = .inline
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        button.contentTintColor = Monokai.foregroundNS
        button.wantsLayer = true
        button.layer?.backgroundColor = Monokai.codeBlockHeaderBgNS.cgColor
        button.layer?.cornerRadius = 4
        button.sizeToFit()

        let codeContent = codeBlock.codeContent
        button.target = nil
        button.action = #selector(CopyButtonTarget.copyAction(_:))

        let target = CopyButtonTarget(codeContent: codeContent, button: button, originalLabel: label)
        button.target = target

        // Position the button
        let containerOrigin = textView.textContainerInset
        let glyphRange = layoutManager.glyphRange(forCharacterRange: codeBlock.fullRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let buttonSize = button.fittingSize
        let x = boundingRect.maxX + containerOrigin.width - buttonSize.width - 8
        let y = boundingRect.minY + containerOrigin.height + 2

        button.frame = NSRect(
            x: max(x, boundingRect.minX + containerOrigin.width),
            y: y,
            width: buttonSize.width,
            height: buttonSize.height
        )

        textView.addSubview(button)

        let overlay = CopyOverlay(button: button, target: target, range: codeBlock.fullRange)
        copyOverlays.append(overlay)
    }

    // MARK: - Inline Image

    private func addInlineImage(for imageInfo: HighlightResult.ImageInfo, in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        guard imageInfo.range.location + imageInfo.range.length <= (textView.string as NSString).length else { return }

        // Resolve image path
        let image: NSImage?
        if let cached = imageCache[imageInfo.source] {
            image = cached
        } else {
            image = resolveImage(source: imageInfo.source)
            if let image {
                imageCache[imageInfo.source] = image
            }
        }

        guard let image else { return }

        let containerOrigin = textView.textContainerInset
        let glyphRange = layoutManager.glyphRange(forCharacterRange: imageInfo.range, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let maxWidth = textContainer.containerSize.width - 24
        let imageSize = image.size
        let scale = min(maxWidth / imageSize.width, 200 / imageSize.height, 1.0)
        let displayWidth = imageSize.width * scale
        let displayHeight = imageSize.height * scale

        let imageView = NSImageView(frame: NSRect(
            x: boundingRect.minX + containerOrigin.width,
            y: boundingRect.maxY + containerOrigin.height + 4,
            width: displayWidth,
            height: displayHeight
        ))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 4
        imageView.layer?.masksToBounds = true

        textView.addSubview(imageView)

        // Add paragraph spacing after the image line to make room
        let nsText = textView.string as NSString
        let lineRange = nsText.lineRange(for: imageInfo.range)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = displayHeight + 8
        textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)

        let overlay = ImageOverlay(
            imageView: imageView,
            range: imageInfo.range,
            originalSize: imageSize
        )
        imageOverlays.append(overlay)
    }

    private func resolveImage(source: String) -> NSImage? {
        // Try as absolute URL first
        if let url = URL(string: source), url.scheme != nil {
            return NSImage(contentsOf: url)
        }

        // Try relative to vault
        if let vaultURL {
            let fileURL = vaultURL.appendingPathComponent(source)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return NSImage(contentsOf: fileURL)
            }
        }

        // Try as file path directly
        if FileManager.default.fileExists(atPath: source) {
            return NSImage(contentsOfFile: source)
        }

        return nil
    }
}

// MARK: - Overlay Models

private struct CopyOverlay {
    let button: NSButton
    let target: CopyButtonTarget
    let range: NSRange
}

private struct ImageOverlay {
    let imageView: NSImageView
    let range: NSRange
    let originalSize: NSSize
}

// MARK: - Copy Button Target

private final class CopyButtonTarget: NSObject {
    let codeContent: String
    weak var button: NSButton?
    let originalLabel: String

    init(codeContent: String, button: NSButton, originalLabel: String) {
        self.codeContent = codeContent
        self.button = button
        self.originalLabel = originalLabel
    }

    @objc func copyAction(_ sender: NSButton) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeContent, forType: .string)

        // Show checkmark feedback
        sender.title = "\u{2713}"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, let button = self.button else { return }
            button.title = self.originalLabel
        }
    }
}
