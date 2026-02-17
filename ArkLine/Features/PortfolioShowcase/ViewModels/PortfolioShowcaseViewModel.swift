import SwiftUI
import Foundation

// MARK: - Portfolio Showcase ViewModel

@Observable
@MainActor
final class PortfolioShowcaseViewModel {
    // MARK: - Dependencies
    private let portfolioService: PortfolioServiceProtocol

    // MARK: - State
    var portfolios: [Portfolio] = []
    var configuration = ShowcaseConfiguration()

    var leftSnapshot: PortfolioSnapshot?
    var rightSnapshot: PortfolioSnapshot?

    var isLoading = false
    var isLoadingLeft = false
    var isLoadingRight = false
    var error: AppError?

    // User context
    private var currentUserId: UUID?

    // MARK: - Computed Properties

    var privacyLevel: PrivacyLevel {
        get { configuration.privacyLevel }
        set {
            configuration.privacyLevel = newValue
            regenerateSnapshots()
        }
    }

    var hasBothPortfolios: Bool {
        leftSnapshot != nil && rightSnapshot != nil
    }

    var hasAnyPortfolio: Bool {
        leftSnapshot != nil || rightSnapshot != nil
    }

    var canExport: Bool {
        hasAnyPortfolio
    }

    /// Portfolios available for left selection (exclude right if selected)
    var availableForLeft: [Portfolio] {
        if let rightId = configuration.rightPortfolioId {
            return portfolios.filter { $0.id != rightId }
        }
        return portfolios
    }

    /// Portfolios available for right selection (exclude left if selected)
    var availableForRight: [Portfolio] {
        if let leftId = configuration.leftPortfolioId {
            return portfolios.filter { $0.id != leftId }
        }
        return portfolios
    }

    // MARK: - Initialization

    init(portfolioService: PortfolioServiceProtocol? = nil) {
        self.portfolioService = portfolioService ?? ServiceContainer.shared.portfolioService
    }

    // MARK: - Load Data

    func loadPortfolios(userId: UUID) async {
        self.currentUserId = userId
        isLoading = true
        error = nil

        do {
            portfolios = try await portfolioService.fetchPortfolios(userId: userId)
            logInfo("Loaded \(portfolios.count) portfolios for showcase", category: .data)
        } catch {
            self.error = AppError.from(error)
            logError("Failed to load portfolios: \(error)", category: .data)
        }

        isLoading = false
    }

    // MARK: - Portfolio Selection

    func selectLeftPortfolio(_ portfolio: Portfolio) async {
        configuration.leftPortfolioId = portfolio.id
        await generateSnapshot(for: portfolio, position: .left)
    }

    func selectRightPortfolio(_ portfolio: Portfolio) async {
        configuration.rightPortfolioId = portfolio.id
        await generateSnapshot(for: portfolio, position: .right)
    }

    func clearLeftPortfolio() {
        configuration.leftPortfolioId = nil
        leftSnapshot = nil
    }

    func clearRightPortfolio() {
        configuration.rightPortfolioId = nil
        rightSnapshot = nil
    }

    func swapPortfolios() {
        let tempLeft = leftSnapshot
        let tempLeftId = configuration.leftPortfolioId

        leftSnapshot = rightSnapshot
        configuration.leftPortfolioId = configuration.rightPortfolioId

        rightSnapshot = tempLeft
        configuration.rightPortfolioId = tempLeftId
    }

    // MARK: - Snapshot Generation

    private enum Position { case left, right }

    private func generateSnapshot(for portfolio: Portfolio, position: Position) async {
        switch position {
        case .left: isLoadingLeft = true
        case .right: isLoadingRight = true
        }

        defer {
            switch position {
            case .left: isLoadingLeft = false
            case .right: isLoadingRight = false
            }
        }

        do {
            // Fetch holdings for this portfolio
            var holdings = try await portfolioService.fetchHoldings(portfolioId: portfolio.id)

            // Refresh prices
            holdings = try await portfolioService.refreshHoldingPrices(holdings: holdings)

            // Create snapshot with current privacy level
            let snapshot = PortfolioSnapshot(
                from: portfolio,
                holdings: holdings,
                privacyLevel: configuration.privacyLevel
            )

            switch position {
            case .left:
                self.leftSnapshot = snapshot
            case .right:
                self.rightSnapshot = snapshot
            }

            logInfo("Generated \(position) snapshot for portfolio \(portfolio.name)", category: .data)
        } catch {
            self.error = AppError.from(error)
            logError("Failed to generate snapshot: \(error)", category: .data)
        }
    }

    /// Regenerate snapshots when privacy level changes
    private func regenerateSnapshots() {
        // Re-generate snapshots with new privacy level if we have the source portfolios
        Task {
            if let leftId = configuration.leftPortfolioId,
               let leftPortfolio = portfolios.first(where: { $0.id == leftId }) {
                await generateSnapshot(for: leftPortfolio, position: .left)
            }

            if let rightId = configuration.rightPortfolioId,
               let rightPortfolio = portfolios.first(where: { $0.id == rightId }) {
                await generateSnapshot(for: rightPortfolio, position: .right)
            }
        }
    }

    // MARK: - Export

    func createBroadcastAttachment(caption: String? = nil) -> BroadcastPortfolioAttachment {
        BroadcastPortfolioAttachment(
            leftSnapshot: leftSnapshot,
            rightSnapshot: rightSnapshot,
            privacyLevel: configuration.privacyLevel,
            caption: caption
        )
    }
}
