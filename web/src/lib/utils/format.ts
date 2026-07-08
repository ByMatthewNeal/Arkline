/* ── Currency preference ─────────────────────────────────────────────────
 * The user's preferred currency (Settings → Preferred Currency) is applied
 * app-wide. `setPreferredCurrency` is called from the dashboard layout when
 * the profile loads; consumers re-render via the layout's currency key.
 */
const CURRENCY_SYMBOLS: Record<string, string> = {
  USD: '$', EUR: '€', GBP: '£', JPY: '¥', AUD: 'A$', CAD: 'C$', CHF: 'CHF ',
};

let preferredCurrency = 'USD';

export function setPreferredCurrency(code: string | null | undefined) {
  if (code && CURRENCY_SYMBOLS[code]) preferredCurrency = code;
}

export function getPreferredCurrency(): string {
  return preferredCurrency;
}

export function formatCurrency(
  value: number,
  currency?: string,
  opts?: { compact?: boolean; decimals?: number; sign?: boolean },
): string {
  const cur = currency ?? preferredCurrency;
  const { compact, decimals, sign } = opts ?? {};
  const prefix = sign && value > 0 ? '+' : '';
  const symbol = CURRENCY_SYMBOLS[cur] ?? '$';

  if (compact && Math.abs(value) >= 1_000_000_000) {
    return `${prefix}${symbol}${(value / 1_000_000_000).toFixed(1)}B`;
  }
  if (compact && Math.abs(value) >= 1_000_000) {
    return `${prefix}${symbol}${(value / 1_000_000).toFixed(1)}M`;
  }
  if (compact && Math.abs(value) >= 1_000) {
    return `${prefix}${symbol}${(value / 1_000).toFixed(1)}K`;
  }

  const formatted = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: cur,
    minimumFractionDigits: decimals ?? (Math.abs(value) < 1 ? 4 : 2),
    maximumFractionDigits: decimals ?? (Math.abs(value) < 1 ? 6 : 2),
  }).format(value);

  return prefix + formatted;
}

export function formatPercent(value: number, decimals = 2): string {
  const sign = value > 0 ? '+' : '';
  return `${sign}${value.toFixed(decimals)}%`;
}

export function formatNumber(value: number, decimals = 2): string {
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

export function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

export function formatRelativeTime(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = now - then;

  // Future dates
  if (diff < 0) {
    const absDiff = Math.abs(diff);
    const minutes = Math.floor(absDiff / 60_000);
    if (minutes < 60) return `in ${minutes}m`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `in ${hours}h`;
    const days = Math.floor(hours / 24);
    return `in ${days}d`;
  }

  const minutes = Math.floor(diff / 60_000);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;

  return formatDate(dateStr);
}

export function formatTimestamp(): string {
  return new Date().toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
    hour12: true,
  });
}

export function cn(...classes: (string | false | undefined | null)[]): string {
  return classes.filter(Boolean).join(' ');
}

/* Parse a markdown briefing ("## TLDR\n…\n\n## Weekend Pulse\n…") into labeled
 * sections, matching the iOS app's sectioned Daily Briefing layout. */
export interface BriefingSection {
  title: string;
  body: string;
}

/** Action guidance for a positioning-signal transition (matches iOS changeHint). */
export function signalChangeHint(from: string, to: string): string {
  const map: Record<string, string> = {
    'bearish>neutral': 'Downtrend pressure easing. Watch for bullish confirmation.',
    'bearish>bullish': 'Trend reversal. Conditions turning favorable for exposure.',
    'neutral>bullish': 'Trend strengthening. Favorable to add or hold positions.',
    'neutral>bearish': 'Trend weakening. Consider reducing exposure.',
    'bullish>neutral': 'Momentum fading. Consider tightening stops or trimming.',
    'bullish>bearish': 'Trend breakdown. Prioritize capital preservation.',
  };
  return map[`${from}>${to}`] ?? '';
}

export function parseBriefingSections(md: string | null | undefined): BriefingSection[] {
  if (!md) return [];
  const hasHeaders = /^##\s+/m.test(md);
  if (!hasHeaders) return [{ title: '', body: md.trim() }];
  return md
    .split(/^##\s+/m)
    .map((s) => s.trim())
    .filter(Boolean)
    .map((part) => {
      const nl = part.indexOf('\n');
      if (nl === -1) return { title: part.trim(), body: '' };
      return { title: part.slice(0, nl).trim(), body: part.slice(nl + 1).trim() };
    });
}
