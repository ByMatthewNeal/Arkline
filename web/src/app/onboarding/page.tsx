'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowRight, ArrowLeft, Check, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui';
import { cn } from '@/lib/utils/format';
import {
  ONBOARDING_STEPS, SKIPPABLE_STEPS, EMPTY_ONBOARDING_DATA, PAYMENT_PLANS,
  INVESTMENT_INTERESTS, EXPERIENCE_LEVELS, PORTFOLIO_SIZES,
  CRYPTO_APPROACHES, PORTFOLIO_GOALS,
  type OnboardingData, type OnboardingStepId,
} from '@/lib/onboarding/config';
import { completeOnboarding, getOnboardingState, startSelfCheckout } from '@/lib/api/onboarding';

const STEP_TITLES: Record<OnboardingStepId, { title: string; subtitle: string }> = {
  payment: { title: 'Activate your membership', subtitle: 'Secure checkout via Stripe. Cancel anytime.' },
  name: { title: 'What should we call you?', subtitle: 'Your name personalizes your briefings.' },
  interests: { title: 'What do you invest in?', subtitle: 'Select all that apply.' },
  experience: { title: 'Your experience', subtitle: 'Helps us tune the depth of your signals.' },
  approach: { title: 'How do you approach crypto?', subtitle: 'Pick the one that fits best.' },
  goals: { title: 'What matters most to you?', subtitle: 'Select all that apply.' },
  notifications: { title: 'Stay in the loop', subtitle: 'Get trade signals and daily briefings.' },
  complete: { title: 'Setting up your account', subtitle: '' },
};

