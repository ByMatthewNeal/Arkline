'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { ArrowRight } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { Button, Input } from '@/components/ui';
import { validateInviteCode } from '@/lib/api/onboarding';

const schema = z
  .object({
    inviteCode: z.string().min(1, 'An invite code is required'),
    email: z.string().email('Invalid email address'),
    password: z.string().min(6, 'Password must be at least 6 characters'),
    confirmPassword: z.string(),
  })
  .refine((d) => d.password === d.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  });

type FormValues = z.infer<typeof schema>;

export default function SignupPage() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
  });

  const onSubmit = async (data: FormValues) => {
    setError('');
    setLoading(true);
    try {
      // Invite-only: validate the code before creating the account.
      const invite = await validateInviteCode(data.inviteCode);
      if (!invite.ok) {
        setError(invite.error ?? 'Invalid invite code.');
        setLoading(false);
        return;
      }

      const supabase = createClient();
      const { error: authError } = await supabase.auth.signUp({
        email: data.email,
        password: data.password,
        options: { data: { invite_code: invite.code } },
      });
      if (authError) throw authError;

      // New users continue into the onboarding flow (profile setup).
      router.push('/onboarding');
      router.refresh();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Signup failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="overflow-hidden rounded-2xl border border-white/[0.08] bg-ark-bg/80 shadow-2xl backdrop-blur-xl">
      {/* Top accent */}
      <div className="h-px bg-gradient-to-r from-transparent via-ark-primary/50 to-transparent" />

      <div className="p-6 sm:p-8">
        <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text">
          Create your Arkline account
        </h1>
        <p className="mt-1.5 text-sm text-ark-text-secondary">
          Arkline is invite-only. Enter your invite code to set up your account.
        </p>

        <form onSubmit={handleSubmit(onSubmit)} className="mt-8 space-y-4">
          <Input
            id="inviteCode"
            type="text"
            label="Invite Code"
            placeholder="ARK-XXXXXX"
            error={errors.inviteCode?.message}
            {...register('inviteCode')}
          />
          <Input
            id="email"
            type="email"
            label="Email"
            placeholder="you@example.com"
            error={errors.email?.message}
            {...register('email')}
          />
          <Input
            id="password"
            type="password"
            label="Password"
            placeholder="At least 6 characters"
            error={errors.password?.message}
            {...register('password')}
          />
          <Input
            id="confirmPassword"
            type="password"
            label="Confirm Password"
            placeholder="Confirm your password"
            error={errors.confirmPassword?.message}
            {...register('confirmPassword')}
          />

          {error && (
            <div className="rounded-xl border border-ark-error/20 bg-ark-error/5 p-3">
              <p className="text-sm text-ark-error">{error}</p>
            </div>
          )}

          <Button type="submit" loading={loading} className="w-full shadow-lg shadow-ark-primary/20">
            Create Account
            <ArrowRight className="h-4 w-4" />
          </Button>
        </form>

        <div className="mt-8 flex items-center gap-3">
          <div className="h-px flex-1 bg-ark-divider" />
          <span className="text-xs text-ark-text-tertiary">or</span>
          <div className="h-px flex-1 bg-ark-divider" />
        </div>

        <p className="mt-6 text-center text-sm text-ark-text-secondary">
          Already have an account?{' '}
          <Link href="/login" className="font-medium text-ark-primary transition-colors hover:text-ark-accent-light">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
