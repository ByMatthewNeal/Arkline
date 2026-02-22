import SwiftUI

struct AdminQuickShareView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = AdminQuickShareViewModel()

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    planPicker
                    qrCodeSection
                    urlSection
                    actionButtons
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.vertical, ArkSpacing.lg)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Quick Share")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            viewModel.generateQR()
        }
        .onChange(of: viewModel.selectedPlan) { _, _ in
            viewModel.generateQR()
        }
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: ArkSpacing.xs) {
            ForEach(StripePlan.allCases) { plan in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedPlan = plan
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(plan.shortName)
                            .font(AppFonts.caption12Medium)
                        Text(plan.price)
                            .font(AppFonts.caption12)
                            .opacity(0.7)
                    }
                    .foregroundColor(
                        viewModel.selectedPlan == plan
                        ? .white
                        : AppColors.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(
                        viewModel.selectedPlan == plan
                        ? AppColors.accent
                        : AppColors.cardBackground(colorScheme)
                    )
                    .cornerRadius(ArkSpacing.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                            .stroke(
                                viewModel.selectedPlan == plan
                                ? Color.clear
                                : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                }
            }
        }
    }

    // MARK: - QR Code

    private var qrCodeSection: some View {
        VStack(spacing: ArkSpacing.md) {
            if let image = viewModel.qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding(ArkSpacing.lg)
                    .background(Color.white)
                    .cornerRadius(ArkSpacing.Radius.lg)
            } else {
                ProgressView()
                    .frame(width: 250, height: 250)
            }

            HStack(spacing: ArkSpacing.xs) {
                if viewModel.selectedPlan.isFounder {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.warning)
                }
                Text(viewModel.selectedPlan.displayName)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
        }
    }

    // MARK: - URL Section

    private var urlSection: some View {
        Button {
            viewModel.copyURL()
        } label: {
            HStack {
                Text(viewModel.selectedPlan.paymentURL)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Image(systemName: viewModel.copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.copied ? AppColors.success : AppColors.accent)
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: ArkSpacing.sm) {
            PrimaryButton(
                title: "Share Link",
                action: { viewModel.share() },
                icon: "square.and.arrow.up"
            )

            SecondaryButton(
                title: viewModel.saveSuccess ? "Saved!" : "Save QR to Photos",
                action: { viewModel.saveToPhotos() },
                isLoading: viewModel.isSaving,
                icon: viewModel.saveSuccess ? "checkmark" : "arrow.down.to.line"
            )

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminQuickShareView()
            .environmentObject(AppState())
    }
}
