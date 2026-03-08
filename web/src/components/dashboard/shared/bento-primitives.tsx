'use client';

import { useRef, useEffect, useState } from 'react';
import { ArrowUpRight, GripVertical } from 'lucide-react';
import { motion, useInView } from 'framer-motion';
import { GlassCard, Skeleton } from '@/components/ui';
import { cn } from '@/lib/utils/format';

/* ── Globally unique SVG gradient IDs ── */
let sparkIdCounter = 0;
export function useSparkId() {
  const idRef = useRef(`sp-${++sparkIdCounter}`);
  return idRef.current;
}

/* ── Animated count-up hook ── */
export function useCountUp(target: number, isLoading: boolean, decimals = 0) {
  const ref = useRef<HTMLSpanElement>(null);
  const inViewRef = useRef<HTMLSpanElement>(null);
  const isInView = useInView(inViewRef, { once: true });
  const [display, setDisplay] = useState(0);
  const hasAnimated = useRef(false);

  useEffect(() => {
    if (isLoading || !isInView || hasAnimated.current || target === 0) return;
    hasAnimated.current = true;
    const steps = 35;
    const duration = 1200;
    const stepTime = duration / steps;
    let step = 0;
    const timer = setInterval(() => {
      step++;
      const t = step / steps;
      const eased = 1 - (1 - t) * (1 - t);
      setDisplay(eased * target);
      if (step >= steps) {
        clearInterval(timer);
        setDisplay(target);
      }
    }, stepTime);
    return () => clearInterval(timer);
  }, [target, isLoading, isInView]);

  useEffect(() => {
    if (isLoading) {
      hasAnimated.current = false;
      setDisplay(0);
    }
  }, [isLoading]);

  const formatted = decimals > 0 ? display.toFixed(decimals) : Math.round(display).toString();
  return { ref: inViewRef, value: formatted };
}

/* ── Mini SVG Sparkline ── */
export function Spark({ data, color, className = '' }: { data: number[]; color: string; className?: string }) {
  const id = useSparkId();
  if (data.length < 2) return null;
  const w = 120, h = 32;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * w;
    const y = h - ((v - min) / range) * (h - 4) - 2;
    return `${x},${y}`;
  }).join(' ');
  return (
    <svg viewBox={`0 0 ${w} ${h}`} className={`w-full ${className}`} preserveAspectRatio="none">
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity={0.25} />
          <stop offset="100%" stopColor={color} stopOpacity={0} />
        </linearGradient>
      </defs>
      <polygon points={`0,${h} ${pts} ${w},${h}`} fill={`url(#${id})`} />
      <polyline points={pts} fill="none" stroke={color} strokeWidth={1.5} strokeLinecap="round" />
    </svg>
  );
}

/* ── Mini Semi-Circle Gauge ── */
export function MiniGauge({ value, max, color, size = 72 }: { value: number; max: number; color: string; size?: number }) {
  const r = 28;
  const circ = Math.PI * r;
  const pct = Math.min(value / max, 1);
  const dashOffset = circ - pct * circ;
  const half = size / 2;
  return (
    <svg viewBox={`0 0 ${size} ${half + 8}`} className="w-full" style={{ maxWidth: size }}>
      <path
        d={`M ${half - r} ${half} A ${r} ${r} 0 0 1 ${half + r} ${half}`}
        fill="none" stroke="var(--ark-divider)" strokeWidth="5" strokeLinecap="round"
      />
      <path
        d={`M ${half - r} ${half} A ${r} ${r} 0 0 1 ${half + r} ${half}`}
        fill="none" stroke={color} strokeWidth="5" strokeLinecap="round"
        strokeDasharray={circ} strokeDashoffset={dashOffset}
        className="transition-all duration-700"
      />
    </svg>
  );
}

