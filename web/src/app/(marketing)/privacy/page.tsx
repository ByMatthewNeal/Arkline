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
            Effective May 12, 2026  &bull;  Last updated May 12, 2026
          </p>
        </FadeIn>

        <FadeIn onMount delay={0.1} as="article" className="prose-ark mt-10 space-y-8 text-sm leading-relaxed text-ark-text-secondary">
          <section>
            <p className="mt-2">
              This Privacy Policy describes how Arkline Technologies LLC (&quot;Arkline,&quot; &quot;we,&quot; &quot;us,&quot; or &quot;our&quot;) collects, uses, and shares information when you use our website at arkline.io and our iOS application (collectively, the &quot;Service&quot;).
            </p>
            <p className="mt-2">
              By using the Service, you agree to the collection and use of information as described in this policy.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">1. Information We Collect</h2>

            <p className="mt-4"><strong className="text-ark-text">Information you provide</strong></p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Account information.</strong> When you create an account, we collect your email address, name, and a password (which is hashed and never stored in plain text).</li>
              <li><strong className="text-ark-text">Profile information.</strong> Optional details you choose to add to your profile, such as a display name or avatar.</li>
              <li><strong className="text-ark-text">Portfolio data.</strong> Financial information you choose to add to track your portfolio, including asset holdings, transaction history, cost basis, and notes. This information is entered manually by you. We do not connect to any exchange, brokerage, or wallet.</li>
              <li><strong className="text-ark-text">Communications.</strong> When you contact us through support channels, we keep records of those communications, including your email address and the contents of the message.</li>
              <li><strong className="text-ark-text">Feedback and survey responses.</strong> If you submit feedback, ratings, or participate in surveys, we collect what you share.</li>
            </ul>

            <p className="mt-4"><strong className="text-ark-text">Information collected automatically</strong></p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Device and usage information.</strong> When you use our Service, we collect technical information about your device (model, operating system version, app version, IP address) and how you interact with the Service (features used, pages viewed, session duration, crashes).</li>
              <li><strong className="text-ark-text">Push notification tokens.</strong> If you enable push notifications, we collect a device-specific token from Apple Push Notification service to send you notifications.</li>
              <li><strong className="text-ark-text">Cookies and similar technologies.</strong> Our website uses essential cookies to keep you signed in and to remember your preferences. We do not use advertising or cross-site tracking cookies.</li>
            </ul>

            <p className="mt-4"><strong className="text-ark-text">Information from third parties</strong></p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Payment information.</strong> We use Stripe to process payments. Stripe collects your payment details (card number, billing address) directly. We do not receive or store your full card number. We receive only your Stripe customer ID and your subscription status (active, past due, canceled, trialing). For more information, see Stripe&apos;s Privacy Policy at stripe.com/privacy.</li>
              <li><strong className="text-ark-text">AI conversation data.</strong> When you use our AI Briefings feature, your queries and contextual information (such as your portfolio composition for personalized briefings) are sent to Anthropic for processing through their Claude API. Anthropic&apos;s data handling is governed by their Commercial Terms and Privacy Policy at anthropic.com/legal.</li>
            </ul>

            <p className="mt-4"><strong className="text-ark-text">Information we do NOT collect</strong></p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>We do not collect or store your wallet private keys, exchange API keys, or banking credentials.</li>
              <li>We do not connect directly to your exchange or brokerage accounts.</li>
              <li>We do not collect biometric data. Face ID and Touch ID are processed entirely on your device by iOS and we never receive that data.</li>
              <li>We do not collect your location.</li>
              <li>We do not use third-party advertising trackers.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">2. How We Use Your Information</h2>
            <p className="mt-2">We use the information we collect to:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Operate, maintain, and improve the Service</li>
              <li>Authenticate you and manage your account</li>
              <li>Process payments and manage your subscription through Stripe</li>
              <li>Generate personalized market briefings, risk analyses, and portfolio insights using AI</li>
              <li>Send you transactional communications (account confirmations, billing receipts, password resets, security alerts)</li>
              <li>Send push notifications you have opted into (price alerts, briefing readiness, DCA reminders)</li>
              <li>Respond to your support requests</li>
              <li>Detect, prevent, and address fraud, abuse, security incidents, and technical issues</li>
              <li>Comply with legal obligations and enforce our Terms of Service</li>
            </ul>
            <p className="mt-2">
              We do not sell your personal information to third parties. We do not use your data to train AI models.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">3. How We Share Your Information</h2>
            <p className="mt-2">We share information only as described below.</p>

            <p className="mt-4"><strong className="text-ark-text">Service providers</strong></p>
            <p className="mt-2">
              We use the following third-party services to operate Arkline. Each receives only the information they need to perform their function and is bound by contractual confidentiality and data-handling obligations.
            </p>
            <div className="mt-4 overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-ark-border">
                    <th className="pb-2 pr-4 font-semibold text-ark-text">Provider</th>
                    <th className="pb-2 pr-4 font-semibold text-ark-text">Purpose</th>
                    <th className="pb-2 font-semibold text-ark-text">Data shared</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-ark-border">
                  <tr>
                    <td className="py-2 pr-4 align-top font-medium text-ark-text">Supabase</td>
                    <td className="py-2 pr-4 align-top">Authentication, database, file storage</td>
                    <td className="py-2 align-top">Account info, profile data, portfolio data, app usage data</td>
                  </tr>
                  <tr>
                    <td className="py-2 pr-4 align-top font-medium text-ark-text">Stripe</td>
                    <td className="py-2 pr-4 align-top">Payment processing and subscription management</td>
                    <td className="py-2 align-top">Email, customer ID, subscription status (Stripe collects card data directly)</td>
                  </tr>
                  <tr>
                    <td className="py-2 pr-4 align-top font-medium text-ark-text">Anthropic</td>
                    <td className="py-2 pr-4 align-top">AI Briefings and Chat (Claude API)</td>
                    <td className="py-2 align-top">Your queries and relevant portfolio context for the duration of the request</td>
                  </tr>
                  <tr>
                    <td className="py-2 pr-4 align-top font-medium text-ark-text">Apple Push Notification service</td>
                    <td className="py-2 pr-4 align-top">Sending push notifications to your iOS device</td>
                    <td className="py-2 align-top">Device token, notification payloads</td>
                  </tr>
                  <tr>
                    <td className="py-2 pr-4 align-top font-medium text-ark-text">Market data providers (CoinGecko, Alpha Vantage, FRED, FMP, Taapi.io, Coinglass)</td>
                    <td className="py-2 pr-4 align-top">Public market data feeds</td>
                    <td className="py-2 align-top">No personal information &mdash; only the asset symbols you are viewing</td>
                  </tr>
                  <tr>
                    <td className="py-2 pr-4 align-top font-medium text-ark-text">Hosting and infrastructure providers</td>
                    <td className="py-2 pr-4 align-top">Running our servers and CDN</td>
                    <td className="py-2 align-top">Technical request data only</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p className="mt-4">
              We do not share your information with advertisers, data brokers, or any party for marketing purposes.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Legal disclosures</strong></p>
            <p className="mt-2">
              We may disclose your information if required by law, subpoena, or other legal process, or if we believe disclosure is necessary to (a) comply with a legal obligation, (b) protect our rights, property, or safety, or (c) investigate or prevent fraud or security issues.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Business transfers</strong></p>
            <p className="mt-2">
              If we are involved in a merger, acquisition, or sale of all or part of our assets, your information may be transferred as part of that transaction. We will notify you before your information becomes subject to a different privacy policy.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">4. How We Protect Your Information</h2>
            <p className="mt-2">We take security seriously. Our protections include:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>All data encrypted in transit (TLS) and at rest</li>
              <li>Passwords hashed using PBKDF2-SHA256 and never stored in plain text</li>
              <li>Sensitive on-device data stored in the iOS Keychain</li>
              <li>SSL certificate pinning on critical API connections</li>
              <li>Row-level security policies on our Supabase database, so users can access only their own data</li>
              <li>Application-level authentication required for every API request</li>
              <li>Regular security reviews and a documented internal security audit</li>
            </ul>
            <p className="mt-2">
              No system is perfectly secure. If we become aware of a security breach affecting your information, we will notify you in accordance with applicable law.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">5. Data Retention</h2>
            <p className="mt-2">
              We retain your information for as long as your account is active. If you delete your account, we delete or anonymize your personal information within 30 days, except where we are required to retain it for legal, tax, accounting, or fraud-prevention purposes.
            </p>
            <p className="mt-2">
              Backup copies may persist for a limited period, after which they are permanently deleted.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">6. Your Rights</h2>
            <p className="mt-2">Depending on where you live, you may have the following rights regarding your personal information:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Access</strong> &mdash; request a copy of the information we hold about you</li>
              <li><strong className="text-ark-text">Correction</strong> &mdash; request that we correct inaccurate information</li>
              <li><strong className="text-ark-text">Deletion</strong> &mdash; request that we delete your information (see &quot;Account deletion&quot; below)</li>
              <li><strong className="text-ark-text">Portability</strong> &mdash; request a copy of your data in a portable format</li>
              <li><strong className="text-ark-text">Objection or restriction</strong> &mdash; object to or restrict certain processing</li>
              <li><strong className="text-ark-text">Withdrawal of consent</strong> &mdash; withdraw consent where processing is based on consent</li>
            </ul>
            <p className="mt-2">
              To exercise any of these rights, email <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a>. We will respond within the time required by applicable law (generally 30 days).
            </p>

            <p className="mt-4"><strong className="text-ark-text">Account deletion</strong></p>
            <p className="mt-2">
              You may delete your account at any time from within the iOS app at Settings &rarr; Account &rarr; Delete Account, or by emailing <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a>. Deletion removes your portfolio data, account information, and AI conversation history within 30 days.
            </p>

            <p className="mt-4"><strong className="text-ark-text">California residents (CCPA / CPRA)</strong></p>
            <p className="mt-2">
              If you are a California resident, you have the right to know what personal information we collect, sell, or share about you, and to request deletion. We do not sell or share personal information for cross-context behavioral advertising. To exercise your rights, email <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a>.
            </p>

            <p className="mt-4"><strong className="text-ark-text">EU and UK residents (GDPR / UK GDPR)</strong></p>
            <p className="mt-2">
              If you are in the EU, EEA, or UK, our legal bases for processing your information are:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Performance of a contract (operating the Service for you)</li>
              <li>Legitimate interests (improving the Service, preventing fraud)</li>
              <li>Compliance with legal obligations</li>
              <li>Your consent (where required, e.g., for non-essential cookies)</li>
            </ul>
            <p className="mt-2">
              You have the right to lodge a complaint with your local data protection authority.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">7. International Data Transfers</h2>
            <p className="mt-2">
              We are based in Wyoming, United States. Information we collect may be processed in the United States and other countries where our service providers operate. By using the Service, you consent to your information being transferred to and processed in countries that may have different data protection laws than your country.
            </p>
            <p className="mt-2">
              For users in the EU/EEA/UK, we rely on Standard Contractual Clauses or other approved transfer mechanisms when transferring data outside those regions.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">8. Children&apos;s Privacy</h2>
            <p className="mt-2">
              Arkline is not intended for use by anyone under 18. We do not knowingly collect personal information from anyone under 18. If you believe a child under 18 has provided us with personal information, contact <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a> and we will delete it.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">9. Third-Party Links</h2>
            <p className="mt-2">
              The Service may contain links to third-party websites or services. We are not responsible for the privacy practices of those third parties. We encourage you to review their privacy policies before sharing information with them.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">10. Do Not Track</h2>
            <p className="mt-2">
              Our Service does not respond to Do Not Track browser signals because there is currently no industry consensus on how to interpret them.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">11. Changes to This Policy</h2>
            <p className="mt-2">
              We may update this Privacy Policy from time to time. If we make material changes, we will notify you by email (to the address associated with your account) or by posting a prominent notice in the Service before the changes take effect. The &quot;Last updated&quot; date at the top of this policy reflects the most recent revision.
            </p>
            <p className="mt-2">
              Continued use of the Service after changes take effect means you accept the updated policy.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">12. Contact Us</h2>
            <p className="mt-2">For privacy questions, requests, or complaints, contact:</p>
            <p className="mt-2">
              <strong className="text-ark-text">Arkline Technologies LLC</strong><br />
              1908 Thomes Ave STE 63374<br />
              Cheyenne, WY 82001<br />
              Email: <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a>
            </p>
          </section>
        </FadeIn>
      </div>
    </section>
  );
}
