import SwiftUI

// MARK: - Search Bar
struct SearchBar: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var text: String
    var placeholder: String = "Search"
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)

                TextField(placeholder, text: $text)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .autocorrectionDisabled()
                    #if canImport(UIKit)
                    .textInputAutocapitalization(.never)
                    #endif
                    .focused($isFocused)
                    .onSubmit {
                        onSubmit?()
                    }

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(10)

            if isEditing {
                Button("Cancel") {
                    text = ""
                    isFocused = false
                    isEditing = false
                    onCancel?()
                }
                .foregroundColor(AppColors.accent)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .onChange(of: isFocused) { _, newValue in
            isEditing = newValue
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""))
        SearchBar(text: .constant("Bitcoin"))
    }
    .padding()
    .background(AppColors.background(.dark))
}
