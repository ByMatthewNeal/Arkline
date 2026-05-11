'use client';

import { Suspense } from 'react';
import { usePixelPageView } from './use-pixel-page-view';

function PageViewInner() {
  usePixelPageView();
  return null;
}

export function PixelPageViewTracker() {
  return (
    <Suspense fallback={null}>
      <PageViewInner />
    </Suspense>
  );
}
