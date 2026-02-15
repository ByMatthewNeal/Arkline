import Foundation

// MARK: - Confidence Metrics (Persisted per-asset)

struct ConfidenceMetrics: Codable {
    let assetId: String
    var rSquaredHistory: [RSquaredSnapshot]
    var dataPointCounts: [DataPointSnapshot]
    var predictionSnapshots: [PredictionSnapshot]
    var lastUpdated: Date

    struct RSquaredSnapshot: Codable {
        let date: Date
        let rSquared: Double
        let dataPointCount: Int
    }

    struct DataPointSnapshot: Codable {
        let date: Date
        let count: Int
    }

    struct PredictionSnapshot: Codable, Identifiable {
        var id: String { "\(assetId)_\(Int(snapshotDate.timeIntervalSince1970))" }
        let assetId: String
        let snapshotDate: Date
        let riskLevel: Double
        let riskCategory: String
        let priceAtSnapshot: Double

        // Filled in during validation
        var priceAt30Days: Double?
        var priceAt60Days: Double?
        var priceAt90Days: Double?
        var validatedAt: Date?
        var isCorrect30Day: Bool?
        var isCorrect60Day: Bool?
        var isCorrect90Day: Bool?
    }
}

// MARK: - Adaptive Confidence Result

struct AdaptiveConfidenceResult {
    let assetId: String
    let staticConfidence: Int
    let adaptiveConfidence: Int
    let rSquared: Double?
    let dataPointCount: Int
    let predictionAccuracy: Double?
    let validatedPredictionCount: Int
    let totalPredictionCount: Int
    let rSquaredBonus: Double
    let dataPointBonus: Double
    let accuracyBonus: Double
    let lastUpdated: Date
}

// MARK: - Confidence Tracker Actor

