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
          Renew your ArkLine membership
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
            href="mailto:support@arkline.io?subject=Renew%20my%20ArkLine%20membership&body=Hi%20Arkline%20team%2C%0A%0AI'd%20like%20to%20renew%20my%20ArkLine%20membership.%20Please%20send%20me%20a%20new%20checkout%20link.%0A%0AThanks!"
            className="inline-block rounded-xl bg-[#3369FF] px-10 py-4 text-[17px] font-semibold text-white transition-colors hover:bg-[#2855D6]"
          >
            Email support@arkline.io
          </a>
        </div>

        {/* Footer */}
        <p className="mt-12 text-[13px] text-white/30">
          Most renewals are processed within a few hours, Mon&ndash;Fri.
        </p>

        {/* Deep link */}
        <a
          href="arkline://invite"
          className="mt-4 inline-block text-[13px] text-white/30 underline hover:text-white/60"
        >
          Already renewed? Open ArkLine &rarr;
        </a>
      </div>
    </div>
  );
}

export const metadata = {
  title: 'Renew — Arkline',
  description: 'Reactivate your Arkline membership.',
  robots: { index: false, follow: false },
};
