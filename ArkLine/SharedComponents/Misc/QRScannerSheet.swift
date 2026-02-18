import SwiftUI
import AVFoundation

// MARK: - QR Scanner Sheet

/// Presented modally to scan an invite code QR.
/// Handles camera permission requests and displays a viewfinder overlay.
struct QRScannerSheet: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            ZStack {
                switch cameraPermission {
                case .authorized:
                    scannerContent
                case .notDetermined:
                    requestPermissionView
                default:
                    permissionDeniedView
                }
            }
            .navigationTitle("Scan QR Code")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Scanner Content

    private var scannerContent: some View {
        ZStack {
            QRScannerView { code in
                onCodeScanned(code)
                dismiss()
            }
            .ignoresSafeArea()

            // Viewfinder overlay
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.8), lineWidth: 3)
                    .frame(width: 250, height: 250)
                    .background(Color.clear)

                Text("Point at an invite QR code")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(.white)
                    .padding(.top, ArkSpacing.md)

                Spacer()
            }
        }
    }

    // MARK: - Request Permission

    private var requestPermissionView: some View {
        VStack(spacing: ArkSpacing.xl) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.accent)

            Text("Camera Access Required")
                .font(AppFonts.title20)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("ArkLine needs camera access to scan invite code QR codes.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.xl)

            PrimaryButton(title: "Allow Camera Access") {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        cameraPermission = granted ? .authorized : .denied
                    }
                }
            }
            .padding(.horizontal, ArkSpacing.xl)

            Spacer()
        }
        .background(AppColors.background(colorScheme))
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: ArkSpacing.xl) {
            Spacer()

            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)

            Text("Camera Access Denied")
                .font(AppFonts.title20)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Enable camera access in Settings to scan QR codes.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.xl)

            SecondaryButton(title: "Open Settings", action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }, icon: "gear")
            .padding(.horizontal, ArkSpacing.xl)

            Spacer()
        }
        .background(AppColors.background(colorScheme))
    }
}
