'use client';

/**
 * CoinIcon — the canonical way to render a crypto asset's identity anywhere
 * in the app. Uses the real CoinGecko logo from the cached top-100 asset
 * list; unknown/long-tail symbols fall back to a deterministic-hue initials
 * disc so the layout never breaks.
 */

import { useCryptoAssets } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';

const SIZES = {
  xs: 'h-4 w-4 text-[7px]',
  sm: 'h-5 w-5 text-[8px]',
  md: 'h-7 w-7 text-[10px]',
  lg: 'h-10 w-10 text-xs',
} as const;

/** Well-known brand colors for majors so fallbacks still look right. */
const BRAND: Record<string, string> = {
  btc: '#F7931A', eth: '#627EEA', sol: '#14F195', usdt: '#26A17B', usdc: '#2775CA',
  bnb: '#F3BA2F', xrp: '#23292F', ada: '#0033AD', doge: '#C2A633', link: '#2A5ADA',
};

function hueFor(symbol: string): string {
  const known = BRAND[symbol.toLowerCase()];
  if (known) return known;
  let h = 0;
  for (const c of symbol) h = (h * 31 + c.charCodeAt(0)) % 360;
  return `hsl(${h} 55% 45%)`;
}

export function CoinIcon({
  symbol,
  size = 'md',
  className,
}: {
  symbol: string;
  size?: keyof typeof SIZES;
  className?: string;
}) {
  const { data: assets } = useCryptoAssets(1);
  const image = assets?.find((a) => a.symbol.toLowerCase() === symbol.toLowerCase())?.image;

  if (image) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={image}
        alt={symbol.toUpperCase()}
        loading="lazy"
        className={cn('shrink-0 rounded-full object-contain', SIZES[size].split(' ').slice(0, 2).join(' '), className)}
      />
    );
  }

  return (
    <span
      className={cn(
        'flex shrink-0 items-center justify-center rounded-full font-bold text-white',
        SIZES[size],
        className,
      )}
      style={{ background: hueFor(symbol) }}
    >
      {symbol.slice(0, 3).toUpperCase()}
    </span>
  );
}
