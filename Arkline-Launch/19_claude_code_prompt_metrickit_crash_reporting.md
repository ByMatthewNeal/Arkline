# Claude Code Prompt — Add MetricKit Crash Reporting

Copy everything below the `---` line and paste into Claude Code as a single prompt. This wires up Apple's built-in MetricKit framework to capture crash, hang, and CPU-exception diagnostics from real users and store them in a Supabase table for analysis. No third-party SDK, no privacy disclosure additions, no user permission prompt.

---

# Task

Add MetricKit-based crash reporting to ArkLine. Apple's MetricKit framework aggregates crash, hang, and disk-write-exception diagnostics from users in TestFlight and the App Store, then delivers the payloads to the app on its next launch. By subscribing, we receive copies of these diagnostics and can persist them centrally for analysis.

Right now: zero visibility into crashes that testers (or production users) experience. Apple shows crashes in App Store Connect's built-in crash reporting, but that's surface-level and ID'd by symbolicated stack only. MetricKit gives us the full payload (call stacks, signal types, exception codes, device + OS + app version) and lets us correlate with `user_id` for richer debugging.

Scope is **crash diagnostics only** for v1 — performance metrics (CPU, memory, hangs in steady state) are out of scope. The schema and service are designed to be extended later.

## Files involved

- **New file:** `ArkLine/Data/Services/Diagnostics/CrashReportingService.swift`
- **Modify:** `ArkLine/App/ArkLineApp.swift` — register the service on launch.
- **New migration:** `supabase/migrations/{TODAY_YYYYMMDDHHMMSS}_create_crash_reports.sql`
- **No changes to:** Privacy manifest, Info.plist, anything else.

## Existing infrastructure to use

