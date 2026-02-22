import SwiftUI
import Foundation
import Supabase
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
@MainActor
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
        self.user = user
    }

    // MARK: - Actions
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        await loadStats()
    }

    func loadStats() async {
        guard let userId = await MainActor.run(body: { SupabaseAuthManager.shared.currentUserId }) else {
            return
        }

        do {
            let db = SupabaseManager.shared.database

            async let dcaResult = db
                .from(SupabaseTable.dcaReminders.rawValue)
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId.uuidString)
                .execute()

            async let portfolioResult = db
                .from(SupabaseTable.portfolios.rawValue)
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId.uuidString)
                .execute()

            async let chatResult = db
                .from(SupabaseTable.chatSessions.rawValue)
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId.uuidString)
                .execute()

            let (dca, portfolios, chats) = try await (dcaResult, portfolioResult, chatResult)

            await MainActor.run {
                self.stats = ProfileStatsData(
                    dcaReminders: dca.count ?? 0,
                    chatSessions: chats.count ?? 0,
                    portfolios: portfolios.count ?? 0
                )
            }
        } catch {
            logError("Failed to load profile stats: \(error)", category: .data)
        }
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
