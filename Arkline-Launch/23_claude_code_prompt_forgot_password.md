# Claude Code Prompt — Forgot Password Feature (iOS + Web)

Copy everything below the `---` line and paste into Claude Code as a single prompt. Adds a self-service password recovery flow so users (including legacy OTP-only accounts) can reset their passwords without admin intervention.

---

# Task

Add a "Forgot password?" recovery flow that works across the two iOS surfaces that ask for password (the new `EmailPasswordSignInSheet` from the LoginView, and the onboarding `SignInView`), plus a new web page on arkline.io that handles the actual password reset.

The flow:
1. User taps "Forgot password?" link on an iOS sign-in surface.
2. App calls Supabase's `auth.resetPasswordForEmail(email, redirectTo: "https://arkline.io/reset-password")`.
3. App shows confirmation: "Check your email for a reset link."
4. User receives email with a one-time-use link.
5. User taps link on any device → opens `https://arkline.io/reset-password` in browser.
6. Web page reads the Supabase token from the URL hash, presents a "Set new password" form.
7. On submit, web page calls Supabase to update the password.
8. Web page shows success with a CTA to open ArkLine.
9. User signs in with new password.

This unblocks two known issues:
- Legacy users created via the OTP-only onboarding (before password sign-up was added) have no password and are currently locked out if their session clears.
- Future users who legitimately forget their password have no self-service recovery.

## Parts

- **Part A: iOS — `EmailPasswordSignInSheet`** — add "Forgot password?" link and reset confirmation state.
- **Part B: iOS — `SignInView` (onboarding)** — same link for consistency in the onboarding flow.
- **Part C: iOS — `AuthViewModel`** — add `sendPasswordReset(email:)` method.
- **Part D: iOS — `OnboardingViewModel`** — add the same method for SignInView's surface.
- **Part E: Web — `web/src/app/reset-password/page.tsx`** — new Next.js page that handles the actual password update.
- **Manual config (post-deploy):** Add `https://arkline.io/reset-password` to Supabase Auth allowed redirect URLs.

---

## Part A: `EmailPasswordSignInSheet.swift`

Add a small "Forgot password?" link below the Sign In button, with the same muted style as the existing `Cancel` button. Tap behavior:

1. Validate the email field is non-empty and looks like an email.
2. If valid → call `viewModel.sendPasswordReset(email: ...)`.
3. Show a `passwordResetSent` confirmation state in the sheet (replace the form with a success message: "Check your email. We sent a password reset link to [email]. The link expires in 1 hour.").
4. Show a "Done" button that dismisses the sheet.
5. If email is invalid → inline error: "Enter your email above first."

Layout sketch (below the existing Sign In button):

```swift
if !viewModel.passwordResetSent {
    Button {
        Task { await viewModel.sendPasswordReset(email: email) }
    } label: {
        Text("Forgot password?")
            .font(AppFonts.body14Medium)
            .foregroundColor(AppColors.accent)
    }
    .padding(.top, ArkSpacing.md)
}
```

When `viewModel.passwordResetSent == true`, replace the form area with:

```swift
VStack(spacing: ArkSpacing.lg) {
    Image(systemName: "envelope.badge")
        .font(.system(size: 40))
        .foregroundColor(AppColors.accent)
    Text("Check your email")
        .font(AppFonts.title30)
    Text("We sent a password reset link to \(email). The link expires in 1 hour.")
        .font(AppFonts.body14)
        .foregroundColor(AppColors.textSecondary)
        .multilineTextAlignment(.center)
    Button("Done") { dismiss() }
        .buttonStyle(.borderedProminent)
}
```

---

## Part B: `SignInView.swift` (onboarding)

Same affordance, same behavior. Add the "Forgot password?" link **below** the existing "Use email code instead" link so the user has three paths from this screen:

1. **Sign In** (primary action — enter password and sign in)
2. **Use email code instead** (existing — switch to OTP auth)
3. **Forgot password?** (new — send recovery email)

Layout: add it as a second secondary link, below the existing one, using the same styling. Call `viewModel.sendPasswordReset(email: viewModel.email)`.

When `viewModel.passwordResetSent == true`, replace the form section with the same confirmation card as in Part A.

---

## Part C: `AuthViewModel.swift`

Add the recovery method and supporting state:

```swift
var passwordResetSent: Bool = false
var passwordResetError: String?
var isPasswordResetLoading: Bool = false

@MainActor
func sendPasswordReset(email: String) async {
    guard !email.isEmpty, email.contains("@") else {
        passwordResetError = "Enter a valid email address."
        return
    }

    passwordResetError = nil
    isPasswordResetLoading = true
    defer { isPasswordResetLoading = false }

    do {
        try await SupabaseAuthManager.shared.resetPasswordForEmail(
            email: email,
            redirectTo: "https://arkline.io/reset-password"
        )
        passwordResetSent = true
        Haptics.success()
    } catch {
        passwordResetError = AppError.from(error).userMessage
        Haptics.error()
    }
}
```

Verify `SupabaseAuthManager.shared` has a `resetPasswordForEmail(email:redirectTo:)` method. If not, add it as a thin wrapper around the Supabase SDK's `auth.resetPasswordForEmail(email, options: AuthFlowOptions(redirectTo: URL(string: redirectTo)))`. Grep for the existing `signIn(email:password:)` method to find the canonical pattern.

