import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QR Code Generator

/// CoreImage-based QR code generator for invite code deep links.
enum QRCodeGenerator {
    private static let context = CIContext()
    private static let filter = CIFilter.qrCodeGenerator()

    /// Generates a QR code UIImage for the given invite code.
    /// Encodes: `arkline://invite?code=ARK-XXXXXX`
    static func generate(for code: String, size: CGFloat = 250) -> UIImage? {
        let deepLink = "arkline://invite?code=\(code)"
        guard let data = deepLink.data(using: .utf8) else { return nil }

        filter.message = data
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale to desired size
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - SwiftUI View

/// Displays a QR code for an invite code with optional share button.
struct QRCodeView: View {
    let code: String
    let size: CGFloat

    init(code: String, size: CGFloat = 200) {
        self.code = code
        self.size = size
    }

    var body: some View {
        if let image = QRCodeGenerator.generate(for: code, size: size) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: size * 0.4))
                .foregroundColor(.secondary)
                .frame(width: size, height: size)
        }
    }
}
