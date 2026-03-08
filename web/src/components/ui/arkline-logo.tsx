'use client';

import { cn } from '@/lib/utils/format';

type LogoSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

interface ArklineLogoProps {
  size?: LogoSize;
  showText?: boolean;
  className?: string;
}

const sizeMap: Record<LogoSize, { px: number; box: string; font: string }> = {
  xs: { px: 24, box: 'h-6 w-6', font: 'text-base' },
  sm: { px: 32, box: 'h-8 w-8', font: 'text-xl' },
  md: { px: 36, box: 'h-9 w-9', font: 'text-lg' },
  lg: { px: 40, box: 'h-10 w-10', font: 'text-xl' },
  xl: { px: 48, box: 'h-12 w-12', font: 'text-2xl' },
};

export function ArklineLogo({ size = 'sm', showText = true, className }: ArklineLogoProps) {
  const s = sizeMap[size];

  return (
    <div className={cn('flex items-center gap-2.5', className)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/appicon.png"
        alt="Arkline"
        width={s.px}
        height={s.px}
        className={cn('shrink-0 object-contain', s.box)}
      />
      {showText && (
        <span
          className={cn(
            'font-[family-name:var(--font-urbanist)] font-semibold tracking-tight text-ark-text',
            s.font,
          )}
        >
          Arkline
        </span>
      )}
    </div>
  );
}
