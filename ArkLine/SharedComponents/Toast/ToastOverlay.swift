import SwiftUI

// MARK: - Toast Overlay

struct ToastOverlay: View {
    @Environment(\.colorScheme) var colorScheme
    let toast: ToastMessage
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(toast.type.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                if let message = toast.message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 12, y: 4)
        )
        .padding(.horizontal, 16)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Toast Modifier

struct ToastContainerModifier: ViewModifier {
    let toastManager: ToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = toastManager.currentToast {
                ToastOverlay(toast: toast) {
                    toastManager.dismiss()
                }
                .padding(.top, 8)
            }
        }
    }
}

extension View {
    func toastContainer(_ manager: ToastManager = .shared) -> some View {
        modifier(ToastContainerModifier(toastManager: manager))
    }
}
