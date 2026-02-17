import SwiftUI

// MARK: - Invite Code Management View

/// Admin-only view for generating, viewing, and revoking invite codes.
struct InviteCodeManagementView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = InviteCodeAdminViewModel()
    @State private var showingCreateSheet = false
    @State private var copiedCodeId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: ArkSpacing.lg) {
                statsSection
                filterSection
                if viewModel.isLoading && viewModel.codes.isEmpty {
                    ProgressView()
                        .padding(.top, ArkSpacing.xxxl)
                } else if viewModel.filteredCodes.isEmpty {
                    emptyState
                } else {
                    codeList
                }
            }
            .padding(.horizontal, ArkSpacing.md)
            .padding(.bottom, 100)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Invite Codes")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .refreshable {
            await viewModel.loadCodes()
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateInviteCodeSheet(
                viewModel: viewModel,
                userId: appState.currentUser?.id ?? UUID()
            )
        }
        .task {
            await viewModel.loadCodes()
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: ArkSpacing.sm) {
            InviteStatCard(title: "Active", value: "\(viewModel.activeCodes)", color: AppColors.accent)
            InviteStatCard(title: "Used", value: "\(viewModel.usedCodes)", color: AppColors.success)
            InviteStatCard(title: "Revoked", value: "\(viewModel.revokedCodes)", color: AppColors.error)
        }
        .padding(.top, ArkSpacing.md)
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ArkSpacing.xs) {
                ForEach(InviteCodeFilter.allCases, id: \.self) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(
                                viewModel.selectedFilter == filter
                                ? .white
                                : AppColors.textSecondary
                            )
                            .padding(.horizontal, ArkSpacing.sm)
                            .padding(.vertical, ArkSpacing.xs)
                            .background(
                                viewModel.selectedFilter == filter
                                ? AppColors.accent
                                : AppColors.cardBackground(colorScheme)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Code List

    private var codeList: some View {
        LazyVStack(spacing: ArkSpacing.sm) {
            ForEach(viewModel.filteredCodes) { code in
                InviteCodeRow(
                    code: code,
                    isCopied: copiedCodeId == code.id,
                    onCopy: { copyCode(code) },
                    onRevoke: { Task { await viewModel.revokeCode(code) } },
                    onDelete: { Task { await viewModel.deleteCode(code) } }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "ticket")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)
            Text("No invite codes")
                .font(AppFonts.title16)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("Tap + to generate your first invite code")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, ArkSpacing.xxxl)
    }

    // MARK: - Copy

    private func copyCode(_ code: InviteCode) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code.code
        #endif
        copiedCodeId = code.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedCodeId == code.id {
                copiedCodeId = nil
            }
        }
    }
}

// MARK: - Stat Card

struct InviteStatCard: View {
    let title: String
    let value: String
    let color: Color

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: ArkSpacing.xxs) {
            Text(value)
                .font(AppFonts.title24)
                .foregroundColor(color)
            Text(title)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }
}

// MARK: - Code Row

struct InviteCodeRow: View {
    let code: InviteCode
    let isCopied: Bool
    let onCopy: () -> Void
    let onRevoke: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Code + status
            HStack {
                Text(code.code)
                    .font(AppFonts.title16)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Text(code.statusLabel)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, ArkSpacing.xs)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Recipient
            if let name = code.recipientName {
                Text("For: \(name)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Note
            if let note = code.note {
                Text(note)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(2)
            }

            // Dates
            HStack {
                Text("Created \(code.createdAt.formatted(.relative(presentation: .named)))")
                    .font(AppFonts.footnote10)
                    .foregroundColor(AppColors.textTertiary)

                Spacer()

                if code.isUsed, let usedAt = code.usedAt {
                    Text("Used \(usedAt.formatted(.relative(presentation: .named)))")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.success)
                } else if !code.isRevoked {
                    Text("Expires \(code.expiresAt.formatted(.relative(presentation: .named)))")
                        .font(AppFonts.footnote10)
                        .foregroundColor(code.isExpired ? AppColors.error : AppColors.textTertiary)
                }
            }

            // Actions for active codes
            if code.isValid {
                HStack(spacing: ArkSpacing.md) {
                    Button(action: onCopy) {
                        Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.accent)
                    }

                    Button(action: onRevoke) {
                        Label("Revoke", systemImage: "xmark.circle")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.error)
                    }

                    Spacer()
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    private var statusColor: Color {
        switch code.statusLabel {
        case "Active": return AppColors.accent
        case "Used": return AppColors.success
        case "Expired": return AppColors.textSecondary
        case "Revoked": return AppColors.error
        default: return AppColors.textSecondary
        }
    }
}
