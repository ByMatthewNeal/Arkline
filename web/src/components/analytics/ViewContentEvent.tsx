'use client';

import { useEffect } from 'react';

export function ViewContentEvent({ contentName }: { contentName: string }) {
  useEffect(() => {
    if (typeof window !== 'undefined' && typeof window.fbq === 'function') {
      window.fbq('track', 'ViewContent', { content_name: contentName });
    }
  }, [contentName]);

  return null;
}
