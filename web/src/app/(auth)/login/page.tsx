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

export default function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [resetSent, setResetSent] = useState(false);

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

        <form onSubmit={handleSubmit(onSubmit)} className="mt-8 space-y-4">
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
