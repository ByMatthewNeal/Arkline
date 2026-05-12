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
            Effective May 12, 2026  &bull;  Last updated May 12, 2026
          </p>
        </FadeIn>

        <FadeIn onMount delay={0.1} as="article" className="prose-ark mt-10 space-y-8 text-sm leading-relaxed text-ark-text-secondary">
          <section>
            <h2 className="text-lg font-semibold text-ark-text">1. Acceptance of These Terms</h2>
            <p className="mt-2">
              These Terms of Service (&quot;Terms&quot;) form a binding agreement between you and Arkline Technologies LLC (&quot;Arkline,&quot; &quot;we,&quot; &quot;us,&quot; or &quot;our&quot;). By creating an account, accessing the Arkline website at arkline.io, or using the Arkline iOS application (collectively, the &quot;Service&quot;), you agree to be bound by these Terms and our <a href="/privacy" className="text-ark-primary hover:underline">Privacy Policy</a>.
            </p>
            <p className="mt-2">
              If you do not agree, do not use the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">2. Eligibility</h2>
            <p className="mt-2">You may use the Service only if you:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Are at least 18 years old</li>
              <li>Have the legal capacity to enter into a binding contract</li>
              <li>Are not barred from using the Service under applicable law</li>
              <li>Are not located in a country subject to a U.S. government embargo or designated by the U.S. government as a &quot;terrorist-supporting&quot; country</li>
            </ul>
            <p className="mt-2">
              By using the Service, you represent that you meet these requirements.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">3. The Service Is Not Financial or Investment Advice</h2>
            <p className="mt-2">
              <strong className="text-ark-text">This is the most important provision in these Terms. Read it carefully.</strong>
            </p>
            <p className="mt-2">
              Arkline is a market-intelligence and analytical tool. It is not a registered investment advisor, broker-dealer, financial planner, or fiduciary. We do not provide personalized investment advice, recommendations, or solicitations to buy or sell any security, cryptocurrency, or other asset.
            </p>
            <p className="mt-2">
              All content delivered through the Service &mdash; including risk scores, AI-generated briefings, macro indicators, sentiment analyses, DCA suggestions, technical analysis, and any other output &mdash; is <strong className="text-ark-text">for informational and educational purposes only</strong>. None of it should be construed as:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>A recommendation to buy, sell, or hold any specific asset</li>
              <li>A solicitation of an offer to buy or sell any security</li>
              <li>Personalized financial, tax, legal, or accounting advice</li>
              <li>A guarantee of any specific result, return, or outcome</li>
            </ul>
            <p className="mt-2">
              You are solely responsible for your investment decisions. You acknowledge that all financial markets &mdash; and cryptocurrency markets in particular &mdash; involve substantial risk, including the risk of total loss. <strong className="text-ark-text">Past performance does not guarantee future results.</strong>
            </p>
            <p className="mt-2">
              Before making any financial decision, you should consult with a qualified, licensed financial advisor and conduct your own independent research. We strongly recommend that you do.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">4. AI-Generated Content</h2>
            <p className="mt-2">
              The Service includes features that generate content using artificial intelligence (&quot;AI Content&quot;), including AI Briefings and AI Chat. AI Content is produced by third-party language models (currently Anthropic&apos;s Claude) based on prompts and data we send to them.
            </p>
            <p className="mt-2">You acknowledge:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>AI Content may contain errors, inaccuracies, or omissions</li>
              <li>AI Content may reflect biases present in the underlying training data</li>
              <li>AI Content is generated probabilistically and is not deterministic &mdash; the same query may produce different responses</li>
              <li>AI Content does not represent our professional opinion or advice</li>
              <li>We do not verify AI Content for accuracy before delivering it to you</li>
              <li>You should independently verify any factual claims before relying on them</li>
            </ul>
            <p className="mt-2">
              We are not liable for any decisions you make based on AI Content. AI Content is delivered &quot;as is&quot; and is subject to all the disclaimers in Section 8.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">5. Account Creation and Access</h2>

            <p className="mt-4"><strong className="text-ark-text">Invitation-only access</strong></p>
            <p className="mt-2">
              Arkline is currently invitation-only. To create an account, you must (a) receive an invitation through our membership channels and (b) complete payment for a membership through our website.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Account responsibility</strong></p>
            <p className="mt-2">You are responsible for:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Keeping your login credentials confidential</li>
              <li>All activity that occurs under your account</li>
              <li>Notifying us promptly at <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a> if you suspect unauthorized access</li>
            </ul>
            <p className="mt-2">
              We are not liable for any loss or damage arising from your failure to safeguard your credentials.
            </p>

            <p className="mt-4"><strong className="text-ark-text">One account per person</strong></p>
            <p className="mt-2">
              You may create only one account. Accounts are personal and non-transferable. You may not share your credentials with anyone else.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">6. Subscriptions and Billing</h2>

            <p className="mt-4"><strong className="text-ark-text">Subscription terms</strong></p>
            <p className="mt-2">
              The Service is offered on a subscription basis. By subscribing, you agree to pay the recurring fees disclosed at the time of your purchase.
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Subscriptions auto-renew at the end of each billing period unless canceled</li>
              <li>Fees are charged through Stripe, our payment processor, in U.S. dollars</li>
              <li>Applicable taxes will be added where required by law</li>
              <li>Prices may change with at least 30 days&apos; notice; changes will not affect your current billing period</li>
            </ul>

            <p className="mt-4"><strong className="text-ark-text">Free trials</strong></p>
            <p className="mt-2">
              If your subscription includes a free trial, you will not be charged during the trial. Your card will be charged automatically at the end of the trial unless you cancel before then.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Cancellation</strong></p>
            <p className="mt-2">
              You may cancel your subscription at any time through your account settings on arkline.io or by contacting <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a>. Cancellation takes effect at the end of your current billing period; you will retain access until then. <strong className="text-ark-text">We do not provide refunds for partial billing periods</strong>, except as required by applicable law.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Refunds</strong></p>
            <p className="mt-2">
              Except as required by law, all fees are non-refundable.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Failed payments</strong></p>
            <p className="mt-2">
              If a payment fails, we will attempt to retry the charge through Stripe. If payment is not received, we may suspend or terminate your access to paid features without further notice.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">7. Acceptable Use</h2>
            <p className="mt-2">You agree not to:</p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Use the Service for any illegal purpose or in violation of any applicable law</li>
              <li>Reverse-engineer, decompile, or disassemble any part of the Service</li>
              <li>Use any automated system (bots, scrapers) to access the Service except for legitimate accessibility tools</li>
              <li>Resell, sublicense, or redistribute access to the Service</li>
              <li>Share your account credentials with another person</li>
              <li>Submit false, misleading, or fraudulent information</li>
              <li>Upload, post, or transmit any content that is unlawful, defamatory, harassing, abusive, fraudulent, obscene, or otherwise objectionable</li>
              <li>Attempt to gain unauthorized access to other users&apos; accounts or to our systems</li>
              <li>Interfere with or disrupt the Service or its underlying infrastructure</li>
              <li>Use the Service to develop a competing product or service</li>
            </ul>
            <p className="mt-2">
              We reserve the right to suspend or terminate your access for any violation of these Terms.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">8. Disclaimers and Limitations of Liability</h2>

            <p className="mt-4"><strong className="text-ark-text">Disclaimer of warranties</strong></p>
            <p className="mt-2">
              <strong className="text-ark-text">THE SERVICE IS PROVIDED &quot;AS IS&quot; AND &quot;AS AVAILABLE,&quot; WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS, IMPLIED, STATUTORY, OR OTHERWISE. TO THE FULLEST EXTENT PERMITTED BY LAW, WE DISCLAIM ALL WARRANTIES INCLUDING:</strong>
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">MERCHANTABILITY</strong></li>
              <li><strong className="text-ark-text">FITNESS FOR A PARTICULAR PURPOSE</strong></li>
              <li><strong className="text-ark-text">NON-INFRINGEMENT</strong></li>
              <li><strong className="text-ark-text">ACCURACY, COMPLETENESS, OR TIMELINESS OF DATA</strong></li>
              <li><strong className="text-ark-text">UNINTERRUPTED OR ERROR-FREE OPERATION</strong></li>
            </ul>
            <p className="mt-2">
              <strong className="text-ark-text">WE DO NOT WARRANT THAT MARKET DATA, RISK SCORES, AI BRIEFINGS, OR ANY OTHER CONTENT IS ACCURATE OR RELIABLE. WE DO NOT WARRANT THAT THE SERVICE WILL MEET YOUR REQUIREMENTS OR LEAD TO ANY SPECIFIC FINANCIAL OUTCOME.</strong>
            </p>

            <p className="mt-4"><strong className="text-ark-text">Limitation of liability</strong></p>
            <p className="mt-2">
              <strong className="text-ark-text">TO THE FULLEST EXTENT PERMITTED BY LAW, IN NO EVENT WILL ARKLINE, ITS AFFILIATES, OR ITS OFFICERS, DIRECTORS, EMPLOYEES, OR AGENTS BE LIABLE FOR:</strong>
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES</strong></li>
              <li><strong className="text-ark-text">ANY LOSS OF PROFITS, REVENUES, DATA, OR BUSINESS OPPORTUNITY</strong></li>
              <li><strong className="text-ark-text">ANY INVESTMENT LOSSES OR FINANCIAL DAMAGES OF ANY KIND, REGARDLESS OF WHETHER YOU RELIED ON CONTENT OBTAINED FROM THE SERVICE</strong></li>
            </ul>
            <p className="mt-2">
              <strong className="text-ark-text">OUR TOTAL CUMULATIVE LIABILITY ARISING FROM OR RELATED TO THESE TERMS OR THE SERVICE WILL NOT EXCEED THE GREATER OF (A) THE FEES YOU PAID US IN THE 12 MONTHS BEFORE THE EVENT GIVING RISE TO THE CLAIM, OR (B) ONE HUNDRED U.S. DOLLARS ($100).</strong>
            </p>
            <p className="mt-2">
              This limitation applies regardless of the legal theory (contract, tort, negligence, strict liability, or otherwise) and even if we have been advised of the possibility of such damages.
            </p>
            <p className="mt-2">
              Some jurisdictions do not allow the exclusion of certain warranties or limitation of liability, so some of the above may not apply to you. In those jurisdictions, our liability is limited to the maximum extent permitted by law.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">9. Indemnification</h2>
            <p className="mt-2">
              You agree to indemnify, defend, and hold harmless Arkline and its affiliates, officers, directors, employees, and agents from any claims, damages, losses, liabilities, and expenses (including reasonable attorneys&apos; fees) arising from or related to:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Your use of the Service</li>
              <li>Your violation of these Terms</li>
              <li>Your violation of any law or third-party right</li>
              <li>Any investment or financial decisions you make based on information from the Service</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">10. Intellectual Property</h2>

            <p className="mt-4"><strong className="text-ark-text">Our content</strong></p>
            <p className="mt-2">
              The Service, including its software, design, text, graphics, logos, risk-scoring methodology, and other content (excluding user-submitted content and third-party data feeds), is owned by Arkline and protected by U.S. and international copyright, trademark, and other intellectual property laws.
            </p>
            <p className="mt-2">
              We grant you a limited, non-exclusive, non-transferable, revocable license to access and use the Service for personal, non-commercial purposes during the term of your subscription. This license does not include the right to:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Resell, sublicense, or commercially exploit the Service</li>
              <li>Make copies of any portion of the Service except as expressly permitted</li>
              <li>Use the Service to build a competing product</li>
            </ul>

            <p className="mt-4"><strong className="text-ark-text">Your content</strong></p>
            <p className="mt-2">
              You retain ownership of any portfolio data, notes, or other content you submit to the Service. By submitting content, you grant us a non-exclusive, royalty-free license to use, store, display, and process that content as necessary to operate the Service for you.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Feedback</strong></p>
            <p className="mt-2">
              If you submit feedback, suggestions, or ideas, you grant us a perpetual, irrevocable, royalty-free license to use them without compensation or attribution.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">11. Third-Party Services and Data</h2>
            <p className="mt-2">
              The Service incorporates data and services from third parties, including market data providers (CoinGecko, Alpha Vantage, FRED, FMP, Taapi.io, Coinglass), Anthropic (Claude API for AI features), Stripe (payment processing), and Apple (push notifications and the iOS platform).
            </p>
            <p className="mt-2">
              We are not responsible for the accuracy, availability, or content of third-party services. Use of third-party services may be subject to their own terms and privacy policies. Disruptions or errors in third-party services may affect the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">12. Termination</h2>

            <p className="mt-4"><strong className="text-ark-text">Termination by you</strong></p>
            <p className="mt-2">
              You may terminate your account at any time by canceling your subscription and deleting your account from within the app or by emailing <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a>.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Termination by us</strong></p>
            <p className="mt-2">
              We may suspend or terminate your access to the Service, with or without notice, for any reason, including:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li>Violation of these Terms</li>
              <li>Failure to pay fees when due</li>
              <li>Conduct that we believe poses a risk to other users, the Service, or us</li>
              <li>Extended inactivity</li>
              <li>Discontinuation of the Service</li>
            </ul>

            <p className="mt-4"><strong className="text-ark-text">Effect of termination</strong></p>
            <p className="mt-2">
              Upon termination, your right to access the Service ends immediately. Sections that by their nature should survive termination &mdash; including Sections 3, 4, 8, 9, 10, 13, and 14 &mdash; will survive.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">13. Dispute Resolution and Governing Law</h2>

            <p className="mt-4"><strong className="text-ark-text">Governing law</strong></p>
            <p className="mt-2">
              These Terms are governed by the laws of the State of Wyoming, United States, without regard to its conflict-of-laws provisions.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Informal resolution</strong></p>
            <p className="mt-2">
              Before filing a formal claim, you agree to contact us at <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a> and attempt to resolve the dispute informally. Most disputes can be resolved this way.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Binding arbitration</strong></p>
            <p className="mt-2">
              [ARBITRATION CLAUSE — review with attorney before publishing. The following is a common template; your attorney may recommend modifications based on your state and risk profile:]
            </p>
            <p className="mt-2">
              If we cannot resolve a dispute informally within 60 days, you and Arkline agree to resolve any dispute through binding individual arbitration administered by the American Arbitration Association (AAA) under its Consumer Arbitration Rules. The arbitration will take place in [CITY, STATE] or at another mutually agreed location, or by video conference.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Class action waiver.</strong> You and Arkline agree that disputes will be resolved on an individual basis only. You waive any right to participate in a class action, class arbitration, or representative proceeding.
            </p>
            <p className="mt-2">
              <strong className="text-ark-text">Opt-out.</strong> You may opt out of this arbitration agreement by sending written notice to <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a> within 30 days of first accepting these Terms.
            </p>

            <p className="mt-4"><strong className="text-ark-text">Exceptions</strong></p>
            <p className="mt-2">
              Either party may bring an individual claim in small-claims court for disputes within that court&apos;s jurisdiction. Either party may seek injunctive relief in court for intellectual property infringement or unauthorized access to the Service.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">14. Changes to These Terms</h2>
            <p className="mt-2">
              We may update these Terms from time to time. If we make material changes, we will notify you by email (to the address associated with your account) or by a prominent notice in the Service before the changes take effect.
            </p>
            <p className="mt-2">
              Your continued use of the Service after changes become effective constitutes acceptance of the updated Terms. If you do not agree to the changes, you must stop using the Service and may cancel your subscription.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">15. Miscellaneous</h2>
            <ul className="mt-2 list-disc space-y-1 pl-5">
              <li><strong className="text-ark-text">Entire agreement.</strong> These Terms, together with our Privacy Policy, constitute the entire agreement between you and Arkline regarding the Service and supersede any prior agreements.</li>
              <li><strong className="text-ark-text">Severability.</strong> If any provision of these Terms is found unenforceable, the remaining provisions will remain in full force and effect.</li>
              <li><strong className="text-ark-text">No waiver.</strong> Our failure to enforce any provision of these Terms will not constitute a waiver of that provision.</li>
              <li><strong className="text-ark-text">Assignment.</strong> You may not assign or transfer these Terms without our prior written consent. We may assign these Terms without restriction.</li>
              <li><strong className="text-ark-text">Force majeure.</strong> We are not liable for failure to perform any obligation under these Terms due to causes beyond our reasonable control, including natural disasters, war, terrorism, labor disputes, internet outages, government action, or third-party service failures.</li>
              <li><strong className="text-ark-text">Apple-specific terms (for iOS users).</strong> If you are using our iOS app: these Terms are between you and Arkline only, not Apple; Apple has no obligation to provide maintenance or support for the app; Apple is not responsible for addressing any claims you have relating to the app; Apple is a third-party beneficiary of these Terms and has the right to enforce them against you.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-ark-text">16. Contact Us</h2>
            <p className="mt-2">For questions about these Terms or the Service, contact:</p>
            <p className="mt-2">
              <strong className="text-ark-text">Arkline Technologies LLC</strong><br />
              1908 Thomes Ave STE 63374<br />
              Cheyenne, WY 82001<br />
              Email: <a href="mailto:support@arkline.io" className="text-ark-primary hover:underline">support@arkline.io</a>
            </p>
          </section>
        </FadeIn>
      </div>
    </section>
  );
}
