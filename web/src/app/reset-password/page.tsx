"use client";

import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import { KeyRound, AlertCircle, CheckCircle2 } from "lucide-react";

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
  const [initializing, setInitializing] = useState(true);

  useEffect(() => {
    async function init() {
      // Check for error params first (Supabase sends these on verification failure)
      const searchParams = new URLSearchParams(window.location.search);
      const hashParams = new URLSearchParams(window.location.hash.slice(1));
      const urlError = searchParams.get("error") || hashParams.get("error");
      const errorCode = searchParams.get("error_code") || hashParams.get("error_code");
      const errorDesc = searchParams.get("error_description") || hashParams.get("error_description");

      if (urlError) {
        if (errorCode === "otp_expired") {
          setError("This link has already been used or expired. Open ArkLine and request a new password reset link.");
        } else {
          setError(errorDesc?.replace(/\+/g, " ") || "Something went wrong. Please request a new reset link.");
        }
        setTokenInvalid(true);
        setInitializing(false);
        return;
      }

      // Token hash flow (primary): ?token_hash=...&type=recovery
      const tokenHash = searchParams.get("token_hash");
      const type = searchParams.get("type");
      if (tokenHash && type === "recovery") {
        const { error } = await supabase.auth.verifyOtp({
          token_hash: tokenHash,
          type: "recovery",
        });
        if (error) setTokenInvalid(true);
        else setTokenReady(true);
        setInitializing(false);
        return;
      }

      // PKCE fallback: ?code=... query param
      const code = searchParams.get("code");
      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (error) setTokenInvalid(true);
        else setTokenReady(true);
        setInitializing(false);
        return;
      }

      // Implicit flow fallback: #access_token=...&refresh_token=...
      const accessToken = hashParams.get("access_token");
      const refreshToken = hashParams.get("refresh_token");
      if (accessToken && refreshToken) {
        const { error } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });
        if (error) setTokenInvalid(true);
        else setTokenReady(true);
        setInitializing(false);
        return;
      }

      // No token found
      setTokenInvalid(true);
      setInitializing(false);
    }

    init();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError("Passwords don&apos;t match.");
      return;
    }

    setLoading(true);
    const { error } = await supabase.auth.updateUser({ password });
    setLoading(false);

    if (error) setError(error.message);
    else setSuccess(true);
  };

  if (initializing) {
    return (
      <div className="min-h-screen bg-[#0A0A0F] text-white flex items-center justify-center">
        <div className="animate-spin h-8 w-8 border-2 border-[#3369FF] border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0A0A0F] text-white flex items-center justify-center px-6 py-12">
      <div className="w-full max-w-[480px] text-center">
        {tokenInvalid && <InvalidTokenView message={error} />}
        {tokenReady && !success && (
          <FormView
            password={password}
            confirm={confirm}
            error={error}
            loading={loading}
            onPasswordChange={setPassword}
            onConfirmChange={setConfirm}
            onSubmit={handleSubmit}
          />
        )}
        {success && <SuccessView />}
      </div>
    </div>
  );
}

function InvalidTokenView({ message }: { message?: string | null }) {
  return (
    <>
      <div className="mx-auto mb-8 flex h-[72px] w-[72px] items-center justify-center rounded-full bg-[#F59E0B]/15">
        <AlertCircle className="h-9 w-9 text-[#F59E0B]" strokeWidth={2.5} />
      </div>
      <h1 className="font-[family-name:var(--font-urbanist)] text-[28px] font-bold tracking-tight">
        Invalid or expired link
      </h1>
      <p className="mt-6 text-[17px] leading-relaxed text-white/70">
        {message || "This password reset link has expired or has already been used. Open ArkLine and request a new one from the sign-in screen."}
      </p>
      <div className="mt-10">
        <a
          href="arkline://invite"
          className="inline-block rounded-xl bg-[#3369FF] px-10 py-4 text-[17px] font-semibold text-white transition-colors hover:bg-[#2855D6]"
        >
          Open ArkLine
        </a>
      </div>
    </>
  );
}

function FormView({
  password,
  confirm,
  error,
  loading,
  onPasswordChange,
  onConfirmChange,
  onSubmit,
}: {
  password: string;
  confirm: string;
  error: string | null;
  loading: boolean;
  onPasswordChange: (v: string) => void;
  onConfirmChange: (v: string) => void;
  onSubmit: (e: React.FormEvent) => void;
}) {
  return (
    <>
      <div className="mx-auto mb-8 flex h-[72px] w-[72px] items-center justify-center rounded-full bg-[#3369FF]/15">
        <KeyRound className="h-9 w-9 text-[#3369FF]" strokeWidth={2.5} />
      </div>
      <h1 className="font-[family-name:var(--font-urbanist)] text-[28px] font-bold tracking-tight">
        Set a new password
      </h1>
      <p className="mt-4 text-[15px] text-white/50">
        Choose a password with at least 8 characters.
      </p>

      <form onSubmit={onSubmit} className="mt-8 space-y-4 text-left">
        <div>
          <label className="block text-[13px] font-medium text-white/50 mb-1.5">
            New password
          </label>
          <input
            type="password"
            value={password}
            onChange={(e) => onPasswordChange(e.target.value)}
            className="w-full rounded-xl border border-white/[0.08] bg-white/[0.04] px-4 py-3 text-[15px] text-white placeholder-white/30 outline-none focus:border-[#3369FF]/50 focus:ring-1 focus:ring-[#3369FF]/30"
            placeholder="At least 8 characters"
            autoFocus
          />
        </div>
        <div>
          <label className="block text-[13px] font-medium text-white/50 mb-1.5">
            Confirm password
          </label>
          <input
            type="password"
            value={confirm}
            onChange={(e) => onConfirmChange(e.target.value)}
            className="w-full rounded-xl border border-white/[0.08] bg-white/[0.04] px-4 py-3 text-[15px] text-white placeholder-white/30 outline-none focus:border-[#3369FF]/50 focus:ring-1 focus:ring-[#3369FF]/30"
            placeholder="Re-enter password"
          />
        </div>

        {error && (
          <p className="text-[13px] text-[#DC2626]">{error}</p>
        )}

        <button
          type="submit"
          disabled={loading || !password || !confirm}
          className="w-full rounded-xl bg-[#3369FF] px-6 py-4 text-[17px] font-semibold text-white transition-colors hover:bg-[#2855D6] disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {loading ? "Updating..." : "Set new password"}
        </button>
      </form>
    </>
  );
}

function SuccessView() {
  return (
    <>
      <div className="mx-auto mb-8 flex h-[72px] w-[72px] items-center justify-center rounded-full bg-[#3369FF]/15">
        <CheckCircle2 className="h-9 w-9 text-[#3369FF]" strokeWidth={2.5} />
      </div>
      <h1 className="font-[family-name:var(--font-urbanist)] text-[28px] font-bold tracking-tight">
        Password updated
      </h1>
      <p className="mt-6 text-[17px] leading-relaxed text-white/70">
        Your password has been changed. Open ArkLine to sign in with your new
        password.
      </p>
      <div className="mt-10">
        <a
          href="arkline://invite"
          className="inline-block rounded-xl bg-[#3369FF] px-10 py-4 text-[17px] font-semibold text-white transition-colors hover:bg-[#2855D6]"
        >
          Open ArkLine
        </a>
      </div>
      <p className="mt-12 text-[13px] text-white/30">
        If the button doesn&apos;t work, open the ArkLine app manually and sign
        in with your new password.
      </p>
    </>
  );
}
