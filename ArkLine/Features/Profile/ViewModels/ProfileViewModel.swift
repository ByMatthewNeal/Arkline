import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Profile View Model
@Observable
final class ProfileViewModel {
    // MARK: - State
    var user: User?
    var isLoading = false
    var error: AppError?

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
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
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
        // TODO: Implement share sheet
    }
}
