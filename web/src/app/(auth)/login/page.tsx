'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { ArrowRight } from 'lucide-react';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import { Button, Input } from '@/components/ui';

const schema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

type FormValues = z.infer<typeof schema>;

/** Sign-in methods: password, or email OTP code (iOS-onboarding parity —
 *  members who signed up on iOS verified via email code and may have no password). */
type Method = 'password' | 'otp';

export default function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [resetSent, setResetSent] = useState(false);
  const [method, setMethod] = useState<Method>('password');
  // OTP flow state
  const [otpEmail, setOtpEmail] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [otpSent, setOtpSent] = useState(false);

  const {
    register,
    handleSubmit,
    getValues,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
  });

  const onSubmit = async (data: FormValues) => {
    setError('');
    setResetSent(false);
    setLoading(true);
    try {
      if (!isSupabaseConfigured()) {
        throw new Error('Sign-in is not available right now. Please try again later.');
      }
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword({
        email: data.email,
        password: data.password,
      });
      if (authError) throw authError;
      router.push('/dashboard');
      router.refresh();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Sign in failed');
    } finally {
      setLoading(false);
    }
  };

  const sendOtp = async () => {
    setError('');
    const email = otpEmail.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError('Enter a valid email address.');
      return;
    }
    if (!isSupabaseConfigured()) {
      setError('Sign-in is not available right now. Please try again later.');
      return;
    }
    setLoading(true);
    try {
      const supabase = createClient();
      // shouldCreateUser: false — Arkline is invite-only; the code only goes
      // to existing accounts, mirroring the iOS sign-in (not onboarding) flow.
      const { error: otpError } = await supabase.auth.signInWithOtp({
        email,
        options: { shouldCreateUser: false },
      });
      if (otpError) throw otpError;
      setOtpSent(true);
      setOtpCode('');
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Could not send code';
      // Supabase returns "Signups not allowed for otp" for unknown emails.
      setError(/signup/i.test(msg) ? 'No account found with that email.' : msg);
    } finally {
      setLoading(false);
    }
  };

  const verifyOtp = async () => {
    setError('');
    if (otpCode.trim().length < 6) {
      setError('Enter the 6-digit code from your email.');
      return;
    }
    setLoading(true);
    try {
      const supabase = createClient();
      const { error: verifyError } = await supabase.auth.verifyOtp({
        email: otpEmail.trim(),
        token: otpCode.trim(),
        type: 'email',
      });
      if (verifyError) throw verifyError;
      router.push('/dashboard');
      router.refresh();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Invalid or expired code');
    } finally {
      setLoading(false);
    }
  };

  const switchMethod = (m: Method) => {
    setMethod(m);
    setError('');
    setResetSent(false);
    setOtpSent(false);
    setOtpCode('');
  };

  const onForgotPassword = async () => {
    setError('');
    setResetSent(false);
    const email = getValues('email')?.trim();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError('Enter your email above, then tap “Forgot password?”');
      return;
    }
    if (!isSupabaseConfigured()) {
      setError('Password reset is not available right now. Please try again later.');
      return;
    }
    try {
      const supabase = createClient();
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      });
      if (resetError) throw resetError;
      setResetSent(true);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Could not send reset email');
    }
  };

  return (
    <div className="overflow-hidden rounded-2xl border border-white/[0.08] bg-ark-bg/80 shadow-2xl backdrop-blur-xl">
      {/* Top accent */}
      <div className="h-px bg-gradient-to-r from-transparent via-ark-primary/50 to-transparent" />

      <div className="p-6 sm:p-8">
        <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text">
          Sign in to Arkline
        </h1>
        <p className="mt-1.5 text-sm text-ark-text-secondary">
          Welcome back. Access your portfolio, risk scoring, and daily briefings.
        </p>

        {/* Method toggle */}
        <div className="mt-6 flex rounded-xl bg-ark-fill-secondary/60 p-1">
          {([['password', 'Password'], ['otp', 'Email code']] as const).map(([m, label]) => (
            <button
              key={m}
              type="button"
              onClick={() => switchMethod(m)}
              className={`flex-1 rounded-lg px-3 py-2 text-sm font-semibold transition-colors ${
                method === m ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {method === 'otp' ? (
          <div className="mt-6 space-y-4">
            {!otpSent ? (
              <>
                <Input
                  id="otp-email"
                  type="email"
                  label="Email"
                  placeholder="you@example.com"
                  autoComplete="email"
                  value={otpEmail}
                  onChange={(e) => setOtpEmail(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); sendOtp(); } }}
                />
                <p className="text-xs text-ark-text-tertiary">
                  We&apos;ll email you a 6-digit code — the same way you signed in on the iOS app.
                </p>
                {error && (
                  <div className="rounded-xl border border-ark-error/20 bg-ark-error/5 p-3">
                    <p className="text-sm text-ark-error">{error}</p>
                  </div>
                )}
                <Button type="button" onClick={sendOtp} loading={loading} className="w-full shadow-lg shadow-ark-primary/20">
                  Send Code
                  <ArrowRight className="h-4 w-4" />
                </Button>
              </>
            ) : (
              <>
                <p className="text-sm text-ark-text-secondary">
                  Enter the 6-digit code we sent to <span className="font-semibold text-ark-text">{otpEmail.trim()}</span>.
                </p>
                <Input
                  id="otp-code"
                  type="text"
                  label="Verification code"
                  placeholder="123456"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  maxLength={6}
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                  onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); verifyOtp(); } }}
                />
                {error && (
                  <div className="rounded-xl border border-ark-error/20 bg-ark-error/5 p-3">
                    <p className="text-sm text-ark-error">{error}</p>
                  </div>
                )}
                <Button type="button" onClick={verifyOtp} loading={loading} className="w-full shadow-lg shadow-ark-primary/20">
                  Verify &amp; Sign In
                  <ArrowRight className="h-4 w-4" />
                </Button>
                <div className="flex items-center justify-between text-xs">
                  <button type="button" onClick={() => { setOtpSent(false); setError(''); }} className="font-medium text-ark-text-tertiary transition-colors hover:text-ark-text">
                    Use a different email
                  </button>
                  <button type="button" onClick={sendOtp} className="font-medium text-ark-primary transition-colors hover:text-ark-accent-light">
                    Resend code
                  </button>
                </div>
              </>
            )}
          </div>
        ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="mt-6 space-y-4">
          <Input
            id="email"
            type="email"
            label="Email"
            placeholder="you@example.com"
            autoComplete="email"
            error={errors.email?.message}
            {...register('email')}
          />
          <div>
            <Input
              id="password"
              type="password"
              label="Password"
              placeholder="Your password"
              autoComplete="current-password"
              error={errors.password?.message}
              {...register('password')}
            />
            <button
              type="button"
              onClick={onForgotPassword}
              className="mt-2 text-xs font-medium text-ark-primary transition-colors hover:text-ark-accent-light"
            >
              Forgot password?
            </button>
          </div>

          {resetSent && (
            <div className="rounded-xl border border-ark-primary/20 bg-ark-primary/5 p-3">
              <p className="text-sm text-ark-text-secondary">
                Check your inbox — we sent a password reset link.
              </p>
            </div>
          )}

          {error && (
            <div className="rounded-xl border border-ark-error/20 bg-ark-error/5 p-3">
              <p className="text-sm text-ark-error">{error}</p>
            </div>
          )}

          <Button type="submit" loading={loading} className="w-full shadow-lg shadow-ark-primary/20">
            Sign In
            <ArrowRight className="h-4 w-4" />
          </Button>
        </form>
        )}

        <div className="mt-8 flex items-center gap-3">
          <div className="h-px flex-1 bg-ark-divider" />
          <span className="text-xs text-ark-text-tertiary">or</span>
          <div className="h-px flex-1 bg-ark-divider" />
        </div>

        <p className="mt-6 text-center text-sm text-ark-text-secondary">
          Don&apos;t have an account?{' '}
          <Link href="/signup" className="font-medium text-ark-primary transition-colors hover:text-ark-accent-light">
            Create one
          </Link>
        </p>
      </div>
    </div>
  );
}
