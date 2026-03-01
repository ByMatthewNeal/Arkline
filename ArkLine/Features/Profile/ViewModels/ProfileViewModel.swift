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

// MARK: - Activity Query Rows
private struct PortfolioActivityRow: Decodable {
    let id: UUID
    let name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}

private struct PortfolioIdRow: Decodable {
    let id: UUID
}

private struct TransactionActivityRow: Decodable {
    let id: UUID
    let symbol: String
    let type: String
    let transactionDate: Date

    enum CodingKeys: String, CodingKey {
        case id, symbol, type
        case transactionDate = "transaction_date"
    }
}

private struct DCAActivityRow: Decodable {
    let id: UUID
    let name: String
    let symbol: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, symbol
        case createdAt = "created_at"
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

    // MARK: - Portfolio Allocation
    var allocations: [PortfolioAllocation] = []

    // MARK: - Activity
    var recentActivity: [ActivityItem] = []

    // MARK: - Referral
    var referralCode = ""
    var referralCount = 0
    var isLoadingReferral = false
    private let inviteCodeService = InviteCodeService()

    // MARK: - User ID
    var copiedUserId = false

    var shortUserId: String {
        guard let id = user?.id else { return "" }
        return String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }

    func copyUserId() {
        #if canImport(UIKit)
        UIPasteboard.general.string = shortUserId
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shortUserId, forType: .string)
        #endif
        copiedUserId = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { copiedUserId = false }
        }
    }

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

        async let statsTask: () = loadStats()
        async let activityTask: () = loadRecentActivity()
        async let referralTask: () = loadReferralCode()
        async let allocationTask: () = loadPortfolioAllocation()
        _ = await (statsTask, activityTask, referralTask, allocationTask)
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

            let (dca, portfolios) = try await (dcaResult, portfolioResult)

            await MainActor.run {
                self.stats = ProfileStatsData(
                    dcaReminders: dca.count ?? 0,
                    portfolios: portfolios.count ?? 0
                )
            }
        } catch {
            logError("Failed to load profile stats: \(error)", category: .data)
        }
    }

    func loadPortfolioAllocation() async {
        guard let userId = user?.id else { return }
        do {
            let portfolioService = ServiceContainer.shared.portfolioService
            let portfolios = try await portfolioService.fetchPortfolios(userId: userId)
            guard let primary = portfolios.first else { return }
            let holdings = try await portfolioService.fetchHoldings(portfolioId: primary.id)
            let holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: holdings)
            let computed = PortfolioAllocation.calculate(from: holdingsWithPrices)
            await MainActor.run {
                self.allocations = computed
            }
        } catch {
            logError("Failed to load portfolio allocation: \(error)", category: .data)
        }
    }

    func loadRecentActivity() async {
        guard let userId = await MainActor.run(body: { SupabaseAuthManager.shared.currentUserId }) else {
            return
        }

        do {
            let db = SupabaseManager.shared.database

            // Fetch portfolio IDs for the user
            let portfolioIds: [PortfolioIdRow] = try await db
                .from(SupabaseTable.portfolios.rawValue)
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let ids = portfolioIds.map { $0.id.uuidString }

            // Fetch recent data in parallel
            async let recentPortfolios: [PortfolioActivityRow] = db
                .from(SupabaseTable.portfolios.rawValue)
                .select("id, name, created_at")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value

            async let recentDCA: [DCAActivityRow] = db
                .from(SupabaseTable.dcaReminders.rawValue)
                .select("id, name, symbol, created_at")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value

            var items: [ActivityItem] = []

            let (portfolios, dcaReminders) = try await (recentPortfolios, recentDCA)

            // Map portfolios
            for p in portfolios {
                items.append(ActivityItem(
                    icon: "chart.pie.fill",
                    iconColor: AppColors.accent,
                    title: "Created portfolio \"\(p.name)\"",
                    subtitle: "",
                    timestamp: p.createdAt
                ))
            }

            // Map DCA reminders
            for d in dcaReminders {
                items.append(ActivityItem(
                    icon: "clock.arrow.circlepath",
                    iconColor: AppColors.warning,
                    title: "DCA reminder for \(d.symbol.uppercased())",
                    subtitle: "",
                    timestamp: d.createdAt
                ))
            }

            // Fetch transactions if user has portfolios
            if !ids.isEmpty {
                let recentTransactions: [TransactionActivityRow] = try await db
                    .from(SupabaseTable.transactions.rawValue)
                    .select("id, symbol, type, transaction_date")
                    .in("portfolio_id", values: ids)
                    .order("transaction_date", ascending: false)
                    .limit(5)
                    .execute()
                    .value

                for t in recentTransactions {
                    let isBuy = t.type.lowercased() == "buy"
                    items.append(ActivityItem(
                        icon: isBuy ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                        iconColor: isBuy ? AppColors.success : AppColors.error,
                        title: "\(isBuy ? "Bought" : "Sold") \(t.symbol.uppercased())",
                        subtitle: "",
                        timestamp: t.transactionDate
                    ))
                }
            }

            // Sort by timestamp descending, take top 10
            items.sort { $0.timestamp > $1.timestamp }
            let topItems = Array(items.prefix(10))

            await MainActor.run {
                self.recentActivity = topItems
            }
        } catch {
            logError("Failed to load recent activity: \(error)", category: .data)
        }
    }

    func loadReferralCode() async {
        guard let userId = user?.id else { return }

        isLoadingReferral = true
        defer { isLoadingReferral = false }

        do {
            // Fetch existing referral code, or create one
            if let existing = try await inviteCodeService.fetchReferralCode(for: userId) {
                referralCode = existing.code
            } else {
                let created = try await inviteCodeService.createReferralCode(for: userId)
                referralCode = created.code
            }

            // Fetch how many friends redeemed
            referralCount = try await inviteCodeService.fetchReferralCount(for: userId)
        } catch {
            logError("Failed to load referral code: \(error)", category: .data)
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
              var topController = windowScene.windows.first?.rootViewController else {
            return
        }

        // Walk up the presentation chain to find the topmost presented controller
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        // For iPad: Set the source view for the popover
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX,
                                        y: topController.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topController.present(activityViewController, animated: true)
        #endif
    }
}
