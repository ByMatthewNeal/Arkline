import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct EarlyAccessSignup: Codable, Identifiable {
    let id: UUID
    let email: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}

@MainActor
@Observable
class EarlyAccessSignupsViewModel {
    var signups: [EarlyAccessSignup] = []
    var selectedIDs: Set<UUID> = []
    var isLoading = false
    var isDeleting = false
    var errorMessage: String?
    var successMessage: String?

    private let supabase = SupabaseManager.shared

    var isSelecting: Bool { !selectedIDs.isEmpty }

    var allSelected: Bool {
        !signups.isEmpty && selectedIDs.count == signups.count
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: [EarlyAccessSignup] = try await supabase.database
                .from(SupabaseTable.earlyAccessSignups.rawValue)
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            signups = result
            selectedIDs = selectedIDs.intersection(Set(result.map(\.id)))
            errorMessage = nil
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    func delete(_ signup: EarlyAccessSignup) async {
        do {
            try await supabase.database
                .from(SupabaseTable.earlyAccessSignups.rawValue)
                .delete()
                .eq("id", value: signup.id.uuidString)
                .execute()
            signups.removeAll { $0.id == signup.id }
            selectedIDs.remove(signup.id)
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    func deleteSelected() async {
        guard !selectedIDs.isEmpty else { return }
        isDeleting = true
        defer { isDeleting = false }
        let ids = Array(selectedIDs).map(\.uuidString)
        do {
            try await supabase.database
                .from(SupabaseTable.earlyAccessSignups.rawValue)
                .delete()
                .in("id", values: ids)
                .execute()
            signups.removeAll { selectedIDs.contains($0.id) }
            selectedIDs.removeAll()
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func toggleSelectAll() {
        if allSelected {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(signups.map(\.id))
        }
    }

    func copyAllEmails() -> String {
        let emails = selectedIDs.isEmpty
            ? signups.map(\.email)
            : signups.filter { selectedIDs.contains($0.id) }.map(\.email)
        return emails.joined(separator: ", ")
    }

    func selectedEmails() -> [String] {
        if selectedIDs.isEmpty {
            return signups.map(\.email)
        }
        return signups.filter { selectedIDs.contains($0.id) }.map(\.email)
    }
}

struct EarlyAccessSignupsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = EarlyAccessSignupsViewModel()
    @State private var showDeleteConfirm = false
    @State private var signupToDelete: EarlyAccessSignup?
    @State private var showBatchDeleteConfirm = false
    @State private var showBatchInviteSheet = false
    @State private var selectedPlan: StripePlan = .foundingMonthly
    @State private var copiedToast = false

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Count card
                    MetricCard(
                        title: "Total Signups",
                        value: "\(viewModel.signups.count)",
                        icon: "envelope.fill",
                        color: AppColors.accent
                    )

                    // Action bar
                    if !viewModel.signups.isEmpty {
                        actionBar
                    }

                    if viewModel.isLoading && viewModel.signups.isEmpty {
                        ProgressView()
                            .padding(.top, ArkSpacing.xxl)
                    } else if let error = viewModel.errorMessage, viewModel.signups.isEmpty {
                        Text(error)
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.error)
                            .padding(.top, ArkSpacing.xxl)
                    } else {
                        // Signup list
                        VStack(spacing: ArkSpacing.xs) {
                            ForEach(viewModel.signups) { signup in
                                signupRow(signup)
                            }
                        }
                    }
                }
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.vertical, ArkSpacing.lg)
                .padding(.bottom, 100)
            }
            .refreshable {
                await viewModel.load()
            }

