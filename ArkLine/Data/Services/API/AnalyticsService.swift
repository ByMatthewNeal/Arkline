import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Analytics Service

/// Batched user behavior analytics. Buffers events in memory and flushes
/// to Supabase periodically or when the buffer reaches a threshold.
actor AnalyticsService {
    // MARK: - Singleton
    static let shared = AnalyticsService()

    // MARK: - Consent
    private static let consentKey = "analyticsConsentGranted"

    /// Whether the user has granted analytics consent. Defaults to false.
    var isConsentGranted: Bool {
        UserDefaults.standard.bool(forKey: Self.consentKey)
    }

    /// Call from Settings or onboarding to update consent.
    func setConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: Self.consentKey)
        if !granted {
            buffer.removeAll()
        }
    }

    // MARK: - Configuration
    private let flushInterval: TimeInterval = 60
    private let flushThreshold = 10
    private let maxRetryBuffer = 100

    // MARK: - State
    private var buffer: [AnalyticsEventDTO] = []
    private let sessionId = UUID()
    private var deviceInfo: [String: AnyCodableValue]?
    private var screenViewCount = 0
    private var coinsViewed: Set<String> = []
    private var flushTask: Task<Void, Never>?
    private var currentDay: String = ""

    // MARK: - Init
    private init() {
        startPeriodicFlush()
    }

    // MARK: - Device Info

    private func getDeviceInfo() -> [String: AnyCodableValue] {
        if let cached = deviceInfo { return cached }

        var info: [String: AnyCodableValue] = [:]

        #if canImport(UIKit)
        let device = UIDevice.current
        info["model"] = .string(device.model)
        info["system_name"] = .string(device.systemName)
        info["system_version"] = .string(device.systemVersion)
        #endif

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info["app_version"] = .string(version)
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info["build_number"] = .string(build)
        }

        deviceInfo = info
        return info
    }

    private var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    private func getUserId() async -> UUID? {
        await MainActor.run { SupabaseAuthManager.shared.currentUserId }
    }

    // MARK: - Track Event

    /// Buffer an analytics event. Flushes automatically when threshold is reached.
    /// Respects user consent — no-ops if consent has not been granted.
    func track(_ eventName: String, properties: [String: AnyCodableValue]? = nil) async {
        guard isConsentGranted else { return }
        let userId = await getUserId()
        let event = AnalyticsEventDTO(
            userId: userId,
            eventName: eventName,
            properties: properties,
            sessionId: sessionId,
            deviceInfo: getDeviceInfo()
        )
        buffer.append(event)

        // Track screen views for DAU
        if eventName == "screen_view" {
            screenViewCount += 1
        }
        if eventName == "coin_tap" || eventName == "screen_view",
           let coin = properties?["coin"] {
            if case .string(let coinId) = coin {
                coinsViewed.insert(coinId)
            }
        }

        if buffer.count >= flushThreshold {
            Task { await flush() }
        }
    }

    // MARK: - Flush

    /// Sends buffered events to Supabase and updates DAU.
    func flush() async {
        guard SupabaseManager.shared.isConfigured else {
            buffer.removeAll()
            return
        }
        guard !buffer.isEmpty else { return }

        let eventsToSend = buffer
        buffer.removeAll()

        do {
            try await SupabaseManager.shared.client
                .from(SupabaseTable.analyticsEvents.rawValue)
                .insert(eventsToSend)
                .execute()
            logInfo("Flushed \(eventsToSend.count) analytics events", category: .network)
        } catch {
            logError("Failed to flush analytics: \(error.localizedDescription)", category: .network)
            // Re-queue failed events (capped)
            let requeue = eventsToSend.prefix(maxRetryBuffer - buffer.count)
            buffer.insert(contentsOf: requeue, at: 0)
        }

        // Update DAU
        await updateDAU()
    }

    // MARK: - DAU

    private func updateDAU() async {
        guard let userId = await getUserId() else { return }

        let today = todayString
        guard today != currentDay || screenViewCount > 0 else { return }
        currentDay = today

        let dto = DailyActiveUserDTO(
            userId: userId,
            date: today,
            sessionCount: 1,
            screenViews: screenViewCount,
            coinsViewed: Array(coinsViewed),
            appVersion: appVersion
        )

        do {
            try await SupabaseManager.shared.client
                .from(SupabaseTable.dailyActiveUsers.rawValue)
                .upsert([dto], onConflict: "recorded_date,user_id")
                .execute()
        } catch {
            logError("Failed to update DAU: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Periodic Flush

    private func startPeriodicFlush() {
        flushTask = Task { [weak self = self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000))
                await self?.flush()
            }
        }
    }
}

// MARK: - Convenience Helpers

extension AnalyticsService {
    /// Track a screen view
    func trackScreenView(_ screenName: String, coin: String? = nil) async {
        var props: [String: AnyCodableValue] = ["screen": .string(screenName)]
        if let coin = coin {
            props["coin"] = .string(coin)
        }
        await track("screen_view", properties: props)
    }

    /// Track a tab switch
    func trackTabSwitch(_ tabName: String) async {
        await track("tab_switch", properties: ["tab": .string(tabName)])
    }

    /// Track a coin tap
    func trackCoinTap(_ coinId: String, source: String) async {
        await track("coin_tap", properties: ["coin": .string(coinId), "source": .string(source)])
    }

    /// Track app open
    func trackAppOpen(source: String = "cold_start") async {
        await track("app_open", properties: ["source": .string(source)])
    }

    /// Track search
    func trackSearch(query: String, resultCount: Int) async {
        await track("search", properties: ["query": .string(query), "result_count": .int(resultCount)])
    }
}
