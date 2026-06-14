# Claude Code Prompt — Gate Direct API Key Fallback to DEBUG Builds Only

Copy everything below the `---` line and paste into Claude Code as a single prompt. This is a small security hardening fix from the pre-ship audit.

---

# Task

In `ArkLine/Data/Network/APIProxy.swift`, the direct-HTTP fallback path (which injects API keys for FRED, Metals, TAAPI, FMP, etc. as URL query params or headers) currently runs in **all build configurations**. This means release builds (TestFlight and App Store) carry the fallback wired up — and if the Supabase Edge Function proxy fails for any reason, the app falls back to direct calls that expose API keys.

The proxy is supposed to be the only path that uses API keys in production. The direct fallback is a developer-convenience feature so debug builds work without dependence on a deployed proxy.

Gate the fallback to `#if DEBUG` so:
- **Debug builds** (running locally in Xcode): fallback works as today — direct API calls with local keys for fast iteration.
- **Release builds** (TestFlight + App Store): proxy is the only path. If proxy fails, the request throws a clean error — no key-leaking fallback ever runs.

## Files involved

- **Modify:** `ArkLine/Data/Network/APIProxy.swift` — the only file.
- **No changes to:** `Constants.swift`, `Secrets.plist`, `Info.plist`, any caller of `APIProxy.shared.request(...)`.

## Implementation

There are two call sites for the fallback inside `APIProxy.swift`:

1. **`request(service:path:method:queryItems:)`** around lines 160–174 (GET).
2. **`request<Body: Encodable>(service:path:queryItems:body:)`** around lines 177–197 (POST).

Both end with:

```swift
// Fallback: direct HTTP with local API key
return try await directGetRequest(...)
```

or

```swift
return try await directPostRequest(...)
```

Wrap each fallback call in `#if DEBUG` like this:

### GET path (around line 173)

Current:

```swift
// Fallback: direct HTTP with local API key
return try await directGetRequest(service: service, path: path, method: method, queryItems: queryItems)
```

Replace with:

```swift
// Fallback: direct HTTP with local API key (DEBUG only — release builds
// route exclusively through the Supabase Edge Function proxy)
#if DEBUG
return try await directGetRequest(service: service, path: path, method: method, queryItems: queryItems)
#else
throw APIProxyError.proxyUnavailable
#endif
```

### POST path (around line 196)

Current:

```swift
// Fallback: direct HTTP with local API key
return try await directPostRequest(service: service, path: path, queryItems: queryItems, body: body)
```

Replace with:

```swift
// Fallback: direct HTTP with local API key (DEBUG only — release builds
// route exclusively through the Supabase Edge Function proxy)
#if DEBUG
return try await directPostRequest(service: service, path: path, queryItems: queryItems, body: body)
#else
throw APIProxyError.proxyUnavailable
#endif
```

### Add the new error case

In the `APIProxyError` enum at the bottom of the file (around line 441):

```swift
enum APIProxyError: Error, LocalizedError {
    case notConfigured
    case unauthorized
    case httpError(statusCode: Int, data: Data)
    case relayError
    case proxyUnavailable    // NEW

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase not configured"
        case .unauthorized:
            return "Authentication required"
        case .httpError(let code, _):
            return "API proxy HTTP error: \(code)"
        case .relayError:
            return "Edge Function relay error"
        case .proxyUnavailable:    // NEW
            return "Service temporarily unavailable"
        }
    }
}
```

The error message is intentionally generic ("Service temporarily unavailable") because it surfaces to users. They don't need to know about proxies or keys; they just need to know the action failed.

### Keep the direct methods themselves untouched

`directGetRequest`, `directPostRequest`, `buildDirectRequest`, and `directConfig` should remain in the file unchanged. They're still called by DEBUG builds. Wrapping them in `#if DEBUG` would require dead-code stripping verification — easier to leave the methods compiled but unreachable in release, since the compiler eliminates the call sites and the methods become unused code that's typically dead-code-eliminated anyway.

## Verification

After making the changes:

1. **DEBUG build (Xcode simulator):** Run the app, trigger any feature that uses one of the proxied APIs (FRED, FMP, etc.). With proxy enabled it should work normally via proxy. If you temporarily kill the proxy (e.g., disconnect from the internet or break the auth session), the direct fallback should kick in and the feature should still work.

2. **RELEASE build (Archive → distribute):** Build for Release configuration. Open the resulting binary and confirm via `strings` or similar that the `directGetRequest` / `directPostRequest` code paths are either unreachable or eliminated. Easier verification: temporarily break the proxy (e.g., point Supabase to a non-existent function), build for Release, run on device — the proxied features should now throw `proxyUnavailable` and fail gracefully rather than fall through to direct HTTP.

3. **Compile both configurations** to catch any unused-import warnings or unreachable-code warnings the `#if DEBUG` gate introduces.

## Out of scope (do NOT do)

- Do not remove `Secrets.plist` or change how API keys are loaded into `Constants.API`. That's a deeper refactor for a separate task. Note for future: keys still exist in the release binary (extractable via `strings` or class-dump) — but with this change, they're never *transmitted* in release builds, which is what the audit flagged.
- Do not change the existing proxy logic (auth session check, circuit breaker, error mapping). The proxy primary path is correct as-is.
- Do not change the Binance Futures path. `binanceFutures` has `apiKey: nil` and uses no fallback key — it's a separate code path that doesn't leak anything.
- Do not modify any caller of `APIProxy.shared.request(...)`. They handle thrown errors generically; the new `.proxyUnavailable` case will surface through existing error handling.

## Reporting

Briefly:

1. Confirmation that lines 173, 196, and the `APIProxyError` enum were modified as spec'd.
2. Confirmation that DEBUG build still falls through to direct API calls.
3. Confirmation that a Release-configured build compiles cleanly (no unused-code or unreachable warnings).
4. Any callers that handle `APIProxyError.proxyUnavailable` specifically (likely none — generic error handling will catch it).
5. Build status.

Keep it under 150 words.
