import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum InviteMode: String, CaseIterable {
    case payment = "Payment"
    case comped = "Comped"
}

enum SendInviteState: Equatable {
    case idle
    case loading
    case successPayment(checkoutURL: String)
    case successComped(code: String)
    case error(String)

    static func == (lhs: SendInviteState, rhs: SendInviteState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading): return true
        case (.successPayment(let a), .successPayment(let b)): return a == b
        case (.successComped(let a), .successComped(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

@MainActor
@Observable
class SendInviteViewModel {
    // MARK: - Form State

    var inviteMode: InviteMode = .payment
    var email = ""
    var recipientName = ""
    var note = ""
    var selectedPlan: StripePlan = .foundingMonthly

    // MARK: - Result State

    var state: SendInviteState = .idle

    var isSending: Bool {
        if case .loading = state { return true }
        return false
    }

    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var canSend: Bool { isEmailValid && !isSending }

    // MARK: - Service

    private let adminService: AdminServiceProtocol

    init(adminService: AdminServiceProtocol = AdminService()) {
        self.adminService = adminService
    }

    // MARK: - Actions

    func sendInvite() async {
        state = .loading

        do {
            switch inviteMode {
            case .payment:
                let response = try await adminService.createCheckoutSession(
                    email: email.trimmingCharacters(in: .whitespaces),
                    recipientName: recipientName.nilIfEmpty,
                    note: note.nilIfEmpty,
                    priceId: selectedPlan.priceId
                )
                state = .successPayment(checkoutURL: response.checkoutUrl)

            case .comped:
                let response = try await adminService.createCompedInvite(
                    email: email.trimmingCharacters(in: .whitespaces),
                    recipientName: recipientName.nilIfEmpty,
                    note: note.nilIfEmpty,
                    sendEmail: true,
                    tier: selectedPlan.isFounder ? "founding" : "standard"
                )
                state = .successComped(code: response.code)
            }
        } catch {
            state = .error(AppError.from(error).userMessage)
        }
    }

    func shareCheckoutLink() {
        guard case .successPayment(let url) = state else { return }
        let name = recipientName.isEmpty ? "" : " \(recipientName)"
        let text = "Hey\(name), here's your exclusive invite to Arkline. Complete your membership here: \(url)"

        #if canImport(UIKit)
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = root.view
            root.present(activityVC, animated: true)
        }
        #endif
    }

    func shareCompedCode() {
        guard case .successComped(let code) = state else { return }
        let deepLink = "arkline://invite?code=\(code)"
        let name = recipientName.isEmpty ? "" : " \(recipientName)"
        let text = "Hey\(name), you've been invited to Arkline! Your invite code: \(code)\n\nOpen in app: \(deepLink)"

        #if canImport(UIKit)
        var items: [Any] = [text]
        if let qr = QRCodeGenerator.generate(for: code, size: 1024) {
            items.append(qr)
        }
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = root.view
            root.present(activityVC, animated: true)
        }
        #endif
    }

    func reset() {
        state = .idle
        email = ""
        recipientName = ""
        note = ""
        selectedPlan = .foundingMonthly
        inviteMode = .payment
    }
}
