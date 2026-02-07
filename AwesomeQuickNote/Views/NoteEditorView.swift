import SwiftUI

struct NoteEditorView: NSViewRepresentable {
    @Binding var text: String
    var fontSettings: FontSettings
    var onImagePaste: ((NSImage) -> String?)?
    var shouldFocus: Bool = false
    var vaultURL: URL? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        let textView = MarkdownNSTextView()
        textView.delegate = context.coordinator
        textView.onImagePaste = onImagePaste
        textView.vaultURL = vaultURL
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.font = fontSettings.editorFont()
        textView.textColor = Monokai.foregroundNS
        textView.insertionPointColor = Monokai.foregroundNS
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        textView.string = text

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.overlayManager.configure(textView: textView, vaultURL: vaultURL)

        // Highlight immediately for text colors
        let result = coordinator.highlighter.highlight(textView.textStorage!)

        scrollView.documentView = textView

        // Defer overlay building until the view has its final layout width
        // (textContainer width is 0 at this point, causing tiny images)
        DispatchQueue.main.async {
            let cursor = textView.selectedRange().location
            coordinator.overlayManager.updateOverlays(from: result, cursorLocation: cursor)
        }

        // Observe scroll for repositioning overlays
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // Observe frame changes for repositioning overlays
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.textViewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let coordinator = context.coordinator

        let fontChanged = coordinator.currentFontFamily != fontSettings.fontFamily
            || coordinator.currentFontSize != fontSettings.fontSize

        coordinator.overlayManager.updateVaultURL(vaultURL)
        (scrollView.documentView as? MarkdownNSTextView)?.vaultURL = vaultURL

        if fontChanged {
            coordinator.currentFontFamily = fontSettings.fontFamily
            coordinator.currentFontSize = fontSettings.fontSize
            coordinator.highlighter.updateFonts(from: fontSettings)
            textView.font = fontSettings.editorFont()

            let selectedRanges = textView.selectedRanges
            coordinator.overlayManager.clearOverlays()
            let result = coordinator.highlighter.highlight(textView.textStorage!)
            let cursor = textView.selectedRange().location
            coordinator.overlayManager.updateOverlays(from: result, cursorLocation: cursor)
            textView.selectedRanges = selectedRanges
        }

        // Only reset text when the editor has no pending unsaved changes.
        if textView.string != text && !coordinator.isEditorDirty {
            coordinator.overlayManager.clearOverlays()
            textView.string = text
            let result = coordinator.highlighter.highlight(textView.textStorage!)
            let cursor = textView.selectedRange().location
            coordinator.overlayManager.updateOverlays(from: result, cursorLocation: cursor)
        }

        if shouldFocus && !coordinator.hasFocused {
            coordinator.hasFocused = true
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }

        if !shouldFocus {
            coordinator.hasFocused = false
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditorView
        weak var textView: NSTextView?
        var hasFocused = false
        let highlighter: ASTHighlighter
        let overlayManager = EditorOverlayManager()
        var currentFontFamily: String
        var currentFontSize: CGFloat
        var isEditorDirty = false
        private var debounceTask: Task<Void, Never>?

        init(_ parent: NoteEditorView) {
            self.parent = parent
            self.highlighter = ASTHighlighter(fontSettings: parent.fontSettings)
            self.currentFontFamily = parent.fontSettings.fontFamily
            self.currentFontSize = parent.fontSettings.fontSize
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let selectedRanges = textView.selectedRanges

            overlayManager.clearOverlays()
            let result = highlighter.highlight(textView.textStorage!)
            let cursor = textView.selectedRange().location
            overlayManager.updateOverlays(from: result, cursorLocation: cursor)

            textView.selectedRanges = selectedRanges

            let newText = textView.string
            isEditorDirty = true

            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self.parent.text = newText
                self.isEditorDirty = false
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let cursor = textView.selectedRange().location
            overlayManager.updateForSelectionChange(cursorLocation: cursor)
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            overlayManager.repositionOverlays()
        }

        @objc func textViewFrameDidChange(_ notification: Notification) {
            overlayManager.repositionOverlays()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

final class MarkdownNSTextView: NSTextView {
    var onImagePaste: ((NSImage) -> String?)?
    var vaultURL: URL?

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        if let image = NSImage(pasteboard: pasteboard),
           let onImagePaste,
           let markdown = onImagePaste(image) {
            insertText(markdown, replacementRange: selectedRange())
            return
        }

        if let plainString = pasteboard.string(forType: .string) {
            insertText(plainString, replacementRange: selectedRange())
            return
        }

        super.paste(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let image = NSImage(pasteboard: pasteboard),
           let onImagePaste,
           let markdown = onImagePaste(image) {
            insertText(markdown, replacementRange: selectedRange())
            return true
        }

        return super.performDragOperation(sender)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            super.mouseDown(with: event)
            return
        }

        var fraction: CGFloat = 0
        let adjustedPoint = NSPoint(x: point.x - textContainerInset.width,
                                     y: point.y - textContainerInset.height)
        let charIndex = layoutManager.characterIndex(for: adjustedPoint,
                                                      in: textContainer,
                                                      fractionOfDistanceBetweenInsertionPoints: &fraction)

        guard charIndex < (string as NSString).length else {
            super.mouseDown(with: event)
            return
        }

        // Cmd+Click to open links
        if event.modifierFlags.contains(.command),
           let urlString = textStorage?.attribute(.markdownLink, at: charIndex, effectiveRange: nil) as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            return
        }

        // Cmd+Click to open images
        if event.modifierFlags.contains(.command),
           let source = textStorage?.attribute(.markdownImageSource, at: charIndex, effectiveRange: nil) as? String {
            if let url = URL(string: source), url.scheme != nil {
                NSWorkspace.shared.open(url)
            } else if let vaultURL {
                let fileURL = vaultURL.appendingPathComponent(source)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    NSWorkspace.shared.open(fileURL)
                }
            } else if FileManager.default.fileExists(atPath: source) {
                NSWorkspace.shared.open(URL(fileURLWithPath: source))
            }
            return
        }

        // Click to toggle checkboxes
        if let checkboxRange = textStorage?.attribute(.checkboxRange, at: charIndex, effectiveRange: nil) as? NSRange {
            toggleCheckbox(at: checkboxRange)
            return
        }

        super.mouseDown(with: event)
    }

    private func toggleCheckbox(at range: NSRange) {
        let text = string as NSString
        guard range.location + range.length <= text.length else { return }

        let current = text.substring(with: range)
        let replacement: String
        if current.contains(" ") {
            replacement = current.replacingOccurrences(of: "[ ]", with: "[x]")
        } else {
            replacement = current.replacingOccurrences(of: "[x]", with: "[ ]")
        }

        if shouldChangeText(in: range, replacementString: replacement) {
            replaceCharacters(in: range, with: replacement)
            didChangeText()
        }
    }
}