/* ── Circular Gauge (for Asset Risk) ── */
export function CircleGauge({ value, color, size = 52 }: { value: number; color: string; size?: number }) {
  const r = 20;
  const circ = 2 * Math.PI * r;
  const dash = circ * (1 - value);
  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg viewBox="0 0 48 48" className="h-full w-full -rotate-90">
        <circle cx="24" cy="24" r={r} fill="none" stroke="var(--ark-divider)" strokeWidth="4" />
        <circle cx="24" cy="24" r={r} fill="none" stroke={color} strokeWidth="4"
          strokeLinecap="round" strokeDasharray={circ} strokeDashoffset={dash}
          className="transition-all duration-700"
        />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center font-[family-name:var(--font-urbanist)] text-xs font-bold" style={{ color }}>
        {value.toFixed(2)}
      </span>
    </div>
  );
}

/* ── Top Accent Line (hover-brightening) ── */
export function AccentLine({ color }: { color: string }) {
  return (
    <>
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px transition-opacity duration-300 opacity-30 group-hover:opacity-0"
        style={{ background: `linear-gradient(to right, transparent, ${color}60, transparent)` }}
      />
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px transition-opacity duration-300 opacity-0 group-hover:opacity-80"
        style={{ background: `linear-gradient(to right, transparent, ${color}, transparent)` }}
      />
    </>
  );
}

/* ── Ambient Glow behind hero numbers ── */
export function AmbientGlow({ color, className = '' }: { color: string; className?: string }) {
  return (
    <div
      className={cn('pointer-events-none absolute blur-2xl rounded-full', className)}
      style={{ backgroundColor: color, opacity: 0.07 }}
    />
  );
}

/* ── Shine sweep overlay ── */
export function ShineSweep() {
  return (
    <motion.div
      className="pointer-events-none absolute inset-0 z-10 overflow-hidden rounded-[16px]"
      initial={{ opacity: 1 }}
      animate={{ opacity: 0 }}
      transition={{ delay: 2.5, duration: 0.3 }}
    >
      <motion.div
        className="absolute inset-y-0 w-1/2 skew-x-12"
        style={{
          background: 'linear-gradient(to right, transparent, rgba(255,255,255,0.025), transparent)',
        }}
        initial={{ x: '-100%' }}
        animate={{ x: '200%' }}
        transition={{ delay: 0.9, duration: 1.4, ease: 'easeInOut' }}
      />
    </motion.div>
  );
}

/* ── Clickable Tile Wrapper ── */
export function Tile({ onClick, accentColor, className = '', children }: {
  onClick: () => void;
  accentColor?: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <GlassCard
      hover
      className={`cursor-pointer relative overflow-hidden p-3.5 flex flex-col justify-between h-full ${className}`}
      whileHover={{ scale: 1.008 }}
      onClick={onClick}
    >
      {accentColor && (
        <div
          className="pointer-events-none absolute -inset-px rounded-2xl opacity-0 transition-opacity duration-300 group-hover:opacity-100"
          style={{
            background: `radial-gradient(400px circle at 50% 0%, ${accentColor}10, transparent 60%)`,
          }}
        />
      )}
      {/* Drag handle — visible on hover, initiates drag */}
      <div className="drag-handle absolute top-1.5 left-1.5 z-10 flex h-6 w-6 items-center justify-center rounded-md opacity-0 transition-opacity duration-200 group-hover:opacity-40 hover:!opacity-80 hover:bg-ark-fill-secondary">
        <GripVertical className="h-3 w-3 text-ark-text-tertiary" />
      </div>
      <ArrowUpRight className="pointer-events-none absolute top-2.5 right-2.5 h-3 w-3 text-ark-text-disabled opacity-0 transition-opacity duration-300 group-hover:opacity-40" />
      {children}
    </GlassCard>
  );
}

/* ── Stagger animation variants ── */
export const containerVariants = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.055 },
  },
};

export const cellVariants = {
  hidden: { opacity: 0, y: 16, scale: 0.97 },
  visible: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: {
      duration: 0.5,
      ease: [0.25, 1, 0.5, 1] as [number, number, number, number],
    },
  },
};