---

## Part D: `OnboardingViewModel.swift`

Add the same method + state. Match the implementation in Part C exactly — different ViewModels but identical recovery logic.

---

## Part E: Web reset password page

New file: `web/src/app/reset-password/page.tsx`

This is a **client component** (must use `"use client"` at the top) because it needs to:
1. Read the Supabase tokens from the URL hash (only accessible in the browser).
2. Initialize the Supabase JS client.
3. Submit the new password form.

Visual style: match the existing `/renew` and `/payment-success` pages — dark background (`#0A0A0F`), blue accent (`#3369FF`), Urbanist font, rounded card.

Behavior:
1. On page load, parse the URL hash (`window.location.hash`) for `access_token` and `refresh_token`.
2. If missing/invalid: show "Invalid or expired reset link. Request a new one from the app." with a CTA to open the app.
3. If valid: show a form with one password field (and a confirm field), a "Set new password" submit button.
4. Validate: minimum 8 chars, both fields match.
5. On submit: call `supabase.auth.updateUser({ password: newPassword })`.
6. On success: show "Password updated. Open ArkLine to sign in." with an `arkline://invite` deep link CTA.
7. On error: show the error and let user retry.

Use `@supabase/supabase-js`. Install if not already present:

```bash
cd web && npm install @supabase/supabase-js
```

The Supabase client init needs the public URL + anon key — add as Next.js env vars (`NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`) in `.env.local` (and `.env.production` for Vercel). The same anon key the iOS app uses is fine — it's public by design.

Metadata: `title: "Reset Password — Arkline"`, `robots: { index: false, follow: false }`.

Skeleton:

```tsx
"use client";

import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

export default function ResetPasswordPage() {
  const [tokenReady, setTokenReady] = useState(false);
  const [tokenInvalid, setTokenInvalid] = useState(false);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Parse access_token from URL hash and set the session
    const hash = window.location.hash.slice(1);
    const params = new URLSearchParams(hash);
    const accessToken = params.get("access_token");
    const refreshToken = params.get("refresh_token");
    if (!accessToken || !refreshToken) {
      setTokenInvalid(true);
      return;
    }
    supabase.auth.setSession({
      access_token: accessToken,
      refresh_token: refreshToken,
    }).then(({ error }) => {
      if (error) setTokenInvalid(true);
      else setTokenReady(true);
    });
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError("Passwords don't match.");
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.updateUser({ password });
    setLoading(false);
    if (error) setError(error.message);
    else setSuccess(true);
  };

  // ... render appropriate state (loading, invalid token, form, success)
}
```

Render the three states (token invalid, form, success) with the dark-themed styling matching `/renew`. Reuse the visual structure — icon at top, headline, body copy, primary button, footer.

---

## Out of scope (do NOT do)

- Do not change the existing OTP/email-code recovery path. It stays as-is for users who prefer that.
- Do not add password reset to any *other* surface (admin panel, deep settings menu, etc.). Two iOS surfaces is enough for v1.
- Do not store the reset token client-side beyond what's needed for the immediate update call. The hash is the source of truth; don't persist.
- Do not add password strength meters or "complexity rules" beyond min 8 chars. Match what Supabase's own defaults enforce.
- Do not change Supabase Auth email template HTML. Use Supabase's defaults for the recovery email.
- Do not modify the iOS app's bundle ID, deep link schemes, or universal link setup.

## Test plan

1. **iOS sheet path (Part A):** Sign out of the admin account. Tap "Sign in with a different account" → tap "Forgot password?" with a valid email → verify confirmation state appears. Check the email inbox (Gmail/ImprovMX-forwarded) — recovery email arrives within 30 seconds.

2. **iOS onboarding path (Part B):** Delete and reinstall the app. From Welcome → "I already have an account" → on the SignInView, tap "Forgot password?" with a valid email → same confirmation state.

3. **Email link → web page (Part E):** Click the link in the recovery email on a desktop browser. Verify the page loads, shows the password form. Submit a new password (≥8 chars, matching) → success state appears.

4. **Sign in with new password:** Open the iOS app, sign in with the new password → should land in MainTabView.

5. **Invalid token state:** Visit `https://arkline.io/reset-password` directly (no hash) → should show "Invalid or expired reset link" state.

6. **Expired token:** Wait >1 hour after requesting reset, then click the email link → Supabase will reject the expired token; web page should show the invalid state.

## Manual config step (Matt does this after CC reports done)

Go to Supabase Dashboard → **Authentication → URL Configuration** → **Redirect URLs**. Add:

```
https://arkline.io/reset-password
```

Without this, Supabase will reject the `redirectTo` parameter and the recovery email may not arrive (or arrive with a broken link). Also confirm the **Site URL** is set to `https://arkline.io` if not already.

## Reporting

Briefly:

1. Files created/modified with line ranges.
2. Confirmation that `SupabaseAuthManager.shared.resetPasswordForEmail(email:redirectTo:)` exists (or describe the wrapper you added).
3. Confirmation the web page handles all three states (invalid token, form, success).
4. Verification that the npm install for `@supabase/supabase-js` succeeded.
5. The exact env var names you used and where they need to be set.
6. Build statuses (iOS + Next.js).
7. The exact URL to add to Supabase Auth redirect allowlist (for Matt's manual step).

Keep the report under 350 words.
