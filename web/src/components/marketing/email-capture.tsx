'use client';

import { useState, type FormEvent } from 'react';
import { CheckCircle2, ArrowRight, Loader2 } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

type Status = 'idle' | 'loading' | 'success' | 'duplicate' | 'error';

interface EmailCaptureProps {
  size?: 'lg' | 'inline';
  className?: string;
}

export function EmailCapture({ size = 'lg', className = '' }: EmailCaptureProps) {
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<Status>('idle');

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const trimmed = email.trim().toLowerCase();
    if (!trimmed || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) return;

    setStatus('loading');
    try {
      const supabase = createClient();
      const { error } = await supabase
        .from('early_access_signups')
        .insert({ email: trimmed });

      if (error) {
        // Unique constraint violation = duplicate
        if (error.code === '23505') {
          setStatus('duplicate');
        } else {
          setStatus('error');
        }
      } else {
        setStatus('success');
      }
    } catch {
      setStatus('error');
    }
  }

  // Success / duplicate confirmation
  if (status === 'success' || status === 'duplicate') {
    return (
      <div className={`flex items-center gap-2 ${size === 'inline' ? 'h-8' : 'justify-center py-3'} ${className}`}>
        <CheckCircle2 className="h-4 w-4 shrink-0 text-ark-success" />
        <span className={`font-medium text-ark-success ${size === 'inline' ? 'text-xs' : 'text-sm'}`}>
          {status === 'success' ? "You're on the list!" : "You're already signed up!"}
        </span>
      </div>
    );
  }

  if (size === 'inline') {
    return (
      <form onSubmit={handleSubmit} className={`flex items-center gap-1.5 ${className}`}>
        <input
          type="email"
          value={email}
          onChange={(e) => { setEmail(e.target.value); setStatus('idle'); }}
          placeholder="Enter your email"
          required
          className="h-8 w-[160px] min-w-0 flex-1 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2.5 text-xs text-ark-text placeholder:text-ark-text-tertiary outline-none transition-colors focus:border-ark-primary focus:ring-2 focus:ring-ark-primary/20 sm:w-[180px] sm:flex-none"
        />
        <button
          type="submit"
          disabled={status === 'loading'}
          className="inline-flex h-8 items-center gap-1.5 rounded-lg bg-ark-primary px-3 text-xs font-medium text-white shadow-md transition-colors hover:bg-ark-accent-dark disabled:opacity-50 cursor-pointer"
        >
          {status === 'loading' ? (
            <Loader2 className="h-3 w-3 animate-spin" />
          ) : (
            <>
              Get Early Access
              <ArrowRight className="h-3 w-3" />
            </>
          )}
        </button>
        {status === 'error' && (
          <span className="text-xs text-ark-error">Something went wrong</span>
        )}
      </form>
    );
  }

  // Large variant (hero / CTA sections)
  return (
    <div className={className}>
      <form onSubmit={handleSubmit} className="flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
        <input
          type="email"
          value={email}
          onChange={(e) => { setEmail(e.target.value); setStatus('idle'); }}
          placeholder="Enter your email"
          required
          className="h-[52px] w-full rounded-lg border border-ark-divider bg-ark-fill-secondary px-4 text-sm text-ark-text placeholder:text-ark-text-tertiary outline-none transition-colors focus:border-ark-primary focus:ring-2 focus:ring-ark-primary/20 sm:w-[300px]"
        />
        <button
          type="submit"
          disabled={status === 'loading'}
          className="inline-flex h-[52px] w-full shrink-0 items-center justify-center gap-2 whitespace-nowrap rounded-lg bg-ark-primary px-6 text-base font-medium text-white shadow-lg shadow-ark-primary/20 transition-colors hover:bg-ark-accent-dark disabled:opacity-50 cursor-pointer sm:w-auto"
        >
          {status === 'loading' ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <>
              Get Early Access
              <ArrowRight className="h-4 w-4" />
            </>
          )}
        </button>
      </form>
      {status === 'error' && (
        <p className="mt-2 text-center text-sm text-ark-error">Something went wrong. Please try again.</p>
      )}
    </div>
  );
}
