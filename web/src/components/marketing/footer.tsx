'use client';

import Link from 'next/link';
import { Twitter, Apple } from 'lucide-react';
import { ArklineLogo } from '@/components/ui';

const footerLinks = {
  Product: [
    { label: 'Features', href: '/features' },
    { label: 'Pricing', href: '/pricing' },
  ],
  Resources: [
    { label: 'Contact', href: '/contact' },
  ],
  Legal: [
    { label: 'Privacy Policy', href: '/privacy' },
    { label: 'Terms of Service', href: '/terms' },
  ],
};

export function Footer() {
  return (
    <footer className="border-t border-ark-divider">
      <div className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-5">
          {/* Brand */}
          <div className="lg:col-span-2">
            <ArklineLogo size="sm" />
            <p className="mt-4 max-w-xs text-sm leading-relaxed text-ark-text-secondary">
              Portfolio tracking, multi-factor risk scoring, and AI-powered market intelligence — built for investors who want a data-driven edge.
            </p>
            <div className="mt-4">
              <div className="inline-flex items-center gap-1.5 rounded-full bg-white/[0.04] px-2.5 py-1 text-[10px] text-ark-text-disabled">
                <Apple className="h-3 w-3" />
                Available on iOS
              </div>
            </div>
            <div className="mt-4 flex gap-3">
              <a
                href="https://x.com/arkaboreal"
                target="_blank"
                rel="noopener noreferrer"
                className="flex h-9 w-9 items-center justify-center rounded-lg bg-white/[0.04] text-ark-text-tertiary transition-colors hover:bg-white/[0.08] hover:text-ark-text"
              >
                <Twitter className="h-4 w-4" />
              </a>
            </div>
          </div>

          {/* Link columns */}
          {Object.entries(footerLinks).map(([title, items]) => (
            <div key={title}>
              <h4 className="text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
                {title}
              </h4>
              <ul className="mt-4 space-y-2.5">
                {items.map((item) => (
                  <li key={item.label}>
                    <Link
                      href={item.href}
                      className="text-sm text-ark-text-secondary transition-colors hover:text-ark-text"
                    >
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="mt-14 flex flex-col items-center justify-between gap-4 border-t border-ark-divider pt-8 sm:flex-row">
          <p className="text-xs text-ark-text-tertiary">
            &copy; {new Date().getFullYear()} Arkline. All rights reserved.
          </p>
          <p className="text-xs text-ark-text-tertiary">
            Market data aggregated from 12+ sources. Not financial advice.
          </p>
        </div>
      </div>
    </footer>
  );
}
