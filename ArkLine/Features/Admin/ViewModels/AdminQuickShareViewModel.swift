import SwiftUI

@MainActor
@Observable
class AdminQuickShareViewModel {
    var selectedPlan: StripePlan = .foundingMonthly
    var qrImage: UIImage?
    var isSaving = false
    var saveSuccess = false
    var copied = false
    var errorMessage: String?

    var shareText: String {
        "Join Arkline \u{2014} Financial Intelligence\n\n\(selectedPlan.displayName)\n\(selectedPlan.paymentURL)"
    }

    func generateQR() {
        qrImage = QRCodeGenerator.generate(forURL: selectedPlan.paymentURL, size: 250)
    }

    func generateHighResQR() -> UIImage? {
        QRCodeGenerator.generate(forURL: selectedPlan.paymentURL, size: 1024)
    }

    func copyURL() {
        #if canImport(UIKit)
        UIPasteboard.general.string = selectedPlan.paymentURL
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
        #endif
    }

    func saveToPhotos() {
        #if canImport(UIKit)
        guard let image = generateHighResQR() else {
            errorMessage = "Failed to generate QR code"
            return
        }
        isSaving = true
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        isSaving = false
        saveSuccess = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            saveSuccess = false
        }
        #endif
    }

    func share() {
        #if canImport(UIKit)
        var items: [Any] = [shareText]
        if let qr = generateHighResQR() {
            items.append(qr)
        }

        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            // Handle iPad popover
            activityVC.popoverPresentationController?.sourceView = root.view
            root.present(activityVC, animated: true)
        }
        #endif
    }
}
