export function formatCurrency(
  value: number,
  currency = 'USD',
  opts?: { compact?: boolean; decimals?: number; sign?: boolean },
): string {
  const { compact, decimals, sign } = opts ?? {};
  const prefix = sign && value > 0 ? '+' : '';

  if (compact && Math.abs(value) >= 1_000_000_000) {
    return `${prefix}$${(value / 1_000_000_000).toFixed(1)}B`;
  }
  if (compact && Math.abs(value) >= 1_000_000) {
    return `${prefix}$${(value / 1_000_000).toFixed(1)}M`;
  }
  if (compact && Math.abs(value) >= 1_000) {
    return `${prefix}$${(value / 1_000).toFixed(1)}K`;
  }

  const formatted = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
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
