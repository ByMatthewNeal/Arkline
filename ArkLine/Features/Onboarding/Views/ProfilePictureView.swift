import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfilePictureView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Text("Add a profile picture")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Help others recognize you")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                    .padding(.top, 40)

                    // Profile Picture Picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            if let selectedImage = selectedImage {
                                selectedImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        Text(viewModel.fullName.isEmpty ? "?" : String(viewModel.fullName.prefix(1)).uppercased())
                                            .font(.system(size: 60, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }

                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                .frame(width: 150, height: 150)

                            // Edit badge
                            Circle()
                                .fill(Color(hex: "6366F1"))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                )
                                .offset(x: 50, y: 50)
                        }
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
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

                    Spacer()
                }
            }

            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Continue",
                    action: {
                        Task {
                            await viewModel.saveProfilePicture()
                        }
                    }
                )

                Button(action: { viewModel.skipStep() }) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "0F0F0F"))
        .navigationBarBackButtonHidden()
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { viewModel.previousStep() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        ProfilePictureView(viewModel: OnboardingViewModel())
    }
}
