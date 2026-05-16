import { Mail } from 'lucide-react';

export default function RenewPage() {
  return (
    <div className="min-h-screen bg-[#0A0A0F] text-white flex items-center justify-center px-6 py-12">
      <div className="w-full max-w-[480px] text-center">
        {/* Icon */}
        <div className="mx-auto mb-8 flex h-[72px] w-[72px] items-center justify-center rounded-full bg-[#3369FF]/15">
          <Mail className="h-9 w-9 text-[#3369FF]" strokeWidth={2.5} />
        </div>

        {/* Heading */}
        <h1 className="font-[family-name:var(--font-urbanist)] text-[28px] font-bold tracking-tight">
          Renew your Arkline membership
        </h1>

        {/* Body */}
        <p className="mt-6 text-[17px] leading-relaxed text-white/70">
          Your subscription has ended. To reactivate your access, email us and
          we&apos;ll send you a fresh checkout link. Your portfolio data and history
          are safe&nbsp;&mdash; when you renew, everything will be right where you
          left it.
        </p>

        {/* CTA */}
        <div className="mt-10">
          <a
            href="mailto:support@arkline.io?subject=Renew%20my%20Arkline%20membership"
            className="inline-block rounded-xl bg-[#3369FF] px-10 py-4 text-[17px] font-semibold text-white transition-colors hover:bg-[#2855D6]"
          >
            Email support@arkline.io
          </a>
        </div>

        {/* Footer */}
        <p className="mt-12 text-[13px] text-white/30">
          We typically respond within a few hours and will have you back up and
          running the same day.
        </p>
      </div>
    </div>
  );
}

export const metadata = {
  title: 'Renew — Arkline',
  description: 'Reactivate your Arkline membership.',
  robots: { index: false, follow: false },
};
