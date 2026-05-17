import Foundation
import MetricKit
#if canImport(UIKit)
import UIKit
#endif

/// Subscribes to Apple's MetricKit and forwards crash/hang/CPU/disk
/// diagnostic payloads to Supabase for centralized analysis.
///
/// Apple delivers payloads on the *next* app launch after the
/// diagnostic event — there's no real-time hook.
final class CrashReportingService: NSObject {
    static let shared = CrashReportingService()

    private override init() { super.init() }

    /// Register as a MetricKit subscriber. Call once on app launch.
    func register() {
        MXMetricManager.shared.add(self)
        logInfo("MetricKit crash reporting registered", category: .data)
    }

    private func diagnosticType(for diagnostic: MXDiagnostic) -> String {
        switch diagnostic {
        case is MXCrashDiagnostic: return "crash"
        case is MXHangDiagnostic: return "hang"
        case is MXCPUExceptionDiagnostic: return "cpu"
        case is MXDiskWriteExceptionDiagnostic: return "disk"
        default: return "unknown"
        }
    }

    private func upload(payload: MXDiagnosticPayload) async {
        var allDiagnostics: [MXDiagnostic] = []
        allDiagnostics.append(contentsOf: payload.crashDiagnostics ?? [])
        allDiagnostics.append(contentsOf: payload.hangDiagnostics ?? [])
        allDiagnostics.append(contentsOf: payload.cpuExceptionDiagnostics ?? [])
        allDiagnostics.append(contentsOf: payload.diskWriteExceptionDiagnostics ?? [])

        guard !allDiagnostics.isEmpty else { return }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let userId = await MainActor.run { SupabaseAuthManager.shared.currentUserId }

        #if canImport(UIKit)
        let osVersion = await MainActor.run { UIDevice.current.systemVersion }
        let deviceModel = await MainActor.run { UIDevice.current.model }
        #else
        let osVersion: String? = nil
        let deviceModel: String? = nil
        #endif

        for diagnostic in allDiagnostics {
            let jsonData = diagnostic.jsonRepresentation()
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                logError("MetricKit: failed to encode diagnostic JSON", category: .data)
                continue
            }

            let record = CrashReportDTO(
                userId: userId?.uuidString,
                appVersion: appVersion,
                buildNumber: buildNumber,
                osVersion: osVersion,
                deviceModel: deviceModel,
                diagnosticType: diagnosticType(for: diagnostic),
                payload: jsonString
            )

            do {
                try await SupabaseManager.shared.client
                    .from("crash_reports")
                    .insert(record)
                    .execute()
                logInfo("MetricKit: uploaded \(diagnosticType(for: diagnostic)) diagnostic", category: .data)
            } catch {
                logError("MetricKit: failed to upload diagnostic: \(error.localizedDescription)", category: .data)
            }
        }
    }
}

// MARK: - MXMetricManagerSubscriber

extension CrashReportingService: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // Future: performance metrics
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            Task.detached { [weak self] in
                await self?.upload(payload: payload)
            }
        }
    }
}

// MARK: - DTO

private struct CrashReportDTO: Encodable {
    let userId: String?
    let appVersion: String?
    let buildNumber: String?
    let osVersion: String?
    let deviceModel: String?
    let diagnosticType: String
    let payload: String  // Raw JSON string — Supabase casts to jsonb

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case diagnosticType = "diagnostic_type"
        case payload
    }
}
