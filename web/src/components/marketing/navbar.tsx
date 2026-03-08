'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Menu, X } from 'lucide-react';
import { ArklineLogo, ThemeToggle } from '@/components/ui';
import { EmailCapture } from '@/components/marketing/email-capture';

const links = [
  { label: 'Features', href: '/features' },
  { label: 'Pricing', href: '/pricing' },
];

export function Navbar() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header className="fixed top-0 z-50 w-full">
      <nav
        className={`
          mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8
          transition-all duration-300
          ${
            scrolled
              ? 'mx-4 mt-2 rounded-2xl border border-white/[0.08] bg-ark-bg/80 shadow-lg shadow-black/5 backdrop-blur-xl sm:mx-6 lg:mx-auto'
              : 'bg-transparent'
          }
        `}
      >
        <Link href="/" onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}>
          <ArklineLogo size="lg" />
        </Link>

        {/* Desktop */}
        <div className="hidden items-center gap-1 md:flex">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="rounded-lg px-3 py-2 text-sm font-medium text-ark-text-secondary transition-colors hover:bg-white/[0.04] hover:text-ark-text"
            >
              {l.label}
            </Link>
          ))}
          <div className="mx-2 h-5 w-px bg-ark-divider" />
          <ThemeToggle />
          <EmailCapture size="inline" />
        </div>

        {/* Mobile toggle */}
        <button
          className="flex items-center md:hidden cursor-pointer text-ark-text"
          onClick={() => setOpen(!open)}
        >
          {open ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </nav>

      {/* Mobile menu — CSS-only animation for instant interactivity */}
      <div
        className={`mx-4 mt-2 overflow-hidden rounded-2xl border border-white/[0.08] bg-ark-bg/95 shadow-xl backdrop-blur-xl md:hidden transition-all duration-200 origin-top ${
          open
            ? 'opacity-100 scale-y-100 pointer-events-auto'
            : 'opacity-0 scale-y-95 pointer-events-none h-0 border-0 mt-0'
        }`}
      >
        <div className="flex flex-col gap-1 p-3">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="rounded-xl px-4 py-3 text-sm font-medium text-ark-text-secondary transition-colors hover:bg-white/[0.04]"
              onClick={() => setOpen(false)}
            >
              {l.label}
            </Link>
          ))}
          <div className="my-1 h-px bg-ark-divider" />
          <div className="p-1">
            <EmailCapture size="inline" className="w-full justify-center" />
          </div>
        </div>
      </div>
    </header>
  );
}
