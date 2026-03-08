'use client';

import { useEffect, useRef, useState } from 'react';
import { useInView } from '@/lib/hooks/use-in-view';
import { type LucideIcon } from 'lucide-react';
import { FadeIn } from '@/components/marketing/fade-in';

interface AnimatedCounterProps {
  value: string;
  label: string;
  icon?: LucideIcon;
}

function parseValue(val: string): { num: number; prefix: string; suffix: string } {
  const match = val.match(/^([^0-9]*)([0-9]+(?:\.\d+)?)(.*)$/);
  if (!match) return { num: 0, prefix: '', suffix: val };
  return { prefix: match[1], num: parseFloat(match[2]), suffix: match[3] };
}

export function AnimatedCounter({ value, label, icon: Icon }: AnimatedCounterProps) {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true, margin: '-50px' });
  const [displayed, setDisplayed] = useState(0);
  const { num, prefix, suffix } = parseValue(value);

  useEffect(() => {
    if (!isInView) return;

    const duration = 1500;
    const steps = 40;
    let step = 0;

    const timer = setInterval(() => {
      step++;
      // Ease out quad
      const t = step / steps;
      const eased = t * (2 - t);
      setDisplayed(eased * num);

      if (step >= steps) {
        setDisplayed(num);
        clearInterval(timer);
      }
    }, duration / steps);

    return () => clearInterval(timer);
  }, [isInView, num]);

  const displayStr = Number.isInteger(num)
    ? `${prefix}${Math.round(displayed)}${suffix}`
    : `${prefix}${displayed.toFixed(1)}${suffix}`;

  return (
    <FadeIn className="flex flex-col items-center text-center">
      <div ref={ref}>
        {Icon && (
          <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10 mx-auto">
            <Icon className="h-5 w-5 text-ark-primary" />
          </div>
        )}
        <div className="font-[family-name:var(--font-urbanist)] text-4xl font-bold tracking-tight sm:text-5xl">
          <span className="bg-gradient-to-r from-ark-primary to-ark-purple bg-clip-text text-transparent">
            {isInView ? displayStr : `${prefix}0${suffix}`}
          </span>
        </div>
        <div className="mt-2 text-sm text-ark-text-secondary">{label}</div>
      </div>
    </FadeIn>
  );
}
