import SwiftUI

struct NoteEditorView: NSViewRepresentable {
    @Binding var text: String
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
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
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

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        if shouldFocus && !context.coordinator.hasFocused {
            context.coordinator.hasFocused = true
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }

        if !shouldFocus {
            context.coordinator.hasFocused = false
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditorView
        weak var textView: NSTextView?
        var hasFocused = false
        private var debounceTask: Task<Void, Never>?

        init(_ parent: NoteEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
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

        if let image = NSImage(pasteboard: pasteboard),
           let onImagePaste,
           let markdown = onImagePaste(image) {
            insertText(markdown, replacementRange: selectedRange())
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
}
