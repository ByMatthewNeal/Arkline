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
            Effective May 4, 2026  •  Last updated May 4, 2026
          </p>
        </FadeIn>

        <FadeIn onMount delay={0.1} as="article" className="prose-ark mt-10 space-y-8 text-sm leading-relaxed text-ark-text-secondary">
          <section>
            <h2 className="text-lg font-semibold text-ark-text">1. Introduction</h2>
            <p className="mt-2">
              Arkline Technologies LLC (&quot;Arkline&quot;, &quot;we&quot;, &quot;our&quot;, or &quot;us&quot;) operates the Arkline mobile application and the website at arkline.io (collectively, the &quot;Service&quot;). This Privacy Policy explains what information we collect, how we use it, who we share it with, and the rights you have over your information.
            </p>
            <p className="mt-2">
              Arkline Technologies LLC is the data controller for the personal information we process about our users. We are a Wyoming-formed limited liability company whose registered office is c/o Republic Registered Agent LLC, 5830 E 2nd St Ste 7000, Casper, WY 82609, USA.
            </p>
            <p className="mt-2">
              This Policy applies to all users of the Service, worldwide. By creating an account or using the Service, you acknowledge that you have read and understood this Privacy Policy.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">2. Information We Collect</h2>
            <p className="mt-2">We collect the following categories of information:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Account information</strong> — your email address, hashed authentication credentials, and the invite code you used during signup.</li>
              <li><strong className="text-ark-text">Profile information</strong> — display name, avatar, and any optional profile fields you choose to provide.</li>
              <li><strong className="text-ark-text">Portfolio &amp; financial inputs</strong> — asset holdings, transactions, watchlists, dollar-cost-averaging schedules, and other financial preferences you enter into the Service. You provide this data directly; we do not connect to your brokerage, exchange, or bank accounts.</li>
              <li><strong className="text-ark-text">Subscription &amp; billing information</strong> — your subscription tier, status, and renewal dates. <strong className="text-ark-text">Card and payment details are collected and stored by our payment processor (Stripe) directly; Arkline never sees or stores your full payment card information.</strong></li>
              <li><strong className="text-ark-text">Usage &amp; diagnostics data</strong> — feature usage, app interactions, error logs, crash reports, and performance metrics, collected to operate and improve the Service.</li>
              <li><strong className="text-ark-text">Device &amp; technical information</strong> — device type, operating system version, app version, language, time zone, IP address (used for security and approximate location), and unique device identifiers.</li>
              <li><strong className="text-ark-text">Communications</strong> — messages you send to us (support requests, contact form submissions, email correspondence) and our replies.</li>
            </ul>
            <p className="mt-2">
              We do <strong className="text-ark-text">not</strong> knowingly collect government identifiers (Social Security Numbers, passport numbers, etc.), bank account numbers, brokerage credentials, biometric data, or precise GPS location.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">3. How We Use Your Information</h2>
            <p className="mt-2">We use your information to:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Provide, maintain, secure, and improve the Service.</li>
              <li>Authenticate you, validate invite codes, and prevent unauthorized access.</li>
              <li>Process subscription payments and manage billing.</li>
              <li>Generate the personalized portfolio analytics, risk scores, AI briefings, market insights, and DCA reminders you request.</li>
              <li>Send service-related communications (account notices, billing receipts, security alerts, DCA reminders, and material updates to legal terms).</li>
              <li>Respond to your support requests and questions.</li>
              <li>Detect, investigate, and prevent fraud, abuse, security incidents, and violations of our Terms of Service.</li>
              <li>Comply with legal obligations and respond to lawful requests from public authorities.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">4. Legal Bases for Processing (EEA / UK Users)</h2>
            <p className="mt-2">
              If you are located in the European Economic Area, the United Kingdom, or Switzerland, we rely on the following legal bases under the GDPR / UK GDPR:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Performance of a contract</strong> — to deliver the Service you have subscribed to.</li>
              <li><strong className="text-ark-text">Legitimate interests</strong> — to operate, secure, and improve the Service; to detect and prevent fraud or abuse; to communicate operationally with you.</li>
              <li><strong className="text-ark-text">Consent</strong> — for any optional processing where consent is required (e.g., non-essential analytics where applicable). You may withdraw consent at any time.</li>
              <li><strong className="text-ark-text">Legal obligation</strong> — to comply with applicable laws and respond to lawful requests.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">5. How We Share Information</h2>
            <p className="mt-2">
              We do not sell your personal information, and we do not share it for cross-context behavioral advertising. We share information only with the following categories of recipients:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Service providers (subprocessors)</strong> who process data on our behalf under written agreements that restrict use to providing the Service. Our primary subprocessors include:
                <ul className="mt-1 list-[circle] space-y-1 pl-5">
                  <li>Supabase, Inc. — database, authentication, and storage hosting (United States).</li>
                  <li>Stripe, Inc. — subscription billing and payment processing (United States).</li>
                  <li>Anthropic PBC — AI inference for portfolio analytics, risk scores, and market briefings (United States).</li>
                  <li>Vercel Inc. — website hosting (United States).</li>
                  <li>Apple Inc. — push notifications and crash diagnostics for iOS users (United States).</li>
                  <li>Email delivery and customer support providers used to send transactional email and respond to support requests.</li>
                </ul>
              </li>
              <li><strong className="text-ark-text">Third-party data providers</strong> — to fetch market data, prices, and economic indicators (e.g., CoinGecko, Alpha Vantage, FRED, Financial Modeling Prep, Taapi.io). These providers receive only generic, non-personal queries (e.g., a ticker symbol). They do not receive your account, identity, or portfolio holdings.</li>
              <li><strong className="text-ark-text">Legal &amp; safety</strong> — when we have a good-faith belief that disclosure is required to comply with law, valid legal process, or to protect the rights, property, or safety of Arkline, our users, or the public.</li>
              <li><strong className="text-ark-text">Corporate transactions</strong> — in connection with a merger, acquisition, financing, reorganization, or sale of assets, subject to the acquirer continuing to honor the commitments in this Policy.</li>
              <li><strong className="text-ark-text">With your consent</strong> — for any other disclosure, we will ask for your explicit consent first.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">6. International Data Transfers</h2>
            <p className="mt-2">
              Arkline is operated from the United States, and our subprocessors are primarily located in the United States. If you access the Service from outside the United States, your information will be transferred to, stored in, and processed in the United States and other countries where our subprocessors operate.
            </p>
            <p className="mt-2">
              For transfers of personal data from the EEA, the UK, or Switzerland to the United States, we rely on appropriate safeguards such as the European Commission&apos;s Standard Contractual Clauses and the UK International Data Transfer Addendum, where required by law. You may request a copy of the relevant transfer mechanism by contacting us at <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a>.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">7. Data Retention</h2>
            <p className="mt-2">
              We retain your information for as long as your account is active and for a reasonable period thereafter to fulfill the purposes described in this Policy, comply with legal obligations, resolve disputes, and enforce our agreements. Specifically:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Active accounts</strong> — for as long as the account exists.</li>
              <li><strong className="text-ark-text">After account deletion</strong> — most personal data is deleted within 30 days. Some records (billing records, security logs, and information required by law) may be retained for longer periods to comply with tax, accounting, fraud-prevention, and legal obligations, typically up to 7 years.</li>
              <li><strong className="text-ark-text">Backups</strong> — backups containing your data are overwritten in the ordinary course of our backup retention cycles, generally within 90 days of deletion from active systems.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">8. Data Security</h2>
            <p className="mt-2">
              We implement administrative, technical, and physical safeguards designed to protect your information, including: encryption in transit (TLS), encryption at rest, hashed passwords (PBKDF2), row-level security on our database, sensitive credential storage in the iOS Keychain, SSL certificate pinning for sensitive API calls, and regular security reviews. No method of transmission or storage is 100% secure, and we cannot guarantee absolute security. Promptly notify us at <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a> if you suspect any unauthorized access to your account.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">9. Your Rights</h2>
            <p className="mt-2">
              Depending on where you live, you may have some or all of the following rights with respect to your personal information:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Access</strong> — request a copy of the personal information we hold about you.</li>
              <li><strong className="text-ark-text">Correction</strong> — ask us to correct inaccurate or incomplete information.</li>
              <li><strong className="text-ark-text">Deletion</strong> — request deletion of your personal information, subject to certain legal exceptions.</li>
              <li><strong className="text-ark-text">Portability</strong> — receive your data in a structured, commonly used, machine-readable format.</li>
              <li><strong className="text-ark-text">Restriction or objection</strong> — restrict or object to certain processing activities.</li>
              <li><strong className="text-ark-text">Withdraw consent</strong> — withdraw any consent you have previously given, without affecting the lawfulness of prior processing.</li>
              <li><strong className="text-ark-text">Opt out of sales / sharing / targeted advertising</strong> — we do not sell or share your personal information for cross-context behavioral advertising, and we do not engage in targeted advertising. There is therefore nothing for you to opt out of in this respect.</li>
              <li><strong className="text-ark-text">Non-discrimination</strong> — we will not discriminate against you for exercising any of these rights.</li>
              <li><strong className="text-ark-text">Lodge a complaint</strong> — EEA, UK, and Swiss residents may lodge a complaint with their local data protection authority. We would appreciate the chance to address your concern first; please contact us at <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a>.</li>
            </ul>
            <p className="mt-2">
              You can exercise most rights directly within the Service (account settings allow you to review, update, export, or delete your data). For other requests, email us at <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a>. We will verify your identity before fulfilling any request and will respond within the timeframes required by applicable law (typically 30 days, with one possible extension where permitted).
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">10. California Privacy Rights</h2>
            <p className="mt-2">
              If you are a California resident, the California Consumer Privacy Act (CCPA), as amended by the California Privacy Rights Act (CPRA), provides you with the rights described in Section 9 above. In the preceding 12 months, we have collected the following categories of personal information: identifiers (email, account ID), commercial information (subscription status), internet or other electronic activity (usage data, device information), inferences (derived from your portfolio inputs to generate analytics), and customer-relations data (support communications). We do not sell or share personal information for cross-context behavioral advertising, and we do not knowingly collect or use sensitive personal information for purposes that would trigger an opt-out right under the CPRA.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">11. Children&apos;s Privacy</h2>
            <p className="mt-2">
              The Service is not directed to children under 18, and we do not knowingly collect personal information from children under 18. If you are under 18, please do not use the Service or provide any personal information to us. If you believe a child under 18 has provided us with personal information, please contact us at <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a> and we will take appropriate steps to delete it.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">12. Cookies &amp; Similar Technologies</h2>
            <p className="mt-2">
              Our website uses a minimal number of cookies and similar technologies, limited to those strictly necessary for the website to function (e.g., session and authentication cookies) and basic analytics about how the website is used. We do not use cookies for advertising or cross-site tracking. Most browsers allow you to refuse or delete cookies via their settings; doing so may affect parts of the Service that require authentication. The mobile application does not use browser cookies.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">13. Do Not Track &amp; Global Privacy Control</h2>
            <p className="mt-2">
              We do not engage in practices that would require us to respond to a Do Not Track (DNT) browser signal or a Global Privacy Control (GPC) signal. Because we do not sell or share your personal information for cross-context behavioral advertising, there is no behavior to opt out of via these signals.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">14. Third-Party Links &amp; Services</h2>
            <p className="mt-2">
              The Service may contain links to third-party websites or services we do not control. This Privacy Policy does not apply to those third parties. We encourage you to review the privacy policies of any third party you interact with through the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">15. Changes to This Policy</h2>
            <p className="mt-2">
              We may update this Privacy Policy from time to time to reflect changes in our practices or for legal, operational, or regulatory reasons. When we make material changes, we will notify you by email and/or by posting a prominent notice within the Service prior to the changes taking effect. The &quot;Last updated&quot; date at the top of this Policy indicates when it was last revised.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">16. Contact Us</h2>
            <p className="mt-2">
              For privacy questions, requests, or complaints, contact us at:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Email (privacy matters): <a href="mailto:privacy@arkline.io" className="text-ark-primary hover:underline">privacy@arkline.io</a></li>
              <li>Email (general support): <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a></li>
              <li>Mail: Arkline Technologies LLC, c/o Republic Registered Agent LLC, 5830 E 2nd St Ste 7000, Casper, WY 82609, USA</li>
              <li>Or via our <a href="/contact" className="text-ark-primary hover:underline">contact page</a></li>
            </ul>
          </section>
        </FadeIn>
      </div>
    </section>
  );
}
