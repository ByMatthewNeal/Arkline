import SwiftUI
import PhotosUI
import Kingfisher

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let user: User?
    let onSave: (User) -> Void

    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var usePhotoAvatar: Bool = true
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploading: Bool = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(user: User?, onSave: @escaping (User) -> Void) {
        self.user = user
        self.onSave = onSave
        _fullName = State(initialValue: user?.fullName ?? "")
        _username = State(initialValue: user?.username ?? "")
        _email = State(initialValue: user?.email ?? "")
        _usePhotoAvatar = State(initialValue: user?.usePhotoAvatar ?? true)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Avatar with Photo Picker
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        // Avatar display
                        if let imageData = selectedImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let avatarUrl = user?.avatarUrl,
                                  let url = URL(string: avatarUrl),
                                  usePhotoAvatar {
                            KFImage(url)
                                .resizable()
                                .placeholder { letterAvatar }
                                .fade(duration: 0.2)
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            letterAvatar
                        }

                        // Camera badge
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }
                .padding(.top, 20)

                // Photo avatar toggle
                if user?.avatarUrl != nil || selectedImageData != nil {
                    Toggle("Use Photo as Avatar", isOn: $usePhotoAvatar)
                        .font(AppFonts.body14)
                        .tint(AppColors.accent)
                        .padding(.horizontal, 20)
                }

                // Form fields
                VStack(spacing: 16) {
                    EditProfileField(
                        label: "Full Name",
                        text: $fullName,
                        placeholder: "Enter your name"
                    )

                    EditProfileField(
                        label: "Username",
                        text: $username,
                        placeholder: "Enter username"
                    )

                    EditProfileField(
                        label: "Email",
                        text: $email,
                        placeholder: "Enter email",
                        keyboardType: .emailAddress
                    )
                    .disabled(true)
                    .opacity(0.6)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Save button
                Button(action: saveProfile) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isUploading ? "Saving..." : "Save Changes")
                    }
                    .font(AppFonts.body14Bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accent)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty || isUploading)
                .opacity(fullName.trimmingCharacters(in: .whitespaces).isEmpty || isUploading ? 0.5 : 1)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Edit Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var initials: String {
        let name = fullName.isEmpty ? (user?.username ?? "U") : fullName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var letterAvatar: some View {
        ZStack {
            Circle()
                .fill(AppColors.accent.opacity(0.2))
                .frame(width: 100, height: 100)

            Text(initials)
                .font(AppFonts.title30)
                .foregroundColor(AppColors.accent)
        }
    }

    private func saveProfile() {
        guard var updatedUser = user else { return }

        isUploading = true

        Task {
            // Upload new image if selected
            if let imageData = selectedImageData {
                do {
                    // Convert to JPEG format (PhotosPicker may return HEIC/PNG)
                    let jpegData: Data
                    if let uiImage = UIImage(data: imageData),
                       let compressed = uiImage.jpegData(compressionQuality: 0.8) {
                        jpegData = compressed
                    } else {
                        jpegData = imageData
                    }

                    let avatarURL = try await AvatarUploadService.shared.uploadAvatar(
                        data: jpegData,
                        for: updatedUser.id
                    )
                    updatedUser.avatarUrl = avatarURL.absoluteString
                    updatedUser.usePhotoAvatar = true
                } catch {
                    AppLogger.shared.error("Avatar upload failed: \(error)")
                    await MainActor.run {
                        isUploading = false
                        errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                        showError = true
                    }
                    return
                }
            }

            updatedUser.fullName = fullName.trimmingCharacters(in: .whitespaces)
            updatedUser.username = username.trimmingCharacters(in: .whitespaces)
            updatedUser.usePhotoAvatar = usePhotoAvatar

            // Save to database
            let updateRequest = UpdateUserRequest(
                username: updatedUser.username,
                fullName: updatedUser.fullName,
                avatarUrl: updatedUser.avatarUrl,
                usePhotoAvatar: updatedUser.usePhotoAvatar
            )

            do {
                try await SupabaseDatabase.shared.update(
                    in: .profiles,
                    values: updateRequest,
                    id: updatedUser.id.uuidString
                )
            } catch {
                AppLogger.shared.error("Profile update failed: \(error.localizedDescription)")
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to save profile. Please try again."
                    showError = true
                }
                return
            }

            await MainActor.run {
                isUploading = false
                onSave(updatedUser)
                dismiss()
            }
        }
    }
}

// MARK: - Edit Profile Field
struct EditProfileField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            TextField(placeholder, text: $text)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color(hex: "F5F5F7"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.divider(colorScheme), lineWidth: 1)
                )
                #if os(iOS)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                #endif
        }
    }
}
