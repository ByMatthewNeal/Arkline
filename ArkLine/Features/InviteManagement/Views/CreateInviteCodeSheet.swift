import SwiftUI

// MARK: - Create Invite Code Sheet

struct CreateInviteCodeSheet: View {
    @Bindable var viewModel: InviteCodeAdminViewModel
    let userId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: ArkSpacing.lg) {
                // Recipient name
                CustomTextField(
                    placeholder: "Recipient name (optional)",
                    text: $viewModel.recipientName,
                    icon: "person.fill"
                )

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

                Spacer()

                // Show last created code
                if let lastCode = viewModel.lastCreatedCode {
                    VStack(spacing: ArkSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.success)

                        Text(lastCode.code)
                            .font(AppFonts.title24)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = lastCode.code
                            #endif
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.bottom, ArkSpacing.lg)
                }

                // Generate button
                PrimaryButton(
                    title: viewModel.lastCreatedCode != nil ? "Generate Another" : "Generate Code",
                    action: {
                        Task { await viewModel.createCode(createdBy: userId) }
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
}
