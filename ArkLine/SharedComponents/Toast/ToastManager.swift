import SwiftUI

// MARK: - Toast Message

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String?
    let duration: TimeInterval

    init(type: ToastType, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum ToastType {
    case error
    case warning
    case success
    case info

    var icon: String {
        switch self {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .error: return AppColors.error
        case .warning: return AppColors.warning
        case .success: return AppColors.success
        case .info: return AppColors.accent
        }
    }
}

// MARK: - Toast Manager

@Observable
final class ToastManager {
    static let shared = ToastManager()

    private(set) var currentToast: ToastMessage?
    private var queue: [ToastMessage] = []
    private var dismissTask: Task<Void, Never>?

    /// Dedup: don't show the same title twice within this window
    private var recentTitles: [String: Date] = [:]
    private static let dedupWindow: TimeInterval = 10

    private init() {}

    @MainActor
    func show(_ toast: ToastMessage) {
        // Deduplicate rapid-fire identical toasts
        let now = Date()
        if let lastShown = recentTitles[toast.title],
           now.timeIntervalSince(lastShown) < Self.dedupWindow {
            return
        }
        recentTitles[toast.title] = now

        if currentToast != nil {
            queue.append(toast)
        } else {
            present(toast)
        }
    }

    @MainActor
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) {
            currentToast = nil
        }
        // Show next in queue after brief delay
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            if let next = queue.first {
                queue.removeFirst()
                present(next)
            }
        }
    }

    @MainActor
    private func present(_ toast: ToastMessage) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = toast
        }
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    // MARK: - Convenience Methods

    @MainActor
    func error(_ title: String, message: String? = nil) {
        show(ToastMessage(type: .error, title: title, message: message))
    }

    @MainActor
    func warning(_ title: String, message: String? = nil) {
        show(ToastMessage(type: .warning, title: title, message: message))
    }

    @MainActor
    func success(_ title: String, message: String? = nil) {
        show(ToastMessage(type: .success, title: title, message: message))
    }

    @MainActor
    func info(_ title: String, message: String? = nil) {
        show(ToastMessage(type: .info, title: title, message: message))
    }
}
