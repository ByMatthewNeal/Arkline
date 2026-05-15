import { ViewContentEvent } from '@/components/analytics/ViewContentEvent';
import Link from 'next/link';
import { CheckCircle2 } from 'lucide-react';

const PLAN_LABEL: Record<string, string> = {
  founding: 'Founding Member',
  'founding-monthly': 'Founding Member — Monthly',
  'founding-annual': 'Founding Member — Annual',
  standard: 'Standard',
  'standard-monthly': 'Standard — Monthly',
  'standard-annual': 'Standard — Annual',
};

interface PaymentSuccessPageProps {
  searchParams: Promise<{ plan?: string }>;
}

export default async function PaymentSuccessPage({ searchParams }: PaymentSuccessPageProps) {
  const params = await searchParams;
  const planKey = (params.plan ?? '').toLowerCase();
  const displayPlan = PLAN_LABEL[planKey] ?? 'Arkline Membership';

  return (
    <div className="min-h-screen bg-[#0A0A0F] text-white flex items-center justify-center px-6 py-12">
      <ViewContentEvent contentName="payment-success" />

      <div className="w-full max-w-[480px] text-center">
        {/* Success icon */}
        <div className="mx-auto mb-8 flex h-[72px] w-[72px] items-center justify-center rounded-full bg-[#3369FF]/15">
          <CheckCircle2 className="h-9 w-9 text-[#3369FF]" strokeWidth={2.5} />
        </div>

        {/* Heading */}
        <h1 className="font-[family-name:var(--font-urbanist)] text-[28px] font-bold tracking-tight">
          Payment Successful
        </h1>

        {/* Plan badge */}
        <div className="mt-6 inline-block rounded-full bg-[#3369FF]/12 px-4 py-1.5 text-[13px] font-semibold tracking-wide text-[#6B9AFF]">
          {displayPlan}
        </div>

        {/* Message */}
        <p className="mt-6 text-[17px] leading-relaxed text-white/70">
          Your invite code is on its way.
          <br />
          Check your <span className="font-semibold text-white">email</span> for your unique code and instructions.
        </p>

        {/* Steps */}
        <div className="mt-10 rounded-2xl border border-white/[0.08] bg-white/[0.04] p-6 text-left">
          <h3 className="mb-4 text-xs font-semibold uppercase tracking-widest text-white/50">
            Next Steps
          </h3>
          <ol className="space-y-3">
            <li className="flex items-start gap-3">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#3369FF] text-[13px] font-bold text-white">
                1
              </span>
              <span className="text-[15px] leading-snug text-white/80">
                Check your email for your invite code (ARK-XXXXXX)
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#3369FF] text-[13px] font-bold text-white">
                2
              </span>
              <span className="text-[15px] leading-snug text-white/80">
                Open the Arkline app and enter your code
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#3369FF] text-[13px] font-bold text-white">
                3
              </span>
              <span className="text-[15px] leading-snug text-white/80">
                Create your account and start tracking
              </span>
            </li>
          </ol>
        </div>

        {/* CTA */}
        <div className="mt-8">
          <a
            href="arkline://invite"
            className="inline-block rounded-xl bg-[#3369FF] px-10 py-4 text-[17px] font-semibold text-white transition-colors hover:bg-[#2855D6]"
          >
            Open Arkline
          </a>
        </div>

        {/* Footer */}
        <p className="mt-12 text-[13px] text-white/30">
          Didn&apos;t get the email? Check your spam folder or contact{' '}
          <a href="mailto:support@arkline.io" className="underline hover:text-white/60">
            support@arkline.io
          </a>
        </p>
      </div>
    </div>
  );
}

export const metadata = {
  title: 'Payment Successful — Arkline',
  description: 'Your Arkline membership is being activated.',
  robots: { index: false, follow: false },
};
