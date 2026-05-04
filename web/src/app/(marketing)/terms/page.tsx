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
            Effective May 4, 2026  •  Last updated May 4, 2026
          </p>
        </FadeIn>

        <FadeIn onMount delay={0.1} as="article" className="prose-ark mt-10 space-y-8 text-sm leading-relaxed text-ark-text-secondary">
          <section>
            <h2 className="text-lg font-semibold text-ark-text">1. Agreement to These Terms</h2>
            <p className="mt-2">
              These Terms of Service (&quot;Terms&quot;) form a binding agreement between you and Arkline Technologies LLC, a Wyoming limited liability company (&quot;Arkline&quot;, &quot;we&quot;, &quot;us&quot;, or &quot;our&quot;), governing your access to and use of the Arkline mobile application, the website at arkline.io, and any related services (collectively, the &quot;Service&quot;). By creating an account, completing checkout, or otherwise using the Service, you agree to these Terms and to our <a href="/privacy" className="text-ark-primary hover:underline">Privacy Policy</a>. If you do not agree, do not use the Service.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">PLEASE READ THESE TERMS CAREFULLY. THEY INCLUDE A NO-REFUND POLICY (SECTION 6), DISCLAIMERS THAT THE SERVICE IS NOT FINANCIAL ADVICE (SECTION 11), LIMITATIONS ON OUR LIABILITY (SECTION 14), AND A BINDING ARBITRATION AND CLASS-ACTION WAIVER PROVISION (SECTION 18) THAT AFFECT YOUR LEGAL RIGHTS.</strong>
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">2. Eligibility</h2>
            <p className="mt-2">
              You must be at least 18 years old, capable of entering into a binding contract, and not barred from receiving the Service under the laws of the United States or any other applicable jurisdiction. The Service is not available to anyone previously suspended or removed from the Service. You represent and warrant that all information you provide during signup is accurate and current.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">3. The Service</h2>
            <p className="mt-2">
              Arkline is an informational and analytics platform that provides cryptocurrency and traditional-market tracking, portfolio management, multi-factor risk scoring, dollar-cost-averaging reminders, and AI-powered briefings. The Service is delivered as an iOS application and a companion website. Access is invite-only; a valid invite code and an active subscription are required to use most features.
            </p>
            <p className="mt-2">
              We may modify, add, or remove features at any time, in our discretion, with reasonable notice for material reductions in functionality where practicable.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">4. Accounts</h2>
            <p className="mt-2">
              To use the Service, you must create an account using a valid email address and complete email verification. You are responsible for maintaining the confidentiality of your credentials and for all activities that occur under your account. You must notify us immediately of any unauthorized use. We may refuse, suspend, or revoke any invite code or account at any time, in our discretion, for any reason consistent with these Terms.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">5. Subscriptions, Pricing &amp; Billing</h2>
            <p className="mt-2">
              The Service is offered on a paid subscription basis. Subscription fees are charged in advance through our payment processor, Stripe. By subscribing, you authorize us (through Stripe) to charge the payment method you provide for the applicable fees, taxes, and any renewals.
            </p>
            <p className="mt-2"><strong className="text-ark-text">Current pricing:</strong></p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Founding Member</strong> (limited to the first 150 paying subscribers): $39.99 USD per month or $400 USD per year. The Founding Member rate is locked in for the duration of your continuous, uninterrupted subscription. If you cancel and later resubscribe, you will be subject to the then-current Standard rate.</li>
              <li><strong className="text-ark-text">Standard Membership</strong> (after the first 150 Founding Member spots are filled, or for any new subscribers thereafter): $59.99 USD per month or $650 USD per year.</li>
            </ul>
            <p className="mt-2">
              <strong className="text-ark-text">Auto-renewal.</strong> Your subscription renews automatically at the end of each billing period at the then-current price for your tier, until you cancel. We will email you a receipt after each successful charge.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Price changes.</strong> We may change Standard subscription prices for new subscribers at any time. For existing subscribers, we will provide at least 30 days&apos; advance notice by email before any price increase takes effect, and the new price will apply only to billing periods beginning after the notice period. If you do not agree to the new price, you may cancel before it takes effect.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Taxes.</strong> Stated prices do not include taxes. You are responsible for any sales tax, VAT, GST, or similar taxes applicable to your subscription, which may be added to your invoice.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Failed payments.</strong> If a payment fails, we may retry the charge and may suspend or downgrade your access until payment is successful. Continued non-payment may result in account termination.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">6. No Refunds</h2>
            <p className="mt-2">
              <strong className="text-ark-text">All payments are final and non-refundable.</strong> Subscription fees are not pro-rated. If you cancel during a billing period, you will retain access through the end of that billing period and will not be charged again, but you are not entitled to any refund of the unused portion. This policy applies to monthly and annual subscriptions, Founding Member and Standard tiers alike, and to renewals as well as initial purchases. Where applicable law requires us to offer a statutory withdrawal or cooling-off right (for example, certain consumer-protection laws in the EEA or UK), you expressly request that the Service begin immediately upon purchase and acknowledge that, by doing so, you may lose any statutory right of withdrawal once you begin using the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">7. Cancellation</h2>
            <p className="mt-2">
              You may cancel your subscription at any time from your account settings or by contacting <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a>. Cancellation takes effect at the end of the current billing period. After cancellation, your account remains accessible in a read-only or limited state until the end of the paid period, after which premium features become unavailable.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">8. Acceptable Use</h2>
            <p className="mt-2">You agree not to:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Use the Service for any unlawful purpose or in violation of any applicable law or regulation.</li>
              <li>Attempt to reverse-engineer, decompile, disassemble, or otherwise derive source code from the Service, except to the extent such restriction is prohibited by applicable law.</li>
              <li>Interfere with, disrupt, overload, or attack the Service or its infrastructure, including by introducing malware, conducting denial-of-service attacks, or probing security mechanisms.</li>
              <li>Scrape, crawl, or use automated means to extract data from the Service in bulk.</li>
              <li>Resell, redistribute, sublicense, or share access to the Service with anyone other than the authorized account holder.</li>
              <li>Use the Service to develop a competing product or service, or to benchmark the Service for the purpose of building or improving a competing product.</li>
              <li>Bypass invite-code restrictions, billing controls, or other access mechanisms.</li>
              <li>Submit false, misleading, infringing, or unlawful content through the Service or its AI features.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">9. Your Content &amp; License to Us</h2>
            <p className="mt-2">
              You retain ownership of the data and inputs you submit to the Service (your &quot;User Content&quot;), including your portfolio entries and watchlists. You grant Arkline a worldwide, non-exclusive, royalty-free license to host, store, transmit, and process your User Content solely as necessary to operate, secure, and improve the Service for you. We do not claim ownership of your User Content and we do not use it to train third-party AI models.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">10. Our Intellectual Property</h2>
            <p className="mt-2">
              The Service and all content and materials we provide — including software, designs, logos, copy, graphics, and trademarks — are owned by Arkline Technologies LLC or our licensors and are protected by intellectual property laws. We grant you a limited, non-exclusive, non-transferable, revocable license to use the Service in accordance with these Terms for your own personal, non-commercial use. All rights not expressly granted are reserved.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">11. Not Financial Advice; No Fiduciary Relationship</h2>
            <p className="mt-2">
              <strong className="text-ark-text">Arkline is an informational and analytical tool only. Nothing produced by, displayed in, or accessed through the Service constitutes financial, investment, tax, legal, accounting, or other professional advice, and nothing is a recommendation, solicitation, or offer to buy, sell, or hold any security, cryptocurrency, or other asset.</strong> Risk scores, AI briefings, market data, DCA reminders, projections, and all other outputs are generated algorithmically or aggregated from public sources and are provided for educational and informational purposes only.
            </p>
            <p className="mt-2">
              You are solely responsible for your own investment decisions and for consulting a qualified, licensed financial advisor before acting on any information you obtain from the Service. Arkline is not a registered investment adviser, broker-dealer, or financial planner. Your use of the Service does not create any fiduciary, advisory, or other professional relationship between you and Arkline.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Risk disclosure.</strong> Investing involves risk, including the potential loss of principal. Cryptocurrency markets in particular are highly volatile and may experience extreme price movements, liquidity disruptions, and total loss of value. Past performance is not indicative of future results.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">12. Third-Party Data &amp; Services</h2>
            <p className="mt-2">
              The Service aggregates data from third-party providers (including, without limitation, CoinGecko, Alpha Vantage, FRED, Financial Modeling Prep, and Taapi.io) and uses third-party AI services (including Anthropic). We do not warrant the accuracy, completeness, timeliness, or availability of any third-party data or service. Third-party data and services are provided &quot;as is&quot; and may be subject to the respective provider&apos;s own terms and rate limits, which may change without notice. Arkline is not responsible for errors, omissions, delays, or unavailability caused by third parties.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">13. Disclaimer of Warranties</h2>
            <p className="mt-2">
              <strong className="text-ark-text">THE SERVICE IS PROVIDED &quot;AS IS&quot; AND &quot;AS AVAILABLE&quot; WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS, IMPLIED, OR STATUTORY.</strong> To the fullest extent permitted by applicable law, Arkline disclaims all warranties, including warranties of merchantability, fitness for a particular purpose, title, non-infringement, accuracy, and uninterrupted or error-free operation. We do not warrant that the Service will meet your requirements, that it will be free of viruses or harmful components, or that any defects will be corrected. No advice or information obtained from us or through the Service creates any warranty not expressly stated in these Terms.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">14. Limitation of Liability</h2>
            <p className="mt-2">
              <strong className="text-ark-text">TO THE FULLEST EXTENT PERMITTED BY LAW, IN NO EVENT WILL ARKLINE TECHNOLOGIES LLC OR ITS OFFICERS, MEMBERS, EMPLOYEES, AGENTS, OR LICENSORS BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, INCLUDING WITHOUT LIMITATION DAMAGES FOR LOST PROFITS, LOST REVENUE, LOST DATA, BUSINESS INTERRUPTION, OR INVESTMENT LOSSES, ARISING OUT OF OR RELATED TO YOUR USE OF (OR INABILITY TO USE) THE SERVICE, REGARDLESS OF THE LEGAL THEORY (CONTRACT, TORT, STATUTE, OR OTHERWISE) AND EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.</strong>
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">OUR TOTAL CUMULATIVE LIABILITY TO YOU FOR ALL CLAIMS ARISING FROM OR RELATING TO THE SERVICE WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID US FOR THE SERVICE IN THE 12 MONTHS BEFORE THE EVENT GIVING RISE TO THE CLAIM OR (B) ONE HUNDRED U.S. DOLLARS ($100).</strong>
            </p>
            <p className="mt-2">
              Some jurisdictions do not allow the exclusion or limitation of certain damages; in those jurisdictions, our liability is limited to the maximum extent permitted by law.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">15. Indemnification</h2>
            <p className="mt-2">
              You agree to defend, indemnify, and hold harmless Arkline Technologies LLC and its officers, members, employees, and agents from and against any claims, damages, liabilities, costs, and expenses (including reasonable attorneys&apos; fees) arising out of or related to: (a) your use of the Service in violation of these Terms or applicable law; (b) your User Content; or (c) your violation of any third-party right, including intellectual property or privacy rights.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">16. Termination &amp; Suspension</h2>
            <p className="mt-2">
              We may suspend or terminate your access to the Service, in whole or in part, at any time and without prior notice, if we reasonably believe you have violated these Terms, if continued provision of the Service to you would expose us to legal or operational risk, or for non-payment. You may terminate your account at any time as described in Section 7. Upon termination, your right to use the Service ceases immediately, and Sections 6, 9, 10, 11, 13, 14, 15, 18, 19, and 20 will survive.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">17. App Store Terms</h2>
            <p className="mt-2">
              If you accessed the Service through Apple&apos;s App Store, you acknowledge that these Terms are between you and Arkline only, and not with Apple. Apple is not responsible for the Service or its content. To the maximum extent permitted by applicable law, Apple has no warranty obligation whatsoever with respect to the Service. In the event of any failure of the Service to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price (if any) for the application; beyond that, Apple has no other warranty obligation. Apple and its subsidiaries are third-party beneficiaries of these Terms and may enforce them against you.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">18. Governing Law; Arbitration; Class-Action Waiver</h2>
            <p className="mt-2">
              <strong className="text-ark-text">Governing law.</strong> These Terms and any dispute arising out of or related to these Terms or the Service are governed by the laws of the State of Wyoming, USA, without regard to its conflict-of-laws principles. The United Nations Convention on Contracts for the International Sale of Goods does not apply.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Informal resolution first.</strong> Before filing any claim, you and Arkline agree to attempt in good faith to resolve the dispute informally for at least 60 days, by sending written notice to <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a> describing the claim and the relief sought.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Binding arbitration.</strong> If the dispute is not resolved informally, you and Arkline agree that any controversy or claim arising out of or relating to these Terms or the Service will be resolved by final, binding arbitration administered by the American Arbitration Association (AAA) under its Consumer Arbitration Rules. The arbitration will be conducted in English, by a single arbitrator, on a documents-only basis where practicable, with any in-person hearing held in New York County, New York, or another location mutually agreed by the parties. Judgment on the arbitration award may be entered in any court having jurisdiction.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Class-action waiver.</strong> You and Arkline each agree to bring any claim only in your or its individual capacity and not as a plaintiff or class member in any purported class, collective, or representative proceeding. The arbitrator may not consolidate more than one person&apos;s claims or preside over any form of representative or class proceeding.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Exceptions.</strong> Either party may bring (i) a claim in small-claims court for disputes within that court&apos;s jurisdiction, or (ii) an action seeking injunctive or equitable relief for actual or threatened infringement of intellectual property rights. If the class-action waiver is held unenforceable as to any portion of a dispute, that portion will proceed in court while all other claims will continue in arbitration.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">If you reside outside the United States,</strong> mandatory consumer-protection laws of your country of residence may apply notwithstanding the choice of Wyoming law and the arbitration provisions above, to the extent those laws give you protections that cannot be waived by contract.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">19. Changes to These Terms</h2>
            <p className="mt-2">
              We may update these Terms from time to time. When we make material changes, we will notify you by email and/or by a prominent notice within the Service at least 30 days before the changes take effect (or sooner where required by law for security or compliance reasons). Your continued use of the Service after the new Terms become effective constitutes your acceptance of the changes. If you do not agree to the changes, you must stop using the Service before they take effect.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">20. General</h2>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Entire agreement.</strong> These Terms and the Privacy Policy constitute the entire agreement between you and Arkline regarding the Service and supersede all prior or contemporaneous agreements on the subject.</li>
              <li><strong className="text-ark-text">Severability.</strong> If any provision is held unenforceable, the remaining provisions will remain in full force and effect.</li>
              <li><strong className="text-ark-text">No waiver.</strong> Our failure to enforce any provision is not a waiver of our right to do so later.</li>
              <li><strong className="text-ark-text">Assignment.</strong> You may not assign these Terms without our prior written consent. We may assign these Terms in connection with a merger, acquisition, or sale of substantially all of our assets, or to an affiliate.</li>
              <li><strong className="text-ark-text">Force majeure.</strong> We are not liable for any delay or failure caused by events beyond our reasonable control, including natural disasters, acts of war or terrorism, civil unrest, government action, network or power outages, or third-party service failures.</li>
              <li><strong className="text-ark-text">Notices.</strong> We may give you notices via email to the address associated with your account or by posting within the Service. You may give us notice at <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a> or by mail to the address below.</li>
              <li><strong className="text-ark-text">Relationship.</strong> These Terms do not create any agency, partnership, joint venture, or employment relationship between you and Arkline.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">21. Contact Us</h2>
            <p className="mt-2">
              For questions about these Terms, contact us at:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Email: <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a></li>
              <li>Mail: Arkline Technologies LLC, c/o Republic Registered Agent LLC, 5830 E 2nd St Ste 7000, Casper, WY 82609, USA</li>
              <li>Or via our <a href="/contact" className="text-ark-primary hover:underline">contact page</a></li>
            </ul>
          </section>
        </FadeIn>
      </div>
    </section>
  );
}