/* ── Shaped Loading Skeletons ── */
export function SkeletonHeroTile() {
  return (
    <div className="flex h-full gap-4 p-1">
      <div className="flex flex-col justify-between flex-1 space-y-2">
        <div className="flex items-center gap-2">
          <Skeleton className="h-7 w-7 rounded-lg" />
          <Skeleton className="h-3 w-16" />
        </div>
        <Skeleton className="h-7 w-32" />
        <Skeleton className="h-3 w-24" />
        <div className="flex gap-4">
          <Skeleton className="h-8 w-16" />
          <Skeleton className="h-8 w-16" />
        </div>
        <Skeleton className="h-2 w-full" />
      </div>
      <div className="w-2/5 flex items-end">
        <Skeleton className="h-full w-full rounded-lg" />
      </div>
    </div>
  );
}

export function SkeletonGaugeTile() {
  return (
    <div className="flex flex-col justify-between h-full space-y-2 p-1">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Skeleton className="h-7 w-7 rounded-lg" />
          <Skeleton className="h-3 w-20" />
        </div>
        <Skeleton className="h-5 w-14 rounded-full" />
      </div>
      <Skeleton className="h-10 w-20 mx-auto rounded-full" />
      <div className="flex items-end justify-between">
        <Skeleton className="h-8 w-12" />
        <Skeleton className="h-3 w-16" />
      </div>
      <div className="space-y-1">
        {[1, 2, 3].map(i => (
          <div key={i} className="flex items-center gap-1.5">
            <Skeleton className="h-2 w-14" />
            <Skeleton className="h-1 flex-1" />
          </div>
        ))}
      </div>
    </div>
  );
}

export function SkeletonSparkTile() {
  return (
    <div className="flex flex-col justify-between h-full space-y-2 p-1">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Skeleton className="h-7 w-7 rounded-lg" />
          <Skeleton className="h-3 w-20" />
        </div>
        <Skeleton className="h-5 w-14 rounded-full" />
      </div>
      <Skeleton className="h-8 w-16" />
      <Skeleton className="h-8 w-full rounded-lg" />
      <div className="flex gap-0.5">
        {[1, 2, 3, 4, 5].map(i => <Skeleton key={i} className="h-1 flex-1 rounded-full" />)}
      </div>
    </div>
  );
}

export function SkeletonListTile() {
  return (
    <div className="flex flex-col justify-between h-full space-y-2 p-1">
      <div className="flex items-center gap-2">
        <Skeleton className="h-7 w-7 rounded-lg" />
        <Skeleton className="h-3 w-20" />
      </div>
      {[1, 2, 3].map(i => (
        <div key={i} className="flex items-center gap-2 rounded-lg bg-ark-fill-secondary/20 px-2 py-1.5">
          <Skeleton className="h-5 w-5 rounded-full" />
          <Skeleton className="h-3 flex-1" />
          <Skeleton className="h-3 w-12" />
        </div>
      ))}
    </div>
  );
}

export function SkeletonMacroTile() {
  return (
    <div className="flex flex-col justify-between h-full space-y-2 p-1">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Skeleton className="h-7 w-7 rounded-lg" />
          <Skeleton className="h-3 w-16" />
        </div>
        <Skeleton className="h-5 w-14 rounded-full" />
      </div>
      {[1, 2, 3, 4].map(i => (
        <div key={i} className="flex items-center gap-2 rounded-lg bg-ark-fill-secondary/20 px-2 py-1.5">
          <Skeleton className="h-6 w-0.5 rounded-full" />
          <Skeleton className="h-3 w-7" />
          <Skeleton className="h-3 w-12" />
          <Skeleton className="h-5 flex-1 rounded-lg" />
          <Skeleton className="h-3 w-10" />
        </div>
      ))}
    </div>
  );
}
