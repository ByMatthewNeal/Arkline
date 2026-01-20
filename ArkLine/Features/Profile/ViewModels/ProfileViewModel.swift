import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Profile Stats
struct ProfileStatsData {
    var dcaReminders: Int = 0
    var chatSessions: Int = 0
    var portfolios: Int = 0
}

// MARK: - Activity Item
struct ActivityItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let timestamp: Date

    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Profile View Model
@Observable
final class ProfileViewModel {
    // MARK: - State
    var user: User?
    var isLoading = false
    var error: AppError?

    // MARK: - Stats
    var stats = ProfileStatsData()

    // MARK: - Activity
    var recentActivity: [ActivityItem] = []

    // MARK: - Referral
    var referralCode = "ARKLINE2024"
    var referralCount = 3

    // MARK: - Computed Properties
    var displayName: String {
        user?.fullName ?? user?.username ?? "User"
    }

    var initials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var memberSince: String {
        guard let date = user?.createdAt else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Initialization
    init(user: User? = nil) {
        self.user = user ?? createMockUser()
        loadMockData()
    }

    private func loadMockData() {
        // Load mock stats (replace with real data from Supabase in production)
        stats = ProfileStatsData(
            dcaReminders: 12,
            chatSessions: 45,
            portfolios: 3
        )

        // Load mock activity (replace with real data from Supabase in production)
        recentActivity = [
            ActivityItem(
                icon: "arrow.down.left",
                iconColor: AppColors.success,
                title: "Bought 0.01 BTC",
                subtitle: "",
                timestamp: Date().addingTimeInterval(-7200) // 2 hours ago
            ),
            ActivityItem(
                icon: "bell.fill",
                iconColor: AppColors.warning,
                title: "DCA Reminder completed",
                subtitle: "",
                timestamp: Date().addingTimeInterval(-86400) // Yesterday
            ),
            ActivityItem(
                icon: "bubble.left.fill",
                iconColor: AppColors.accent,
                title: "Asked AI about ETH",
                subtitle: "",
                timestamp: Date().addingTimeInterval(-172800) // 2 days ago
            )
        ]
    }

    private func createMockUser() -> User {
        User(
            id: UUID(),
            username: "cryptotrader",
            email: "trader@example.com",
            fullName: "John Doe",
            avatarUrl: nil,
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()),
            careerIndustry: "Technology",
            experienceLevel: "intermediate",
            socialLinks: SocialLinks(
                twitter: "cryptotrader",
                linkedin: nil,
                telegram: nil,
                website: nil
            ),
            preferredCurrency: "USD",
            riskCoins: ["BTC", "ETH"],
            darkMode: "automatic",
            notifications: NotificationSettings(
                pushEnabled: true,
                emailEnabled: true,
                dcaReminders: true,
                priceAlerts: true,
                communityUpdates: false,
                marketNews: true
            ),
            passcodeHash: nil,
            faceIdEnabled: true,
            createdAt: Date().addingTimeInterval(-86400 * 180),
            updatedAt: Date()
        )
    }

    // MARK: - Actions
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // TODO: Fetch real data from Supabase
        // For now, reload mock data
        try? await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {
            loadMockData()
        }
    }

    func loadStats() async {
        // TODO: Implement real stats loading from Supabase
        // Example:
        // let dcaCount = try await SupabaseManager.shared.database
        //     .from(SupabaseTable.dcaReminders.rawValue)
        //     .select("*", head: true, count: .exact)
        //     .eq("user_id", value: userId)
        //     .execute()
        //     .count
    }

    func loadRecentActivity() async {
        // TODO: Implement real activity loading from Supabase
        // This would aggregate from transactions, chat sessions, etc.
    }

    func copyReferralCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = referralCode
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(referralCode, forType: .string)
        #endif
    }

    func shareReferral() {
        let referralLink = "https://arkline.app/invite?code=\(referralCode)"
        let shareText = "Join me on ArkLine - the best crypto sentiment tracker! Use my referral code \(referralCode) to get started: \(referralLink)"

        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        // For iPad: Set the source view for the popover
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                        y: rootViewController.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        rootViewController.present(activityViewController, animated: true)
        #endif
    }
}
