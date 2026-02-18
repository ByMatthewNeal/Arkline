import SwiftUI

// MARK: - Trial Duration Options

enum TrialDuration: Int, CaseIterable, Identifiable {
    case none = 0
    case sevenDays = 7
    case oneMonth = 30
    case threeMonths = 90
    case sixMonths = 180

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .sevenDays: return "7 days"
        case .oneMonth: return "1 month"
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        }
    }
}

// MARK: - Create Invite Code Sheet

struct CreateInviteCodeSheet: View {
    @Bindable var viewModel: InviteCodeAdminViewModel
    let userId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTrialDuration: TrialDuration = .none

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    if let lastCode = viewModel.lastCreatedCode {
                        createdCodeSection(lastCode)
                    } else {
                        formSection
                    }

                    // Generate button
                    PrimaryButton(
                        title: viewModel.lastCreatedCode != nil ? "Generate Another" : "Generate Code",
                        action: {
                            viewModel.trialDays = selectedTrialDuration == .none ? nil : selectedTrialDuration.rawValue
                            Task { await viewModel.createCode(createdBy: userId) }
                            selectedTrialDuration = .none
                        },
                        isLoading: viewModel.isCreating
                    )

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.error)
                    }
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.vertical, ArkSpacing.lg)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("New Invite Code")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.lastCreatedCode = nil
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: ArkSpacing.lg) {
            // Recipient name
            CustomTextField(
                placeholder: "Recipient name (optional)",
                text: $viewModel.recipientName,
                icon: "person.fill"
            )

            // Recipient email
            CustomTextField(
                placeholder: "Email (optional)",
                text: $viewModel.recipientEmail,
                icon: "envelope.fill"
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            // Note
            CustomTextField(
                placeholder: "Note (optional)",
                text: $viewModel.note,
                icon: "note.text"
            )

            // Expiration picker
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("Expires in")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)

                Picker("Expiration", selection: $viewModel.expirationDays) {
                    Text("1 day").tag(1)
                    Text("3 days").tag(3)
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
            }

            // Trial duration picker
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("Free trial")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)

                Picker("Trial", selection: $selectedTrialDuration) {
                    ForEach(TrialDuration.allCases) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Created Code Section

    private func createdCodeSection(_ code: InviteCode) -> some View {
        VStack(spacing: ArkSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(AppColors.success)

            Text(code.code)
                .font(AppFonts.title24)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // QR Code
            QRCodeView(code: code.code, size: 200)
                .padding(ArkSpacing.md)
                .background(Color.white)
                .cornerRadius(ArkSpacing.md)

            // Info badges
            HStack(spacing: ArkSpacing.sm) {
                if let email = code.email, !email.isEmpty {
                    badgeView(icon: "envelope.fill", text: email)
                }
                if code.isFreeTrial, let days = code.trialDays {
                    badgeView(icon: "clock.fill", text: "\(days)-day trial")
                }
            }

            // Action buttons
            HStack(spacing: ArkSpacing.md) {
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = code.code
                    #endif
                } label: {
                    Label("Copy Code", systemImage: "doc.on.doc")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.accent)
                }

                Button {
                    shareCode(code)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func badgeView(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(AppFonts.caption12Medium)
        .foregroundColor(AppColors.accent)
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xxs)
        .background(AppColors.accent.opacity(0.12))
        .clipShape(Capsule())
    }

    private func shareCode(_ code: InviteCode) {
        #if canImport(UIKit)
        let deepLink = "arkline://invite?code=\(code.code)"
        let text = "You've been invited to ArkLine!\n\nYour invite code: \(code.code)\n\nOpen this link to get started: \(deepLink)"

        var items: [Any] = [text]
        if let qrImage = QRCodeGenerator.generate(for: code.code) {
            items.append(qrImage)
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
        #endif
    }
}
