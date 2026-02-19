import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Custom Text Field
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    #if canImport(UIKit)
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    #endif
    var isDisabled: Bool = false
    var errorMessage: String? = nil

    @State private var isShowingPassword = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                        .frame(width: 24)
                }

                Group {
                    if isSecure && !isShowingPassword {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                #if canImport(UIKit)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                #endif
                .autocorrectionDisabled()
                .focused($isFocused)
                .foregroundColor(AppColors.textPrimary(colorScheme))

                if isSecure {
                    Button(action: { isShowingPassword.toggle() }) {
                        Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if !text.isEmpty && !isSecure {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)

            if let error = errorMessage {
                Text(error)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
            }
        }
    }

    private var iconColor: Color {
        if errorMessage != nil { return AppColors.error }
        if isFocused { return AppColors.focusRing }
        return AppColors.textSecondary
    }

    private var borderColor: Color {
        if errorMessage != nil { return AppColors.error }
        if isFocused { return AppColors.accent }
        return AppColors.cardBorder(colorScheme)
    }
}

// MARK: - Text Area
struct CustomTextArea: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    var maxHeight: CGFloat = 200
    var characterLimit: Int? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $text)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: minHeight, maxHeight: maxHeight)
            }
            .padding(12)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(10)
            .onChange(of: text) { _, newValue in
                if let limit = characterLimit, newValue.count > limit {
                    text = String(newValue.prefix(limit))
                }
            }

            if let limit = characterLimit {
                Text("\(text.count)/\(limit)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CustomTextField(
            placeholder: "Email",
            text: .constant(""),
            icon: "envelope.fill"
        )

        CustomTextField(
            placeholder: "Password",
            text: .constant("password"),
            icon: "lock.fill",
            isSecure: true
        )

        CustomTextField(
            placeholder: "Error state",
            text: .constant("Invalid input"),
            errorMessage: "Please enter a valid value"
        )

        CustomTextArea(
            placeholder: "Write something...",
            text: .constant(""),
            characterLimit: 200
        )
    }
    .padding()
    .background(AppColors.background(.dark))
}
