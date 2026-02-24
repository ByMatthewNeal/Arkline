#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - Markdown Text Editor

/// A `UIViewRepresentable` wrapping `UITextView` to expose `selectedRange`
/// — needed because SwiftUI's `TextEditor` doesn't provide selection access.
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont(name: "Inter-Regular", size: 14) ?? .systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.textColor = UIColor.label
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update text if it actually changed to avoid resetting cursor
        if textView.text != text {
            textView.text = text
        }

        // Only update selection if it differs and the text view isn't actively being edited
        let currentRange = textView.selectedRange
        if currentRange != selectedRange && !context.coordinator.isEditing {
            // Clamp range to valid bounds
            let maxLocation = (textView.text as NSString).length
            let clampedLocation = min(selectedRange.location, maxLocation)
            let clampedLength = min(selectedRange.length, maxLocation - clampedLocation)
            let clamped = NSRange(location: clampedLocation, length: clampedLength)
            textView.selectedRange = clamped
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: MarkdownTextEditor
        var isEditing = false

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.selectedRange = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
        }
    }
}
#endif
