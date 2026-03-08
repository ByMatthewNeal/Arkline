'use client';

import { FadeIn } from '@/components/marketing/fade-in';

export default function PrivacyPolicyPage() {
  return (
    <section className="pt-32 pb-16 sm:pt-40 sm:pb-20">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <FadeIn onMount>
          <h1 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
            Privacy Policy
          </h1>
          <p className="mt-2 text-sm text-ark-text-tertiary">
            Effective March 5, 2026
          </p>
        </FadeIn>

        <FadeIn onMount delay={0.1} as="article" className="prose-ark mt-10 space-y-8 text-sm leading-relaxed text-ark-text-secondary">
          <section>
            <h2 className="text-lg font-semibold text-ark-text">1. Introduction</h2>
            <p className="mt-2">
              Arkline (&quot;we&quot;, &quot;our&quot;, or &quot;us&quot;) operates the Arkline mobile application and website. This Privacy Policy explains how we collect, use, and protect your information when you use our services.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">2. Information We Collect</h2>
            <p className="mt-2">We may collect the following types of information:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Account information</strong> — email address and authentication credentials when you create an account.</li>
              <li><strong className="text-ark-text">Portfolio data</strong> — asset holdings, transactions, and preferences you enter into the app.</li>
              <li><strong className="text-ark-text">Usage data</strong> — app interactions, feature usage, and crash reports to improve our service.</li>
              <li><strong className="text-ark-text">Device information</strong> — device type, operating system, and app version.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">3. How We Use Your Information</h2>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Provide, maintain, and improve our services.</li>
              <li>Generate personalized risk scores, AI briefings, and market insights.</li>
              <li>Send service-related notifications (e.g., DCA reminders, risk alerts).</li>
              <li>Respond to support requests and contact form submissions.</li>
              <li>Detect and prevent fraud or abuse.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">4. Data Storage &amp; Security</h2>
            <p className="mt-2">
              Your data is stored securely using Supabase infrastructure with row-level security, encryption at rest, and encryption in transit (TLS). Sensitive credentials are stored in the iOS Keychain. We do not sell your personal data to third parties.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">5. Third-Party Services</h2>
            <p className="mt-2">
              We use third-party APIs to provide market data, pricing, and AI features (including CoinGecko, Alpha Vantage, FRED, and Anthropic Claude). These services receive only the minimum data necessary to fulfill their function. We encourage you to review their respective privacy policies.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">6. Data Retention</h2>
            <p className="mt-2">
              We retain your data for as long as your account is active. You may request deletion of your account and associated data at any time by contacting us.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">7. Your Rights</h2>
            <p className="mt-2">
              Depending on your jurisdiction, you may have the right to access, correct, delete, or export your personal data. To exercise these rights, contact us at the address below.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">8. Changes to This Policy</h2>
            <p className="mt-2">
              We may update this Privacy Policy from time to time. We will notify you of material changes by posting the updated policy on this page with a revised effective date.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">9. Contact Us</h2>
            <p className="mt-2">
              If you have questions about this Privacy Policy, please reach out via our{' '}
              <a href="/contact" className="text-ark-primary hover:underline">contact page</a>.
            </p>
          </section>
        </FadeIn>
      </div>
    </section>
  );
}