            // Copied toast
            if copiedToast {
                VStack {
                    Spacer()
                    Text("Copied to clipboard")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, ArkSpacing.lg)
                        .padding(.vertical, ArkSpacing.sm)
                        .background(AppColors.success)
                        .cornerRadius(ArkSpacing.Radius.full)
                        .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Early Access")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await viewModel.load()
        }
        .alert("Delete Signup", isPresented: $showDeleteConfirm, presenting: signupToDelete) { signup in
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(signup) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { signup in
            Text("Remove \(signup.email) from the early access list?")
        }
        .alert("Delete Selected", isPresented: $showBatchDeleteConfirm) {
            Button("Delete \(viewModel.selectedIDs.count)", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \(viewModel.selectedIDs.count) signup\(viewModel.selectedIDs.count == 1 ? "" : "s") from the early access list?")
        }
        .sheet(isPresented: $showBatchInviteSheet) {
            batchInviteSheet
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: ArkSpacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleSelectAll()
                }
            } label: {
                Label(
                    viewModel.allSelected ? "Deselect All" : "Select All",
                    systemImage: viewModel.allSelected ? "checkmark.circle.fill" : "circle"
                )
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.accent)
            }

            Spacer()

            // Copy emails
            Button {
                let emails = viewModel.copyAllEmails()
                #if os(iOS)
                UIPasteboard.general.string = emails
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(emails, forType: .string)
                #endif
                withAnimation { copiedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copiedToast = false }
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }

            // Send invite
            if viewModel.isSelecting {
                Button {
                    showBatchInviteSheet = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
            }

            // Delete selected
            if viewModel.isSelecting {
                Button {
                    showBatchDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.error)
                }
            }
        }
        .padding(.horizontal, ArkSpacing.sm)
    }

    // MARK: - Batch Invite Sheet

    private var batchInviteSheet: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                VStack(spacing: ArkSpacing.xl) {
                    let emails = viewModel.selectedEmails()

                    Text("\(emails.count) recipient\(emails.count == 1 ? "" : "s") selected")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    // Plan picker
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("Select Plan")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.textSecondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: ArkSpacing.xs) {
                            ForEach(StripePlan.allCases) { plan in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPlan = plan
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
                                        selectedPlan == plan ? .white : AppColors.textSecondary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ArkSpacing.sm)
                                    .background(
                                        selectedPlan == plan
                                        ? AppColors.accent
                                        : AppColors.cardBackground(colorScheme)
                                    )
                                    .cornerRadius(ArkSpacing.Radius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                                            .stroke(
                                                selectedPlan == plan
                                                ? Color.clear
                                                : Color.white.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }
                    }

                    // Share button
                    PrimaryButton(
                        title: "Share Link with \(emails.count) People",
                        action: { shareBatchInvite(emails: emails) },
                        icon: "square.and.arrow.up"
                    )

                    // Copy link only
                    SecondaryButton(
                        title: "Copy Link Only",
                        action: {
                            #if os(iOS)
                            UIPasteboard.general.string = selectedPlan.paymentURL
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(selectedPlan.paymentURL, forType: .string)
                            #endif
                            showBatchInviteSheet = false
                            withAnimation { copiedToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copiedToast = false }
                            }
                        },
                        icon: "link"
                    )

                    Spacer()
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.top, ArkSpacing.lg)
            }
            .navigationTitle("Send Invite")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBatchInviteSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func shareBatchInvite(emails: [String]) {
        let link = selectedPlan.paymentURL
        let emailList = emails.joined(separator: ", ")
        let message = "Hey! You signed up for early access to Arkline \u{2014} we're live now. Here's your exclusive invite to join: \(link)"

        #if os(iOS)
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = root.view
            root.present(activityVC, animated: true)
        }
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(emailList)\n\n\(message)", forType: .string)
        #endif
        showBatchInviteSheet = false
    }

    // MARK: - Row

    private func signupRow(_ signup: EarlyAccessSignup) -> some View {
        HStack(spacing: ArkSpacing.sm) {
            // Selection circle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleSelection(signup.id)
                }
            } label: {
                Image(systemName: viewModel.selectedIDs.contains(signup.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.selectedIDs.contains(signup.id) ? AppColors.accent : AppColors.textSecondary.opacity(0.4))
            }

            Image(systemName: "envelope.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(signup.email)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(signup.createdAt.formatted(.dateTime.month().day().year().hour().minute()))
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: 12)
        .contextMenu {
            Button {
                #if os(iOS)
                UIPasteboard.general.string = signup.email
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(signup.email, forType: .string)
                #endif
            } label: {
                Label("Copy Email", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                signupToDelete = signup
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack {
        EarlyAccessSignupsView()
    }
}
