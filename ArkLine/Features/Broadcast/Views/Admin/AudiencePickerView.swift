import SwiftUI

// MARK: - Audience Picker View

/// View for selecting the target audience for a broadcast.
/// Allows admins to choose between all users, premium only, or specific users.
struct AudiencePickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Binding var targetAudience: TargetAudience

    @State private var selectedOption: AudienceOption = .all
    @State private var selectedUserIds: [UUID] = []
    @State private var userNames: [UUID: String] = [:]
    @State private var showingUserSearch = false

    private enum AudienceOption: String, CaseIterable {
        case all
        case specific

        var displayName: String {
            switch self {
            case .all: return "All Users"
            case .specific: return "Specific Users"
            }
        }

        var description: String {
            switch self {
            case .all: return "Send to everyone who has the app"
            case .specific: return "Select individual users to receive this broadcast"
            }
        }

        var iconName: String {
            switch self {
            case .all: return "person.3.fill"
            case .specific: return "person.crop.circle.badge.checkmark"
            }
        }

        var iconColor: Color {
            switch self {
            case .all: return AppColors.accent
            case .specific: return AppColors.success
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Audience Options
                Section {
                    ForEach(AudienceOption.allCases, id: \.self) { option in
                        audienceOptionRow(option)
                    }
                } header: {
                    Text("Select Audience")
                } footer: {
                    Text("Choose who will receive this broadcast and any associated push notifications.")
                }

                // Specific Users Section (shown only when specific is selected)
                if selectedOption == .specific {
                    Section {
                        if selectedUserIds.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(AppColors.textTertiary)
                                Text("No users selected")
                                    .font(ArkFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.vertical, ArkSpacing.xs)
                        } else {
                            ForEach(selectedUserIds, id: \.self) { userId in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(AppColors.accent)
                                    Text(userNames[userId] ?? String(userId.uuidString.prefix(8)) + "...")
                                        .font(ArkFonts.body)
                                        .foregroundColor(AppColors.textPrimary(colorScheme))
                                    Spacer()
                                    Button {
                                        selectedUserIds.removeAll { $0 == userId }
                                        userNames.removeValue(forKey: userId)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            showingUserSearch = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AppColors.accent)
                                Text("Add Users")
                                    .font(ArkFonts.body)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    } header: {
                        Text("Selected Users (\(selectedUserIds.count))")
                    }
                }

                // Stats Preview
                Section {
                    statsPreviewRow
                } header: {
                    Text("Estimated Reach")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Target Audience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSelection()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentSelection()
            }
            .sheet(isPresented: $showingUserSearch) {
                UserSearchSheet(
                    selectedUserIds: $selectedUserIds,
                    userNames: $userNames
                )
            }
        }
    }

    // MARK: - Audience Option Row

    private func audienceOptionRow(_ option: AudienceOption) -> some View {
        Button {
            selectedOption = option
        } label: {
            HStack(spacing: ArkSpacing.md) {
                Image(systemName: option.iconName)
                    .font(.title2)
                    .foregroundColor(option.iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text(option.displayName)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(option.description)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if selectedOption == option {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.vertical, ArkSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Preview

    private var statsPreviewRow: some View {
        HStack(spacing: ArkSpacing.md) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundColor(AppColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text(estimatedReachText)
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Will receive this broadcast")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, ArkSpacing.xs)
    }

    private var estimatedReachText: String {
        switch selectedOption {
        case .all:
            return "All Users"
        case .specific:
            let count = selectedUserIds.count
            return count == 0 ? "No users selected" : "\(count) user\(count == 1 ? "" : "s")"
        }
    }

    // MARK: - Actions

    private func loadCurrentSelection() {
        switch targetAudience {
        case .all, .premium:
            // Map legacy .premium to .all for backward compatibility
            selectedOption = .all
            selectedUserIds = []
        case .specific(let userIds):
            selectedOption = .specific
            selectedUserIds = userIds
        }
    }

    private func saveSelection() {
        switch selectedOption {
        case .all:
            targetAudience = .all
        case .specific:
            targetAudience = .specific(userIds: selectedUserIds)
        }
    }
}

// MARK: - User Search Sheet

private struct UserSearchSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Binding var selectedUserIds: [UUID]
    @Binding var userNames: [UUID: String]

    @State private var searchText = ""
    @State private var allMembers: [AdminMember] = []
    @State private var isLoading = false
    @State private var activeFilter: MemberFilter = .all

    private let adminService = AdminService()

    private enum MemberFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
    }

    /// Members filtered by search text and active filter, sorted alphabetically.
    private var filteredMembers: [AdminMember] {
        var result = allMembers

        // Apply active/inactive filter
        switch activeFilter {
        case .all: break
        case .active: result = result.filter { $0.isActive }
        case .inactive: result = result.filter { !$0.isActive }
        }

        // Apply search text filter
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty {
            result = result.filter {
                $0.displayName.lowercased().contains(trimmed) ||
                $0.email.lowercased().contains(trimmed)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)
                    TextField("Search by name or email...", text: $searchText)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.vertical, ArkSpacing.sm)
                .background(AppColors.cardBackground(colorScheme))

                // Filter chips
                HStack(spacing: ArkSpacing.xs) {
                    ForEach(MemberFilter.allCases, id: \.self) { filter in
                        Button {
                            activeFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(activeFilter == filter ? .white : AppColors.textSecondary)
                                .padding(.horizontal, ArkSpacing.sm)
                                .padding(.vertical, ArkSpacing.xxs)
                                .background(activeFilter == filter ? AppColors.accent : AppColors.cardBackground(colorScheme))
                                .cornerRadius(ArkSpacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.vertical, ArkSpacing.xs)

                Divider()

                // Results
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredMembers.isEmpty {
                    Spacer()
                    VStack(spacing: ArkSpacing.sm) {
                        Image(systemName: "person.slash")
                            .font(.largeTitle)
                            .foregroundColor(AppColors.textTertiary)
                        Text("No users found")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                } else {
                    List(filteredMembers) { member in
                        memberRow(member)
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Add Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadAllMembers()
            }
        }
    }

    private func memberRow(_ member: AdminMember) -> some View {
        let isSelected = selectedUserIds.contains(member.id)
        return HStack(spacing: ArkSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(member.initials)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ArkSpacing.xs) {
                    Text(member.displayName)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    if !member.isActive {
                        Text("Inactive")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.textTertiary.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                Text(member.email)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
            } else {
                Button {
                    selectedUserIds.append(member.id)
                    userNames[member.id] = member.displayName
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, ArkSpacing.xxs)
    }

    private func loadAllMembers() async {
        isLoading = true
        do {
            let response = try await adminService.fetchMembers(search: nil, status: nil, page: 1)
            allMembers = response.members.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch {
            logError("Failed to load members: \(error)", category: .data)
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    AudiencePickerView(targetAudience: .constant(.all))
}