/// Tracks regression quality and prediction accuracy to compute adaptive confidence levels.
/// Persists metrics to disk so confidence grows across app launches.
actor ConfidenceTracker {
    static let shared = ConfidenceTracker()

    // MARK: - Storage

    private var metricsCache: [String: ConfidenceMetrics] = [:]

    private static let maxRSquaredHistory = 180
    private static let maxPredictionSnapshots = 365

    // MARK: - Init

    init(loadFromDisk: Bool = true) {
        guard loadFromDisk else { return }
        // Load persisted metrics for all known assets on init
        for config in AssetRiskConfig.allConfigs {
            if let loaded = Self.loadFromDisk(assetId: config.assetId) {
                metricsCache[config.assetId] = loaded
            }
        }
    }

    // MARK: - Record Calculation

    /// Record a risk calculation result for adaptive confidence tracking.
    func recordCalculation(
        assetId: String,
        rSquared: Double,
        dataPointCount: Int,
        riskLevel: Double,
        price: Double,
        date: Date = Date()
    ) {
        var metrics = metricsCache[assetId] ?? ConfidenceMetrics(
            assetId: assetId,
            rSquaredHistory: [],
            dataPointCounts: [],
            predictionSnapshots: [],
            lastUpdated: date
        )

        // Record R² snapshot
        metrics.rSquaredHistory.append(
            .init(date: date, rSquared: rSquared, dataPointCount: dataPointCount)
        )
        if metrics.rSquaredHistory.count > Self.maxRSquaredHistory {
            metrics.rSquaredHistory = Array(metrics.rSquaredHistory.suffix(Self.maxRSquaredHistory))
        }

        // Record data point count
        metrics.dataPointCounts.append(.init(date: date, count: dataPointCount))
        if metrics.dataPointCounts.count > Self.maxRSquaredHistory {
            metrics.dataPointCounts = Array(metrics.dataPointCounts.suffix(Self.maxRSquaredHistory))
        }

        // Create prediction snapshot (max 1/day, skip neutral zone)
        let isDirectional = riskLevel < 0.45 || riskLevel > 0.55
        let alreadySnapshotToday = metrics.predictionSnapshots.contains {
            Calendar.current.isDate($0.snapshotDate, inSameDayAs: date)
        }

        if isDirectional && !alreadySnapshotToday {
            metrics.predictionSnapshots.append(
                .init(
                    assetId: assetId,
                    snapshotDate: date,
                    riskLevel: riskLevel,
                    riskCategory: RiskHistoryPoint.category(for: riskLevel),
                    priceAtSnapshot: price
                )
            )
            if metrics.predictionSnapshots.count > Self.maxPredictionSnapshots {
                metrics.predictionSnapshots = Array(
                    metrics.predictionSnapshots.suffix(Self.maxPredictionSnapshots)
                )
            }
        }

        // Validate pending predictions with current price
        validatePendingPredictions(metrics: &metrics, currentPrice: price, currentDate: date)

        metrics.lastUpdated = date
        metricsCache[assetId] = metrics
        saveToDisk(metrics)
    }

    // MARK: - Compute Adaptive Confidence

    func computeAdaptiveConfidence(for assetId: String) -> AdaptiveConfidenceResult {
        let config = AssetRiskConfig.forCoin(assetId)
        let staticConf = config?.confidenceLevel ?? 5
        let metrics = metricsCache[assetId]

        guard let metrics = metrics else {
            return AdaptiveConfidenceResult(
                assetId: assetId,
                staticConfidence: staticConf,
                adaptiveConfidence: staticConf,
                rSquared: nil,
                dataPointCount: 0,
                predictionAccuracy: nil,
                validatedPredictionCount: 0,
                totalPredictionCount: 0,
                rSquaredBonus: 0,
                dataPointBonus: 0,
                accuracyBonus: 0,
                lastUpdated: Date()
            )
        }

        let base = Double(staticConf)

        // R² bonus: (R² - 0.85) * 5.0, clamped to [-0.5, +1.0]
        let latestRSquared = metrics.rSquaredHistory.last?.rSquared
        let rSquaredBonus: Double
        if let r2 = latestRSquared {
            rSquaredBonus = max(-0.5, min(1.0, (r2 - 0.85) * 5.0))
        } else {
            rSquaredBonus = 0.0
        }

        // Data point bonus: min(1.0, log2(points/365) / 4.0)
        let dataPointCount = metrics.dataPointCounts.last?.count ?? 0
        let dataPointBonus: Double
        if dataPointCount > 365 {
            dataPointBonus = min(1.0, log2(Double(dataPointCount) / 365.0) / 4.0)
        } else {
            dataPointBonus = 0.0
        }

        // Accuracy bonus: (accuracy - 0.5) * 2.0, requires 5+ validated predictions
        let validated = metrics.predictionSnapshots.filter { $0.isCorrect30Day != nil }
        let validatedCount = validated.count
        let accuracyBonus: Double
        let accuracy: Double?
        if validatedCount >= 5 {
            let correctCount = validated.filter { $0.isCorrect30Day == true }.count
            let rate = Double(correctCount) / Double(validatedCount)
            accuracy = rate
            accuracyBonus = max(-1.0, min(1.0, (rate - 0.5) * 2.0))
        } else {
            accuracy = nil
            accuracyBonus = 0.0
        }

        // Final: clamp to [base-1, 9]
        let rawAdaptive = base + rSquaredBonus + dataPointBonus + accuracyBonus
        let floor = Double(max(1, staticConf - 1))
        let adaptive = Int(max(floor, min(9.0, rawAdaptive)).rounded())

        return AdaptiveConfidenceResult(
            assetId: assetId,
            staticConfidence: staticConf,
            adaptiveConfidence: adaptive,
            rSquared: latestRSquared,
            dataPointCount: dataPointCount,
            predictionAccuracy: accuracy,
            validatedPredictionCount: validatedCount,
            totalPredictionCount: metrics.predictionSnapshots.count,
            rSquaredBonus: rSquaredBonus,
            dataPointBonus: dataPointBonus,
            accuracyBonus: accuracyBonus,
            lastUpdated: metrics.lastUpdated
        )
    }

    // MARK: - Get Metrics (for testing/debugging)

    func metrics(for assetId: String) -> ConfidenceMetrics? {
        metricsCache[assetId]
    }

    // MARK: - Prediction Validation

    private func validatePendingPredictions(
        metrics: inout ConfidenceMetrics,
        currentPrice: Double,
        currentDate: Date
    ) {
        for i in metrics.predictionSnapshots.indices {
            let snapshot = metrics.predictionSnapshots[i]

            // Skip already fully validated
            if snapshot.isCorrect90Day != nil { continue }

            let daysSince = Calendar.current.dateComponents(
                [.day], from: snapshot.snapshotDate, to: currentDate
            ).day ?? 0

            if daysSince >= 30 && snapshot.priceAt30Days == nil {
                metrics.predictionSnapshots[i].priceAt30Days = currentPrice
                metrics.predictionSnapshots[i].isCorrect30Day = Self.evaluatePrediction(
                    riskLevel: snapshot.riskLevel,
                    snapshotPrice: snapshot.priceAtSnapshot,
                    outcomePrice: currentPrice
                )
            }

            if daysSince >= 60 && snapshot.priceAt60Days == nil {
                metrics.predictionSnapshots[i].priceAt60Days = currentPrice
                metrics.predictionSnapshots[i].isCorrect60Day = Self.evaluatePrediction(
                    riskLevel: snapshot.riskLevel,
                    snapshotPrice: snapshot.priceAtSnapshot,
                    outcomePrice: currentPrice
                )
            }

            if daysSince >= 90 && snapshot.priceAt90Days == nil {
                metrics.predictionSnapshots[i].priceAt90Days = currentPrice
                metrics.predictionSnapshots[i].isCorrect90Day = Self.evaluatePrediction(
                    riskLevel: snapshot.riskLevel,
                    snapshotPrice: snapshot.priceAtSnapshot,
                    outcomePrice: currentPrice
                )
                metrics.predictionSnapshots[i].validatedAt = currentDate
            }
        }
    }

    /// Evaluate whether a prediction was correct.
    /// High risk (>= 0.55) is correct if price dropped >= 5%.
    /// Low risk (< 0.45) is correct if price rose >= 5%.
    static func evaluatePrediction(
        riskLevel: Double,
        snapshotPrice: Double,
        outcomePrice: Double
    ) -> Bool {
        let priceChange = (outcomePrice - snapshotPrice) / snapshotPrice

        if riskLevel >= 0.55 {
            return priceChange <= -0.05
        } else if riskLevel < 0.45 {
            return priceChange >= 0.05
        }
        return false
    }

    // MARK: - Disk Persistence

    private static var cacheDirectory: URL {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachePath.appendingPathComponent("ConfidenceMetrics", isDirectory: true)
    }

    private static func fileURL(for assetId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(assetId.uppercased())_confidence.json")
    }

    private func saveToDisk(_ metrics: ConfidenceMetrics) {
        let dir = Self.cacheDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = Self.fileURL(for: metrics.assetId)
        do {
            let data = try JSONEncoder().encode(metrics)
            try data.write(to: url, options: .atomic)
        } catch {
            logDebug("ConfidenceTracker: Failed to save \(metrics.assetId): \(error)", category: .data)
        }
    }

    private nonisolated static func loadFromDisk(assetId: String) -> ConfidenceMetrics? {
        let url = fileURL(for: assetId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ConfidenceMetrics.self, from: data)
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }
}
