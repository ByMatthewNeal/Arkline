import Foundation

/// Pre-fetches critical market data during the splash screen so the home
/// screen gets instant L1 cache hits instead of waiting for network calls.
///
/// All fetches use the same service → SharedCacheService → APICache path,
/// so results are available to any ViewModel immediately.
enum DataPrefetcher {

    private static var prefetchTask: Task<Void, Never>?

    /// Start pre-fetching in the background. Safe to call multiple times;
    /// subsequent calls are no-ops while a fetch is in flight.
    static func start() {
        guard prefetchTask == nil else { return }

        prefetchTask = Task {
            let container = ServiceContainer.shared

            // Launch the heaviest / most-visible fetches in parallel
            async let crypto: Void = {
                _ = try? await container.marketService.fetchCryptoAssets(page: 1, perPage: 100)
            }()
            async let vix: Void = {
                _ = try? await container.vixService.fetchLatestVIX()
            }()
            async let dxy: Void = {
                _ = try? await container.dxyService.fetchLatestDXY()
            }()
            async let netLiq: Void = {
                _ = try? await container.globalLiquidityService.fetchNetLiquidityChanges()
            }()

            _ = await (crypto, vix, dxy, netLiq)
            logDebug("DataPrefetcher: critical data warmed", category: .network)
        }
    }
}
