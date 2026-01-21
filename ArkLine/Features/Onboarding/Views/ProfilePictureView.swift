import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Profile Picture View
struct ProfilePictureView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "camera.circle.fill",
                        title: "Add a profile picture",
                        subtitle: "Help others recognize you",
                        isOptional: true
                    )

                    // Profile picture picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ProfilePicturePreview(
                            selectedImage: selectedImage,
                            fullName: viewModel.fullName,
                            colorScheme: colorScheme
                        )
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task { @MainActor in
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                viewModel.profileImageData = data
                                #if canImport(UIKit)
                                if let uiImage = UIImage(data: data) {
                                    selectedImage = Image(uiImage: uiImage)
                                }
                                #elseif canImport(AppKit)
                                if let nsImage = NSImage(data: data) {
                                    selectedImage = Image(nsImage: nsImage)
                                }
                                #endif
                            }
                        }
                    }

                    // Hint
                    Text("Tap to select a photo from your library")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer(minLength: ArkSpacing.xxxl)
                }
            }

            // Bottom actions
            OnboardingBottomActions(
                primaryTitle: "Continue",
                primaryAction: {
                    Task {
                        await viewModel.saveProfilePicture()
                    }
                },
                showSkip: true,
                skipAction: { viewModel.skipStep() }
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Profile Picture Preview
struct ProfilePicturePreview: View {
    let selectedImage: Image?
    let fullName: String
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Selected image or placeholder
            if let selectedImage = selectedImage {
                selectedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
            } else {
                // Gradient placeholder with initial
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.fillPrimary, AppColors.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .overlay(
                        Text(fullName.isEmpty ? "?" : String(fullName.prefix(1)).uppercased())
                            .font(AppFonts.number44)
                            .foregroundColor(.white)
                    )
            }

            // Border
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 150, height: 150)

            // Camera badge
            Circle()
                .fill(AppColors.fillPrimary)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )
                .offset(x: 50, y: 50)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ProfilePictureView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
