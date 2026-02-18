import SwiftUI
import AVFoundation

// MARK: - QR Scanner View (UIViewRepresentable)

/// AVFoundation camera view that scans QR codes.
/// Parses `arkline://invite?code=ARK-XXXXXX` deep links or raw `ARK-XXXXXX` codes.
struct QRScannerView: UIViewRepresentable {
    let onCodeScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        let onCodeScanned: (String) -> Void
        private var hasScanned = false

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let rawValue = object.stringValue else { return }

            let code = parseInviteCode(from: rawValue)
            guard let code else { return }

            hasScanned = true

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            session?.stopRunning()
            onCodeScanned(code)
        }

        /// Extracts an ARK-XXXXXX code from either a deep link or raw text.
        private func parseInviteCode(from value: String) -> String? {
            // Try deep link: arkline://invite?code=ARK-XXXXXX
            if let url = URL(string: value),
               url.scheme == "arkline",
               url.host == "invite",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
               code.hasPrefix("ARK-") {
                return code
            }

            // Try raw code: ARK-XXXXXX
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if trimmed.hasPrefix("ARK-") && trimmed.count == 10 {
                return trimmed
            }

            return nil
        }
    }
}
