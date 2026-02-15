import Foundation

/// Persists daily altcoin price snapshots to enable progressive altcoin season calculation.
/// Uses whatever accumulated data is available (31d–90d), improving accuracy over time.
/// Follows the same disk persistence pattern as ConfidenceTracker.
actor AltcoinSeasonStore {
    static let shared = AltcoinSeasonStore()

    // MARK: - Constants

    private static let maxSnapshots = 120
    /// Minimum days of local data before we use it (CoinGecko already covers 30d).
    private static let minimumLocalDays = 31
    /// Maximum window we target.
    private static let targetWindow = 90

    // MARK: - State

    private var snapshotFile: AltcoinSeasonSnapshotFile

    // MARK: - Date Formatter

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Init

    init(loadFromDisk: Bool = true) {
        if loadFromDisk {
            self.snapshotFile = Self.loadFromDisk() ?? AltcoinSeasonSnapshotFile(snapshots: [], lastUpdated: .distantPast)
        } else {
            self.snapshotFile = AltcoinSeasonSnapshotFile(snapshots: [], lastUpdated: .distantPast)
        }
    }

    // MARK: - Record Snapshot

    /// Record a daily snapshot. Deduplicates by calendar date (UTC).
    func recordSnapshot(_ snapshot: AltcoinSeasonSnapshot) {
        guard !snapshotFile.snapshots.contains(where: { $0.date == snapshot.date }) else {
            return
        }

        snapshotFile.snapshots.append(snapshot)
        snapshotFile.snapshots.sort { $0.date < $1.date }

        if snapshotFile.snapshots.count > Self.maxSnapshots {
            snapshotFile.snapshots = Array(snapshotFile.snapshots.suffix(Self.maxSnapshots))
        }

        snapshotFile.lastUpdated = Date()
        saveToDisk()
    }

    // MARK: - Progressive Calculation

    /// The number of days spanned by stored snapshots, or nil if fewer than 2 snapshots.
    var availableWindowDays: Int? {
        guard snapshotFile.snapshots.count >= 2,
              let oldest = snapshotFile.snapshots.first,
              let newest = snapshotFile.snapshots.last,
              let oldestDate = Self.dateFormatter.date(from: oldest.date),
              let newestDate = Self.dateFormatter.date(from: newest.date) else {
            return nil
        }
        return Calendar.current.dateComponents([.day], from: oldestDate, to: newestDate).day
    }

    /// Compute altcoin season index using the best available window.
    /// Uses up to 90 days of local data. Returns nil if we have ≤30 days
    /// (CoinGecko 30d is equivalent, so local data adds no value until day 31+).
    func computeBestIndex() -> AltcoinSeasonIndex? {
        guard let daySpan = availableWindowDays,
              daySpan >= Self.minimumLocalDays,
              let today = snapshotFile.snapshots.last,
              let todayDate = Self.dateFormatter.date(from: today.date) else {
            return nil
        }

        // Use the full available span, capped at target window
        let windowDays = min(daySpan, Self.targetWindow)
        guard let targetDate = Calendar.current.date(byAdding: .day, value: -windowDays, to: todayDate) else {
            return nil
        }
        let targetDateStr = Self.dateFormatter.string(from: targetDate)

        guard let baseSnapshot = findClosestSnapshot(to: targetDateStr),
              baseSnapshot.btcPrice > 0 else {
            return nil
        }

        let basePrices: [String: Double] = Dictionary(
            baseSnapshot.coins.map { ($0.coinId, $0.price) },
            uniquingKeysWith: { first, _ in first }
        )

        let btcChange = (today.btcPrice - baseSnapshot.btcPrice) / baseSnapshot.btcPrice

        var outperformers = 0
        var totalAltcoins = 0

        for coin in today.coins {
            if coin.coinId == "bitcoin" { continue }
            guard let basePrice = basePrices[coin.coinId], basePrice > 0 else { continue }

            totalAltcoins += 1
            let coinChange = (coin.price - basePrice) / basePrice
            if coinChange > btcChange {
                outperformers += 1
            }
        }

        guard totalAltcoins > 0 else { return nil }

        let index = Int((Double(outperformers) / Double(totalAltcoins)) * 100)
        return AltcoinSeasonIndex(
            value: index,
            isBitcoinSeason: index < 50,
            timestamp: Date(),
            calculationWindow: windowDays
        )
    }

    // MARK: - Accessors

    var snapshotCount: Int {
        snapshotFile.snapshots.count
    }

    var dateRange: (oldest: String, newest: String)? {
        guard let first = snapshotFile.snapshots.first,
              let last = snapshotFile.snapshots.last else { return nil }
        return (first.date, last.date)
    }

    // MARK: - Private Helpers

    private func findClosestSnapshot(to targetDate: String) -> AltcoinSeasonSnapshot? {
        if let exact = snapshotFile.snapshots.first(where: { $0.date == targetDate }) {
            return exact
        }
        return snapshotFile.snapshots.last(where: { $0.date <= targetDate })
    }

    // MARK: - Disk Persistence

    private static var cacheDirectory: URL {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachePath.appendingPathComponent("AltcoinSeason", isDirectory: true)
    }

    private static var fileURL: URL {
        cacheDirectory.appendingPathComponent("daily_snapshots.json")
    }

    private func saveToDisk() {
        let dir = Self.cacheDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        do {
            let data = try JSONEncoder().encode(snapshotFile)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            logDebug("AltcoinSeasonStore: Failed to save snapshots: \(error)", category: .data)
        }
    }

    private nonisolated static func loadFromDisk() -> AltcoinSeasonSnapshotFile? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AltcoinSeasonSnapshotFile.self, from: data)
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }
}
