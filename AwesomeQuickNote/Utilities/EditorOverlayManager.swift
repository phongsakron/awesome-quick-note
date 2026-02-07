import AppKit

final class EditorOverlayManager {
    private weak var textView: NSTextView?
    private var vaultURL: URL?

    private var copyOverlays: [CopyOverlay] = []
    private var imageOverlays: [ImageOverlay] = []
    private var imageCache: [String: NSImage] = [:]

    /// Cached result from last highlight pass, used for selection-change updates
    private(set) var lastResult: HighlightResult?
    /// Set of image line locations currently in "edit mode" (cursor on line)
    private var editingImageLines: Set<Int> = []

    func configure(textView: NSTextView, vaultURL: URL?) {
        self.textView = textView
        self.vaultURL = vaultURL
    }

    func updateVaultURL(_ url: URL?) {
        self.vaultURL = url
    }

    // MARK: - Full Update (after highlighting)

    func updateOverlays(from result: HighlightResult, cursorLocation: Int) {
        self.lastResult = result
        guard let textView else { return }

        clearOverlays()
        rebuildAllOverlays(in: textView, result: result, cursorLocation: cursorLocation)
    }

    // MARK: - Selection Change (lightweight — no re-highlight)

    func updateForSelectionChange(cursorLocation: Int) {
        guard let textView, let result = lastResult else { return }
        guard !result.images.isEmpty else { return }

        let textLength = (textView.string as NSString).length
        let nsText = textView.string as NSString
        let cursorLineRange = cursorLocation < textLength
            ? nsText.lineRange(for: NSRange(location: cursorLocation, length: 0))
            : NSRange(location: textLength, length: 0)

        // Determine which image lines now have the cursor
        var newEditingLines = Set<Int>()
        for imageInfo in result.images {
            guard imageInfo.range.location + imageInfo.range.length <= textLength else { continue }
            let imageLineRange = nsText.lineRange(for: imageInfo.range)
            if NSIntersectionRange(cursorLineRange, imageLineRange).length > 0 {
                newEditingLines.insert(imageLineRange.location)
            }
        }

        // Only rebuild if the set of editing lines changed
        guard newEditingLines != editingImageLines else { return }

        // Clear image overlays only (keep copy buttons)
        for overlay in imageOverlays {
            overlay.imageView.removeFromSuperview()
            overlay.openButton.removeFromSuperview()
            overlay.copyButton.removeFromSuperview()
        }
        imageOverlays.removeAll()

        // Rebuild image overlays with new cursor state
        rebuildImageOverlays(in: textView, result: result, cursorLocation: cursorLocation)
    }

    func repositionOverlays() {
        guard let textView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let containerOrigin = textView.textContainerInset
        let textLength = (textView.string as NSString).length

        for overlay in copyOverlays {
            guard overlay.range.location + overlay.range.length <= textLength else {
                overlay.button.isHidden = true
                continue
            }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: overlay.range, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else {
                overlay.button.isHidden = true
                continue
            }
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
            guard overlay.range.location + overlay.range.length <= textLength else {
                overlay.imageView.isHidden = true
                overlay.openButton.isHidden = true
                overlay.copyButton.isHidden = true
                continue
            }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: overlay.range, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else {
                overlay.imageView.isHidden = true
                overlay.openButton.isHidden = true
                overlay.copyButton.isHidden = true
                continue
            }
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            let x = boundingRect.minX + containerOrigin.width
            let y = boundingRect.maxY + containerOrigin.height + 4

            overlay.imageView.frame = NSRect(x: x, y: y,
                                              width: overlay.displaySize.width,
                                              height: overlay.displaySize.height)
            overlay.imageView.isHidden = false

            let openSize = overlay.openButton.fittingSize
            let copySize = overlay.copyButton.fittingSize
            let btnY = y + 4
            let btnX = x + overlay.displaySize.width - openSize.width - copySize.width - 12

            overlay.openButton.frame = NSRect(x: btnX, y: btnY, width: openSize.width, height: openSize.height)
            overlay.copyButton.frame = NSRect(x: btnX + openSize.width + 4, y: btnY, width: copySize.width, height: copySize.height)
            overlay.openButton.isHidden = false
            overlay.copyButton.isHidden = false
        }
    }

    func clearOverlays() {
        for overlay in copyOverlays {
            overlay.button.removeFromSuperview()
        }
        copyOverlays.removeAll()

        for overlay in imageOverlays {
            overlay.imageView.removeFromSuperview()
            overlay.openButton.removeFromSuperview()
            overlay.copyButton.removeFromSuperview()
        }
        imageOverlays.removeAll()
        editingImageLines.removeAll()
    }

    // MARK: - Private: Build All Overlays

    private func rebuildAllOverlays(in textView: NSTextView, result: HighlightResult, cursorLocation: Int) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let textLength = (textView.string as NSString).length

