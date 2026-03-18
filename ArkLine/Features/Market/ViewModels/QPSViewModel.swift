import Foundation

@MainActor
@Observable
class QPSViewModel {
    private let service = PositioningSignalService()

    var signals: [DailyPositioningSignal] = []
    var isLoading = false
    var errorMessage: String?

    /// Only signals where the positioning changed from yesterday
    var changedSignals: [DailyPositioningSignal] {
        signals.filter { $0.hasChanged }
    }

    var hasChanges: Bool {
        !changedSignals.isEmpty
    }

    func loadSignals(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            signals = try await service.fetchLatestSignals(forceRefresh: forceRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
