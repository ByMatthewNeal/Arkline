import Foundation

// MARK: - AppState + Preferences Sync
/// Mirrors the user's dashboard layout + settings to their profile so the setup
/// survives reinstalls and stays in sync across devices. Strategy: push on
/// background, restore on launch/foreground, last-write-wins by timestamp.
extension AppState {

    private var prefsSyncedAtKey: String { "arkline_prefs_synced_at" }
    private var prefsLastUploadedKey: String { "arkline_prefs_last_uploaded" }
    private var enabledCoreAssetsKey: String { "enabledCoreAssets" }

    private static let prefsEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys] // stable bytes for change detection
        return e
    }()

    // MARK: Snapshot / Apply

    /// Capture the current in-memory preferences into a syncable bundle.
    @MainActor
    func snapshotPreferences() -> SyncedPreferences {
        SyncedPreferences(
            darkModePreference: darkModePreference.rawValue,
            avatarColorTheme: avatarColorTheme.rawValue,
            chartColorPalette: chartColorPalette.rawValue,
            preferredCurrency: preferredCurrency,
            widgetConfiguration: widgetConfiguration,
            marketWidgetConfiguration: marketWidgetConfiguration,
            // Sorted for stable, deterministic encoding (avoids spurious uploads).
            enabledCoreAssets: Array(enabledCoreAssets).sorted { $0.rawValue < $1.rawValue },
            dashboardPresets: dashboardPresets,
            activePresetId: activePresetId?.uuidString,
            tickerPreferences: tickerPreferences
        )
    }

    /// Apply a cloud bundle to the live app + local storage.
    @MainActor
    func applyPreferences(_ p: SyncedPreferences) {
        if let v = p.darkModePreference, let pref = Constants.DarkModePreference(rawValue: v) {
            setDarkModePreference(pref)
        }
        if let v = p.avatarColorTheme, let theme = Constants.AvatarColorTheme(rawValue: v) {
            setAvatarColorTheme(theme)
        }
        if let v = p.chartColorPalette, let palette = Constants.ChartColorPalette(rawValue: v) {
            setChartColorPalette(palette)
        }
        if let v = p.preferredCurrency {
            setPreferredCurrency(v)
        }
        if let w = p.widgetConfiguration {
            setWidgetConfiguration(w)
        }
        if let m = p.marketWidgetConfiguration {
            setMarketWidgetConfiguration(m)
        }
        if let assets = p.enabledCoreAssets {
            let set = assets.isEmpty ? CoreAsset.defaultEnabled : Set(assets)
            enabledCoreAssets = set
            if let data = try? JSONEncoder().encode(set) {
                UserDefaults.standard.set(data, forKey: enabledCoreAssetsKey)
            }
        }
        if let presets = p.dashboardPresets {
            dashboardPresets = presets
            if let data = try? JSONEncoder().encode(presets) {
                UserDefaults.standard.set(data, forKey: Constants.UserDefaults.dashboardPresets)
            }
        }
        // Apply the active preset AFTER the widget config so it isn't overridden.
        if let idStr = p.activePresetId, let id = UUID(uuidString: idStr) {
            activePresetId = id
            UserDefaults.standard.set(idStr, forKey: Constants.UserDefaults.activePresetId)
        }
        if let ticker = p.tickerPreferences {
            setTickerPreferences(ticker)
        }
    }

    // MARK: Restore (pull) / Upload (push)

    /// Pull cloud preferences and apply them if newer than what's on this device.
    /// Called on launch, on foreground, and right after sign-in.
    func restorePreferencesFromCloud() async {
        guard isAuthenticated, let userId = currentUser?.id else { return }
        do {
            guard let remote = try await PreferencesSyncService.shared.fetch(userId: userId) else {
                // Nothing in the cloud yet — seed it from this device.
                await uploadPreferences(force: true)
                return
            }
            let localSyncedAt = UserDefaults.standard.object(forKey: prefsSyncedAtKey) as? Date ?? .distantPast
            if remote.updatedAt > localSyncedAt {
                await MainActor.run { applyPreferences(remote.prefs) }
                UserDefaults.standard.set(remote.updatedAt, forKey: prefsSyncedAtKey)
                await markUploaded(remote.prefs) // so the next background push is a no-op
            } else {
                // This device is newer (or equal) — make sure the cloud reflects it.
                await uploadPreferences(force: false)
            }
        } catch {
            logError("Preference restore failed: \(error)", category: .data)
        }
    }

    /// Push the current preferences to the cloud. Skips when unchanged since the
    /// last successful upload (unless `force`).
    func uploadPreferences(force: Bool) async {
        guard isAuthenticated, let userId = currentUser?.id else { return }
        let snap = await MainActor.run { snapshotPreferences() }
        guard let data = try? Self.prefsEncoder.encode(snap) else { return }

        if !force,
           let last = UserDefaults.standard.data(forKey: prefsLastUploadedKey),
           last == data {
            return // nothing changed
        }

        let now = Date()
        do {
            try await PreferencesSyncService.shared.upload(snap, updatedAt: now, userId: userId)
            UserDefaults.standard.set(now, forKey: prefsSyncedAtKey)
            UserDefaults.standard.set(data, forKey: prefsLastUploadedKey)
        } catch {
            logError("Preference upload failed: \(error)", category: .data)
        }
    }

    /// Record a bundle as the last-uploaded snapshot so a follow-up push is a no-op.
    private func markUploaded(_ prefs: SyncedPreferences) async {
        if let data = try? Self.prefsEncoder.encode(prefs) {
            UserDefaults.standard.set(data, forKey: prefsLastUploadedKey)
        }
    }
}