export default function OnboardingPage() {
  const router = useRouter();
  const [stepIndex, setStepIndex] = useState(0);
  const [data, setData] = useState<OnboardingData>(EMPTY_ONBOARDING_DATA);
  const [steps, setSteps] = useState<OnboardingStepId[]>(ONBOARDING_STEPS);
  const [initializing, setInitializing] = useState(true);

  // Decide whether the payment step is needed (self-serve users who haven't paid)
  // and handle the return from Stripe (?paid=1) by polling for activation.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const justPaid = new URLSearchParams(window.location.search).get('paid') === '1';
      let state = await getOnboardingState();

      if (justPaid && state.needsPayment) {
        // Webhook may lag the redirect — poll briefly for the active status.
        for (let i = 0; i < 6 && state.needsPayment; i++) {
          await new Promise((r) => setTimeout(r, 1500));
          state = await getOnboardingState();
        }
      }
      if (cancelled) return;

      setSteps(state.needsPayment ? ['payment', ...ONBOARDING_STEPS] : ONBOARDING_STEPS);
      setInitializing(false);
    })();
    return () => { cancelled = true; };
  }, []);

  const step = steps[stepIndex];
  const numberedSteps: OnboardingStepId[] = steps.filter((s) => s !== 'complete');
  const currentNumber = numberedSteps.indexOf(step) + 1;
  const total = numberedSteps.length;

  const next = () => setStepIndex((i) => Math.min(i + 1, steps.length - 1));
  const back = () => setStepIndex((i) => Math.max(i - 1, 0));

  const set = <K extends keyof OnboardingData>(key: K, value: OnboardingData[K]) =>
    setData((d) => ({ ...d, [key]: value }));

  const toggle = (key: 'interests' | 'goals', id: string) =>
    setData((d) => {
      const arr = d[key];
      return { ...d, [key]: arr.includes(id) ? arr.filter((x) => x !== id) : [...arr, id] };
    });

  const canAdvance =
    step === 'name' ? data.firstName.trim().length > 0 : true;

  if (initializing) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-ark-primary" />
      </div>
    );
  }

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-lg flex-col px-5 py-10">
      {/* Progress */}
      {step !== 'complete' && (
        <div className="mb-10">
          <div className="mb-2 flex items-center justify-between text-xs text-ark-text-tertiary">
            <span>Step {currentNumber} of {total}</span>
            {SKIPPABLE_STEPS.has(step) && (
              <button onClick={next} className="font-medium text-ark-text-secondary transition-colors hover:text-ark-text">
                Skip
              </button>
            )}
          </div>
          <div className="h-1 overflow-hidden rounded-full bg-ark-fill-secondary">
            <div
              className="h-full rounded-full bg-ark-primary transition-all duration-300"
              style={{ width: `${(currentNumber / total) * 100}%` }}
            />
          </div>
        </div>
      )}

      <div className="flex flex-1 flex-col">
        <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text">
          {STEP_TITLES[step].title}
        </h1>
        {STEP_TITLES[step].subtitle && (
          <p className="mt-1.5 text-sm text-ark-text-secondary">{STEP_TITLES[step].subtitle}</p>
        )}

        <div className="mt-8 flex-1">
          {step === 'payment' && <PaymentStep />}

          {step === 'name' && (
            <div className="space-y-4">
              <TextField label="First name" value={data.firstName} onChange={(v) => set('firstName', v)} placeholder="Jane" autoFocus />
              <TextField label="Last name (optional)" value={data.lastName} onChange={(v) => set('lastName', v)} placeholder="Doe" />
            </div>
          )}

          {step === 'interests' && (
            <ChipGrid
              options={INVESTMENT_INTERESTS}
              selected={data.interests}
              onToggle={(id) => toggle('interests', id)}
            />
          )}

          {step === 'experience' && (
            <div className="space-y-6">
              <ChipGrid
                options={EXPERIENCE_LEVELS}
                selected={data.experienceLevel ? [data.experienceLevel] : []}
                onToggle={(id) => set('experienceLevel', data.experienceLevel === id ? null : id)}
              />
              <div>
                <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">Portfolio size</p>
                <ChipGrid
                  options={PORTFOLIO_SIZES}
                  selected={data.portfolioSize ? [data.portfolioSize] : []}
                  onToggle={(id) => set('portfolioSize', data.portfolioSize === id ? null : id)}
                />
              </div>
            </div>
          )}

          {step === 'approach' && (
            <ChipGrid
              options={CRYPTO_APPROACHES}
              selected={data.cryptoApproach ? [data.cryptoApproach] : []}
              onToggle={(id) => set('cryptoApproach', data.cryptoApproach === id ? null : id)}
            />
          )}

          {step === 'goals' && (
            <ChipGrid
              options={PORTFOLIO_GOALS}
              selected={data.goals}
              onToggle={(id) => toggle('goals', id)}
            />
          )}

          {step === 'notifications' && (
            <button
              onClick={() => set('notificationsEnabled', !data.notificationsEnabled)}
              className={cn(
                'flex w-full items-center justify-between rounded-xl border p-4 text-left transition-colors',
                data.notificationsEnabled ? 'border-ark-primary bg-ark-primary/5' : 'border-ark-divider bg-ark-fill-secondary/30',
              )}
            >
              <div>
                <p className="text-sm font-semibold text-ark-text">Enable notifications</p>
                <p className="text-xs text-ark-text-tertiary">Trade signals, daily briefings, and risk alerts.</p>
              </div>
              <span className={cn(
                'flex h-6 w-6 items-center justify-center rounded-full border',
                data.notificationsEnabled ? 'border-ark-primary bg-ark-primary text-white' : 'border-ark-divider',
              )}>
                {data.notificationsEnabled && <Check className="h-3.5 w-3.5" />}
              </span>
            </button>
          )}

          {step === 'complete' && <CompleteStep data={data} onDone={() => { router.push('/dashboard'); router.refresh(); }} />}
        </div>

        {step !== 'complete' && step !== 'payment' && (
          <div className="mt-8 flex items-center gap-3">
            {stepIndex > 0 && steps[stepIndex - 1] !== 'payment' && (
              <Button type="button" variant="secondary" onClick={back} className="px-4">
                <ArrowLeft className="h-4 w-4" />
              </Button>
            )}
            <Button type="button" onClick={next} disabled={!canAdvance} className="flex-1">
              Continue
              <ArrowRight className="h-4 w-4" />
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Sub-components ───────────────────────────────────────────────────────────

function TextField({ label, value, onChange, placeholder, autoFocus }: {
  label: string; value: string; onChange: (v: string) => void; placeholder?: string; autoFocus?: boolean;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-medium text-ark-text-secondary">{label}</span>
      <input
        type="text"
        value={value}
        autoFocus={autoFocus}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/30 px-4 py-3 text-sm text-ark-text outline-none transition-colors focus:border-ark-primary"
      />
    </label>
  );
}

function ChipGrid({ options, selected, onToggle }: {
  options: readonly { id: string; label: string; description?: string }[];
  selected: string[];
  onToggle: (id: string) => void;
}) {
  return (
    <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
      {options.map((opt) => {
        const active = selected.includes(opt.id);
        return (
          <button
            key={opt.id}
            onClick={() => onToggle(opt.id)}
            className={cn(
              'flex items-start gap-3 rounded-xl border p-3.5 text-left transition-colors',
              active ? 'border-ark-primary bg-ark-primary/5' : 'border-ark-divider bg-ark-fill-secondary/30 hover:border-ark-text-disabled/40',
            )}
          >
            <span className={cn(
              'mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border',
              active ? 'border-ark-primary bg-ark-primary text-white' : 'border-ark-divider',
            )}>
              {active && <Check className="h-3 w-3" />}
            </span>
            <span>
              <span className="block text-sm font-semibold text-ark-text">{opt.label}</span>
              {opt.description && <span className="mt-0.5 block text-xs text-ark-text-tertiary">{opt.description}</span>}
            </span>
          </button>
        );
      })}
    </div>
  );
}

function CompleteStep({ data, onDone }: { data: OnboardingData; onDone: () => void }) {
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const res = await completeOnboarding(data);
      if (cancelled) return;
      if (res.ok) onDone();
      else setError(res.error ?? 'Something went wrong.');
    })();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (error) {
    return (
      <div className="rounded-xl border border-ark-error/20 bg-ark-error/5 p-4">
        <p className="text-sm text-ark-error">{error}</p>
        <button onClick={() => location.reload()} className="mt-2 text-sm font-medium text-ark-primary">Try again</button>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <Loader2 className="h-8 w-8 animate-spin text-ark-primary" />
      <p className="mt-4 text-sm text-ark-text-secondary">Finishing setup…</p>
    </div>
  );
}

function PaymentStep() {
  const [selected, setSelected] = useState<string>(PAYMENT_PLANS[0].id);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const checkout = async () => {
    setLoading(true);
    setError('');
    const res = await startSelfCheckout(selected);
    if (res.ok && res.url) {
      window.location.href = res.url;
    } else {
      setError(res.error ?? 'Could not start checkout.');
      setLoading(false);
    }
  };

  return (
    <div className="space-y-3">
      {PAYMENT_PLANS.map((plan) => {
        const active = selected === plan.id;
        return (
          <button
            key={plan.id}
            onClick={() => setSelected(plan.id)}
            className={cn(
              'flex w-full items-center justify-between rounded-xl border p-4 text-left transition-colors',
              active ? 'border-ark-primary bg-ark-primary/5' : 'border-ark-divider bg-ark-fill-secondary/30 hover:border-ark-text-disabled/40',
            )}
          >
            <div>
              <div className="flex items-center gap-2">
                <p className="text-sm font-semibold text-ark-text">{plan.label}</p>
                {plan.highlight && (
                  <span className="rounded-full bg-ark-primary/10 px-2 py-0.5 text-[10px] font-semibold text-ark-primary">Best value</span>
                )}
              </div>
              <p className="text-xs text-ark-text-tertiary">{plan.note}</p>
            </div>
            <div className="text-right">
              <p className="fig text-sm font-bold text-ark-text">{plan.price}</p>
              <p className="text-[11px] text-ark-text-tertiary">{plan.cadence}</p>
            </div>
          </button>
        );
      })}

      {error && <p className="text-sm text-ark-error">{error}</p>}

      <Button type="button" onClick={checkout} loading={loading} className="mt-2 w-full">
        Continue to secure checkout
        <ArrowRight className="h-4 w-4" />
      </Button>
      <p className="text-center text-[11px] text-ark-text-tertiary">Powered by Stripe · Cancel anytime</p>
    </div>
  );
}
