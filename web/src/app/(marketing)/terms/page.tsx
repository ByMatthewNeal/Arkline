'use client';

import { FadeIn } from '@/components/marketing/fade-in';

export default function TermsOfServicePage() {
  return (
    <section className="pt-32 pb-16 sm:pt-40 sm:pb-20">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <FadeIn onMount>
          <h1 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
            Terms of Service
          </h1>
          <p className="mt-2 text-sm text-ark-text-tertiary">
            Effective March 5, 2026
          </p>
        </FadeIn>

        <FadeIn onMount delay={0.1} as="article" className="prose-ark mt-10 space-y-8 text-sm leading-relaxed text-ark-text-secondary">
          <section>
            <h2 className="text-lg font-semibold text-ark-text">1. Acceptance of Terms</h2>
            <p className="mt-2">
              By accessing or using Arkline (&quot;the Service&quot;), you agree to be bound by these Terms of Service. If you do not agree, do not use the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">2. Description of Service</h2>
            <p className="mt-2">
              Arkline is a financial tracking and analytics platform that provides portfolio management, multi-factor risk scoring, market data aggregation, and AI-powered insights. The Service is available as an iOS application and companion website.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">3. Not Financial Advice</h2>
            <p className="mt-2">
              Arkline is an informational tool only. Nothing in the Service constitutes financial, investment, tax, or legal advice. Risk scores, AI briefings, DCA reminders, and all other outputs are for educational and informational purposes only. You are solely responsible for your own investment decisions. Always consult a qualified financial advisor before making investment decisions.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">4. User Accounts</h2>
            <p className="mt-2">
              You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account. You must provide accurate information when creating an account and promptly update it if it changes.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">5. Acceptable Use</h2>
            <p className="mt-2">You agree not to:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Use the Service for any unlawful purpose.</li>
              <li>Attempt to reverse-engineer, decompile, or disassemble any part of the Service.</li>
              <li>Interfere with or disrupt the Service or its infrastructure.</li>
              <li>Scrape, crawl, or automatically extract data from the Service.</li>
              <li>Resell, redistribute, or sublicense access to the Service.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">6. Intellectual Property</h2>
            <p className="mt-2">
              All content, branding, design, and code comprising the Service are owned by Arkline and protected by applicable intellectual property laws. You retain ownership of the data you input into the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">7. Third-Party Data</h2>
            <p className="mt-2">
              The Service aggregates data from third-party providers (including CoinGecko, Alpha Vantage, FRED, and others). We do not guarantee the accuracy, completeness, or timeliness of third-party data. Third-party data is provided &quot;as is&quot; and subject to the respective provider&apos;s terms.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">8. Subscription &amp; Billing</h2>
            <p className="mt-2">
              Certain features may require a paid subscription. Subscription terms, pricing, and billing cycles are presented at the time of purchase. You may cancel your subscription at any time; access continues through the end of the current billing period.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">9. Limitation of Liability</h2>
            <p className="mt-2">
              To the fullest extent permitted by law, Arkline shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data, or investment losses, arising from your use of the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">10. Disclaimer of Warranties</h2>
            <p className="mt-2">
              The Service is provided &quot;as is&quot; and &quot;as available&quot; without warranties of any kind, whether express or implied. We do not warrant that the Service will be uninterrupted, error-free, or free of harmful components.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">11. Termination</h2>
            <p className="mt-2">
              We reserve the right to suspend or terminate your access to the Service at any time for violation of these Terms or for any other reason at our sole discretion. You may terminate your account at any time by contacting us.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">12. Changes to Terms</h2>
            <p className="mt-2">
              We may revise these Terms at any time. Material changes will be communicated by posting the updated Terms with a revised effective date. Continued use of the Service after changes constitutes acceptance of the new Terms.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">13. Contact Us</h2>
            <p className="mt-2">
              If you have questions about these Terms, please reach out via our{' '}
              <a href="/contact" className="text-ark-primary hover:underline">contact page</a>.
            </p>
          </section>
        </FadeIn>
      </div>
    </section>
  );
}