        // Phase 1: Apply textStorage changes for image lines (hide text + add spacing)
        rebuildImageAttributes(in: textView, result: result, cursorLocation: cursorLocation)

        // Phase 2: Layout is now valid — position overlays
        layoutManager.ensureLayout(for: textContainer)
        let containerOrigin = textView.textContainerInset

        // Copy buttons
        for codeBlock in result.codeBlocks {
            addCopyButton(for: codeBlock, in: textView, layoutManager: layoutManager,
                          textContainer: textContainer, containerOrigin: containerOrigin,
                          textLength: textLength)
        }

        // Image overlays (only for non-editing lines)
        positionImageOverlays(in: textView, result: result, layoutManager: layoutManager,
                              textContainer: textContainer, containerOrigin: containerOrigin,
                              textLength: textLength)
    }

    // MARK: - Private: Rebuild Image Overlays Only

    private func rebuildImageOverlays(in textView: NSTextView, result: HighlightResult, cursorLocation: Int) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let textLength = (textView.string as NSString).length

        // Phase 1: Apply textStorage changes
        rebuildImageAttributes(in: textView, result: result, cursorLocation: cursorLocation)

        // Phase 2: Position image overlays
        layoutManager.ensureLayout(for: textContainer)
        let containerOrigin = textView.textContainerInset

        positionImageOverlays(in: textView, result: result, layoutManager: layoutManager,
                              textContainer: textContainer, containerOrigin: containerOrigin,
                              textLength: textLength)
    }

    // MARK: - Phase 1: TextStorage Changes for Images

    private func rebuildImageAttributes(in textView: NSTextView, result: HighlightResult, cursorLocation: Int) {
        let textLength = (textView.string as NSString).length
        let nsText = textView.string as NSString
        guard let textContainer = textView.textContainer else { return }

        let cursorLineRange = cursorLocation < textLength
            ? nsText.lineRange(for: NSRange(location: cursorLocation, length: 0))
            : NSRange(location: textLength, length: 0)

        editingImageLines.removeAll()

        var hasChanges = false

        for imageInfo in result.images {
            guard imageInfo.range.location + imageInfo.range.length <= textLength else { continue }
            guard let img = resolveOrCacheImage(source: imageInfo.source) else { continue }
            guard img.size.width > 0, img.size.height > 0 else { continue }

            let imageLineRange = nsText.lineRange(for: imageInfo.range)
            let cursorOnLine = NSIntersectionRange(cursorLineRange, imageLineRange).length > 0

            if cursorOnLine {
                // Edit mode: cursor is on this line — text stays visible, no image
                editingImageLines.insert(imageLineRange.location)

                // Restore foreground color + remove paragraph spacing
                // (may have been set to .clear by a previous preview-mode pass)
                if !hasChanges {
                    textView.textStorage?.beginEditing()
                    hasChanges = true
                }
                textView.textStorage?.addAttribute(.foregroundColor, value: Monokai.typeNS,
                                                    range: imageLineRange)
                let defaultStyle = NSMutableParagraphStyle()
                defaultStyle.paragraphSpacing = 0
                textView.textStorage?.addAttribute(.paragraphStyle, value: defaultStyle,
                                                    range: imageLineRange)
            } else {
                // Preview mode: hide text, add spacing for rendered image
                if !hasChanges {
                    textView.textStorage?.beginEditing()
                    hasChanges = true
                }

                // Make the markdown text invisible
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.clear,
                                                    range: imageLineRange)

                // Add paragraph spacing to make room for the image
                let maxWidth = textContainer.containerSize.width - 24
                let scale = min(maxWidth / img.size.width, 200 / img.size.height, 1.0)
                let displayHeight = img.size.height * scale
                let style = NSMutableParagraphStyle()
                style.paragraphSpacing = displayHeight + 8
                textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: imageLineRange)
            }
        }

        if hasChanges {
            textView.textStorage?.endEditing()
        }
    }

    // MARK: - Phase 2: Position Image Overlays

    private func positionImageOverlays(
        in textView: NSTextView,
        result: HighlightResult,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        containerOrigin: NSSize,
        textLength: Int
    ) {
        let nsText = textView.string as NSString

        for imageInfo in result.images {
            guard imageInfo.range.location + imageInfo.range.length <= textLength else { continue }
            guard let img = resolveOrCacheImage(source: imageInfo.source) else { continue }
            guard img.size.width > 0, img.size.height > 0 else { continue }

            let imageLineRange = nsText.lineRange(for: imageInfo.range)

            // Skip images on the editing line (cursor is there — show text only)
            if editingImageLines.contains(imageLineRange.location) { continue }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: imageInfo.range, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else { continue }
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            let maxWidth = textContainer.containerSize.width - 24
            let scale = min(maxWidth / img.size.width, 200 / img.size.height, 1.0)
            let displayWidth = img.size.width * scale
            let displayHeight = img.size.height * scale

            let x = boundingRect.minX + containerOrigin.width
            let y = boundingRect.maxY + containerOrigin.height + 4

            let imageView = NSImageView(frame: NSRect(x: x, y: y, width: displayWidth, height: displayHeight))
            imageView.image = img
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 4
            imageView.layer?.masksToBounds = true

            // Resolve file URL for open/copy actions
            let resolvedURL = resolveImageURL(source: imageInfo.source)

            let openButton = makeImageActionButton(title: "Open")
            let copyButton = makeImageActionButton(title: "Copy")

            let target = ImageButtonTarget(image: img, fileURL: resolvedURL, openButton: openButton, copyButton: copyButton)
            openButton.target = target
            openButton.action = #selector(ImageButtonTarget.openAction(_:))
            copyButton.target = target
            copyButton.action = #selector(ImageButtonTarget.copyAction(_:))

            let openSize = openButton.fittingSize
            let copySize = copyButton.fittingSize
            let btnY = y + 4
            let btnX = x + displayWidth - openSize.width - copySize.width - 12

            openButton.frame = NSRect(x: btnX, y: btnY, width: openSize.width, height: openSize.height)
            copyButton.frame = NSRect(x: btnX + openSize.width + 4, y: btnY, width: copySize.width, height: copySize.height)

            textView.addSubview(imageView)
            textView.addSubview(openButton)
            textView.addSubview(copyButton)

            imageOverlays.append(ImageOverlay(
                imageView: imageView,
                openButton: openButton,
                copyButton: copyButton,
                target: target,
                range: imageInfo.range,
                displaySize: NSSize(width: displayWidth, height: displayHeight)
            ))
        }
    }

    // MARK: - Code Block Copy Button

    private func addCopyButton(
        for codeBlock: HighlightResult.CodeBlockInfo,
        in textView: NSTextView,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        containerOrigin: NSSize,
        textLength: Int
    ) {
        guard codeBlock.fullRange.location + codeBlock.fullRange.length <= textLength else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: codeBlock.fullRange, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound else { return }
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

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

        let target = CopyButtonTarget(codeContent: codeBlock.codeContent, button: button, originalLabel: label)
        button.target = target
        button.action = #selector(CopyButtonTarget.copyAction(_:))

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
        copyOverlays.append(CopyOverlay(button: button, target: target, range: codeBlock.fullRange))
    }

    // MARK: - Image Action Button Helper

    private func makeImageActionButton(title: String) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = title
        button.bezelStyle = .inline
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        button.contentTintColor = Monokai.foregroundNS
        button.wantsLayer = true
        button.layer?.backgroundColor = Monokai.codeBlockHeaderBgNS.cgColor
        button.layer?.cornerRadius = 4
        button.sizeToFit()
        return button
    }

    private func resolveImageURL(source: String) -> URL? {
        if let url = URL(string: source), url.scheme != nil {
            return url
        }
        if let vaultURL {
            let fileURL = vaultURL.appendingPathComponent(source)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        if FileManager.default.fileExists(atPath: source) {
            return URL(fileURLWithPath: source)
        }
        return nil
    }

    // MARK: - Image Resolution

    private func resolveOrCacheImage(source: String) -> NSImage? {
        if let cached = imageCache[source] { return cached }
        let img = resolveImage(source: source)
        if let img { imageCache[source] = img }
        return img
    }

    private func resolveImage(source: String) -> NSImage? {
        if let url = URL(string: source), url.scheme != nil {
            return NSImage(contentsOf: url)
        }
        if let vaultURL {
            let fileURL = vaultURL.appendingPathComponent(source)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return NSImage(contentsOf: fileURL)
            }
        }
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
    let openButton: NSButton
    let copyButton: NSButton
    let target: ImageButtonTarget
    let range: NSRange
    let displaySize: NSSize
}

// MARK: - Image Button Target

private final class ImageButtonTarget: NSObject {
    let image: NSImage
    let fileURL: URL?
    weak var openButton: NSButton?
    weak var copyButton: NSButton?

    init(image: NSImage, fileURL: URL?, openButton: NSButton, copyButton: NSButton) {
        self.image = image
        self.fileURL = fileURL
        self.openButton = openButton
        self.copyButton = copyButton
    }

    @objc func openAction(_ sender: NSButton) {
        if let fileURL {
            NSWorkspace.shared.open(fileURL)
        }
    }

    @objc func copyAction(_ sender: NSButton) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        sender.title = "\u{2713}"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton?.title = "Copy"
        }
    }
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

        sender.title = "\u{2713}"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, let button = self.button else { return }
            button.title = self.originalLabel
        }
    }
}
