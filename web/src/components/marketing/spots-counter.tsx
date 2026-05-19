'use client';

import { useEffect, useRef, useState } from 'react';

const TOTAL_SPOTS = 150;
const BASELINE_COUNT = 87;
const SOCIAL_PROOF_THRESHOLD = 250;

interface SpotData {
  signupCount: number;
  spotsRemaining: number;
  showSocialProof: boolean;
}

/** Shared fetch — all instances on the page share one request */
let sharedPromise: Promise<SpotData> | null = null;
let sharedResult: SpotData | null = null;

function fetchSpots(): Promise<SpotData> {
  if (sharedResult) return Promise.resolve(sharedResult);
  if (sharedPromise) return sharedPromise;

  sharedPromise = fetch('/api/spots')
    .then((r) => (r.ok ? r.json() : null))
    .then((data) => {
      const result: SpotData = data ?? {
        signupCount: BASELINE_COUNT,
        spotsRemaining: Math.max(0, TOTAL_SPOTS - BASELINE_COUNT),
        showSocialProof: BASELINE_COUNT >= SOCIAL_PROOF_THRESHOLD,
      };
      sharedResult = result;
      return result;
    })
    .catch(() => {
      const fallback: SpotData = {
        signupCount: BASELINE_COUNT,
        spotsRemaining: Math.max(0, TOTAL_SPOTS - BASELINE_COUNT),
        showSocialProof: false,
      };
      sharedResult = fallback;
      return fallback;
    });

  return sharedPromise;
}

// ─── Animated number hook ───

function useAnimatedNumber(target: number): number {
  const [display, setDisplay] = useState(target);
  const hasAnimated = useRef(false);

  useEffect(() => {
    if (hasAnimated.current) return;
    hasAnimated.current = true;

    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReduced) { setDisplay(target); return; }

    // Animate last 20%
    const start = target > 30
      ? Math.round(target * 0.8)
      : Math.round(target * 1.25); // for small numbers (spots), start higher
    const duration = 600;
    const t0 = performance.now();

    function tick(now: number) {
      const p = Math.min((now - t0) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      setDisplay(Math.round(start + (target - start) * eased));
      if (p < 1) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }, [target]);

  return display;
}

// ─── SpotsCounter ───

interface SpotsCounterProps {
  className?: string;
}

export function SpotsCounter({ className = '' }: SpotsCounterProps) {
  const [spots, setSpots] = useState(Math.max(0, TOTAL_SPOTS - BASELINE_COUNT));

  useEffect(() => {
    fetchSpots().then((d) => setSpots(d.spotsRemaining));
  }, []);

  const display = useAnimatedNumber(spots);

  if (spots <= 0) {
    return (
      <span className={`text-xs font-medium text-ark-text-tertiary ${className}`}>
        Founding pricing closed. Standard pricing applies.
      </span>
    );
  }

  const isUrgent = spots <= 30;
  const isCritical = spots <= 10;

  const numberClass = isCritical
    ? 'text-sm font-bold text-ark-warning'
    : isUrgent
      ? 'text-xs font-semibold text-ark-warning'
      : 'text-xs font-medium text-ark-primary';

  return (
    <span className={`inline-flex items-center gap-1.5 ${className}`}>
      {isUrgent && (
        <span className="relative flex h-1.5 w-1.5 shrink-0">
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-ark-warning opacity-75" />
          <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-ark-warning" />
        </span>
      )}
      <span className={numberClass}>
        {display} of 150 founding spots remaining
      </span>
    </span>
  );
}

// ─── WaitlistCount ───

interface WaitlistCountProps {
  className?: string;
}

export function WaitlistCount({ className = '' }: WaitlistCountProps) {
  const [data, setData] = useState<SpotData | null>(null);

  useEffect(() => {
    fetchSpots().then(setData);
  }, []);

  if (!data || !data.showSocialProof) return null;

  return (
    <span className={`text-xs text-ark-text-tertiary ${className}`}>
      Join {data.signupCount.toLocaleString()} investors on the early access list
    </span>
  );
}