- `SupabaseManager.shared.client` — for inserting into the new table.
- `SupabaseAuthManager.shared.currentUserId` — for the optional `user_id` foreign key (nil for pre-auth crashes; that's fine).
- `logInfo` / `logError` from the existing logger utility — for local debug-build observability.
- `Bundle.main.infoDictionary` — for app version + build number on the payload.

## Implementation

### 1. Supabase migration

Create `supabase/migrations/{TODAY_YYYYMMDDHHMMSS}_create_crash_reports.sql`:

```sql
-- MetricKit crash diagnostics from real users
-- Captures crashes, hangs, and CPU/disk exceptions delivered by Apple MetricKit
create table public.crash_reports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete set null,
    app_version text,
    build_number text,
    os_version text,
    device_model text,
    diagnostic_type text,  -- 'crash' | 'hang' | 'cpu' | 'disk' | 'unknown'
    payload jsonb not null,
    received_at timestamptz default now() not null
);

-- Indexes for the queries we'll actually run
create index idx_crash_reports_received_at on public.crash_reports (received_at desc);
create index idx_crash_reports_diagnostic_type on public.crash_reports (diagnostic_type);
create index idx_crash_reports_app_version on public.crash_reports (app_version);
create index idx_crash_reports_user_id on public.crash_reports (user_id) where user_id is not null;

-- RLS: authenticated users can insert their own reports; admins can read all
alter table public.crash_reports enable row level security;

create policy "Authenticated users can insert their own crash reports"
on public.crash_reports for insert
to authenticated
with check (user_id = auth.uid() or user_id is null);

create policy "Admins can read all crash reports"
on public.crash_reports for select
to authenticated
using (
    exists (
        select 1 from public.profiles
        where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
);

-- Nobody can update or delete (immutable audit log)
create policy "No updates allowed"
on public.crash_reports for update
to authenticated
using (false);

create policy "No deletes allowed"
on public.crash_reports for delete
to authenticated
using (false);
```

Do NOT run `supabase db push` — Matt will deploy manually after review.

### 2. `CrashReportingService.swift`

Create at `ArkLine/Data/Services/Diagnostics/CrashReportingService.swift`:

```swift
import Foundation
import MetricKit

/// Subscribes to Apple's MetricKit and forwards crash/hang/CPU/disk
/// diagnostic payloads to Supabase for centralized analysis.
///
/// Apple delivers payloads on the *next* app launch after the
/// diagnostic event — there's no real-time hook. Payloads are
/// pre-aggregated (typically once per 24h period).
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
        // Iterate each diagnostic in the payload separately so we can
        // tag rows by type for easier filtering in Supabase
        let allDiagnostics: [MXDiagnostic] =
            (payload.crashDiagnostics ?? []) +
            (payload.hangDiagnostics ?? []) +
            (payload.cpuExceptionDiagnostics ?? []) +
            (payload.diskWriteExceptionDiagnostics ?? [])

        if allDiagnostics.isEmpty {
            // Empty payload (Apple sometimes ships these); skip
            return
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let osVersion = await MainActor.run { UIDevice.current.systemVersion }
        let deviceModel = await MainActor.run { UIDevice.current.model }
        let userId = await MainActor.run { SupabaseAuthManager.shared.currentUserId }

        for diagnostic in allDiagnostics {
            let json = diagnostic.jsonRepresentation()
            guard let jsonObject = try? JSONSerialization.jsonObject(with: json) else {
                logError("MetricKit: failed to parse diagnostic JSON", category: .data)
                continue
            }

            let record: [String: Any] = [
                "user_id": userId?.uuidString as Any,
                "app_version": appVersion as Any,
                "build_number": buildNumber as Any,
                "os_version": osVersion,
                "device_model": deviceModel,
                "diagnostic_type": diagnosticType(for: diagnostic),
                "payload": jsonObject
            ]

            do {
                try await SupabaseManager.shared.client
                    .from("crash_reports")
                    .insert(record)
                    .execute()
                logInfo("MetricKit: uploaded \(diagnosticType(for: diagnostic)) diagnostic", category: .data)
            } catch {
                // Best-effort. Don't retry — Apple may redeliver on next launch
                // if delivery confirmation fails, and infinite retries would
                // hammer Supabase if something is systemically broken.
                logError("MetricKit: failed to upload diagnostic: \(error.localizedDescription)", category: .data)
            }
        }

        #if DEBUG
        logInfo("MetricKit: processed \(allDiagnostics.count) diagnostics", category: .data)
        #endif
    }
}

// MARK: - MXMetricManagerSubscriber

extension CrashReportingService: MXMetricManagerSubscriber {
    /// Performance metrics. Out of scope for v1 — no-op.
    func didReceive(_ payloads: [MXMetricPayload]) {
        // Future: ship CPU/memory/hang metrics for performance regressions.
    }

    /// Crash + hang + CPU + disk-write diagnostics.
    /// This is the entry point for the audit's crash reporting goal.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            Task.detached { [weak self] in
                await self?.upload(payload: payload)
            }
        }
    }
}
```

Note the SDK detail: `SupabaseManager.shared.client.from(...).insert(...).execute()` — verify this matches the actual Supabase Swift SDK version in use. If the project uses a different invocation pattern (e.g., `.upsert`, custom RPC, or an older API), adapt accordingly. If you're unsure, grep the codebase for an existing example like `client.from("profiles").insert(...)` and copy the pattern.

### 3. Register on app launch

In `ArkLine/App/ArkLineApp.swift`, find the `.onAppear` block (around line 26) inside the main `WindowGroup` body — currently it calls `setupAppearance()`, `setupNotifications()`, `migrateNotificationKeys()`, and the `Task { ... }` block. Add one line:

```swift
.onAppear {
    setupAppearance()
    setupNotifications()
    migrateNotificationKeys()
    CrashReportingService.shared.register()   // NEW
    Task {
        await appState.refreshUserProfile()
        // ...
    }
}
```

Registration is idempotent (safe to call multiple times). MetricKit will deliver any pending payloads from past launches on the next launch after registration.

## Out of scope (do NOT do)

- Do NOT add performance metrics (`MXMetricPayload`) handling. Future work.
- Do NOT add an admin "Crash Reports" view in-app. For v1, querying the table directly via Supabase Studio is sufficient.
- Do NOT add user prompts for "Send crash reports?" — MetricKit collection is Apple-built-in, no opt-in needed beyond Apple's own system-level diagnostic sharing setting (which users already control).
- Do NOT change `PrivacyInfo.xcprivacy`. The crash payload doesn't include personal data and Apple's framework handles privacy. Adding a `NSPrivacyCollectedDataType` entry for crash data is optional and not required for App Review — defer.
- Do NOT modify the Privacy Policy at this stage. A line about "we collect crash diagnostics to improve the app" can be added in a separate copy edit later.
- Do NOT add real-time crash reporting. MetricKit is post-hoc only (Apple aggregates and delivers on next launch). Real-time crash interception would require a different framework (e.g., PLCrashReporter), which is out of scope.

## Test plan

You can't easily trigger a real crash on the simulator to test MetricKit (Apple doesn't deliver synthetic crashes consistently). Instead, do these structural verifications:

1. **Build succeeds.** `import MetricKit` resolves; `MXMetricManager`, `MXDiagnosticPayload`, etc. are recognized.
2. **Registration runs once.** Add a temporary `print()` or breakpoint in `register()` and verify it's hit exactly once on app launch.
3. **Simulator log shows the "registered" message.** Look for "MetricKit crash reporting registered" in Console.app or Xcode output.
4. **Supabase RLS works.** As an authenticated non-admin user, run an `insert` from the SQL editor with a fake payload — should succeed. Run a `select` — should fail (or return 0 rows, depending on Supabase RLS error mode). As an admin, `select` should return all rows.
5. **Schema accepts a real payload.** Manually insert a row with a representative jsonb payload (you can paste a sample MXDiagnosticPayload JSON from Apple's docs) to confirm the schema doesn't reject it.

Real-world verification will happen organically: once you have testers on TestFlight, you'll start seeing rows appear in `crash_reports` over the following days.

## Reporting

When done:

1. Files created/modified with line ranges.
2. Confirmation that the build compiled cleanly with `import MetricKit`.
3. The exact Supabase Swift SDK invocation pattern you used (`.from(...).insert(...).execute()` or whatever matches the actual SDK version).
4. The migration filename you created.
5. The deploy command Matt should run (e.g., `supabase db push` or migration-up).
6. Any concerns about the RLS policy or schema.

Keep the report under 250 words.
