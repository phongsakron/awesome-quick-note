import SwiftUI

struct NoteEditorView: NSViewRepresentable {
    @Binding var text: String
    var fontSettings: FontSettings
    var onImagePaste: ((NSImage) -> String?)?
    var shouldFocus: Bool = false

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
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        textView.string = text
        context.coordinator.highlighter.highlight(textView.textStorage!)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let coordinator = context.coordinator
        let fontChanged = coordinator.currentFontFamily != fontSettings.fontFamily
            || coordinator.currentFontSize != fontSettings.fontSize

        if fontChanged {
            coordinator.currentFontFamily = fontSettings.fontFamily
            coordinator.currentFontSize = fontSettings.fontSize
            coordinator.highlighter.updateFonts(from: fontSettings)
            textView.font = fontSettings.editorFont()
            coordinator.highlighter.highlight(textView.textStorage!)
        }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            coordinator.highlighter.highlight(textView.textStorage!)
            textView.selectedRanges = selectedRanges
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
        let highlighter: MarkdownHighlighter
        var currentFontFamily: String
        var currentFontSize: CGFloat
        private var debounceTask: Task<Void, Never>?

        init(_ parent: NoteEditorView) {
            self.parent = parent
            self.highlighter = MarkdownHighlighter(fontSettings: parent.fontSettings)
            self.currentFontFamily = parent.fontSettings.fontFamily
            self.currentFontSize = parent.fontSettings.fontSize
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            highlighter.highlight(textView.textStorage!)

            let newText = textView.string

            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self.parent.text = newText
            }
        }
    }
}

final class MarkdownNSTextView: NSTextView {
    var onImagePaste: ((NSImage) -> String?)?

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // Check for image paste first
        if let image = NSImage(pasteboard: pasteboard),
           let onImagePaste,
           let markdown = onImagePaste(image) {
            insertText(markdown, replacementRange: selectedRange())
            return
        }

        // Strip rich text: extract plain string only
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
