import SwiftUI

/// A small "?" button that opens the dictionary filtered to a specific term.
/// Use as a view modifier or standalone button next to any technical term.
///
/// Usage:
///   Text("RSI").dictionaryLink("RSI")
///   DictionaryTermButton(term: "Fibonacci Retracement")
struct DictionaryTermButton: View {
    let term: String
    @State private var showDefinition = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button { showDefinition = true } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDefinition) {
            NavigationStack {
                DictionaryView(initialSearch: term)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showDefinition = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Adds a small "?" icon after this view that opens the dictionary to the specified term.
    func dictionaryLink(_ term: String) -> some View {
        HStack(spacing: 4) {
            self
            DictionaryTermButton(term: term)
        }
    }
}
