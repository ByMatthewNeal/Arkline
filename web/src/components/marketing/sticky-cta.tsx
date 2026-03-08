'use client';

import { useEffect, useRef, useState } from 'react';
import { EmailCapture } from '@/components/marketing/email-capture';

export function StickyCta() {
  const [footerVisible, setFooterVisible] = useState(false);
  const observerRef = useRef<IntersectionObserver | null>(null);

  useEffect(() => {
    const footer = document.querySelector('footer');
    if (!footer) return;

    observerRef.current = new IntersectionObserver(
      ([entry]) => setFooterVisible(entry.isIntersecting),
      { threshold: 0 },
    );
    observerRef.current.observe(footer);

    return () => observerRef.current?.disconnect();
  }, []);

  return (
    <div
      className={`fixed inset-x-0 bottom-0 z-40 md:hidden transition-all duration-300 ${
        footerVisible ? 'translate-y-full opacity-0' : 'translate-y-0 opacity-100'
      }`}
      style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
    >
      <div className="border-t border-white/[0.08] bg-ark-bg/90 backdrop-blur-xl px-4 py-3">
        <EmailCapture size="inline" className="justify-center" />
      </div>
    </div>
  );
}
