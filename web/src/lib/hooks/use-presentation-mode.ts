'use client';

import { useCallback, useEffect, useState } from 'react';

/**
 * Presentation Mode — the "show a friend" display mode.
 *
 * Masks money (account value, gains, holdings, cost basis) while keeping growth
 * percentages and ratios visible, so you can show someone your performance
 * without revealing your net worth. Optionally also masks asset quantities.
 *
 * Persisted in localStorage and kept in sync across every component (and across
 * tabs) via a lightweight event, so toggling it in one place updates everywhere.
 */
const KEY = 'arkline_presentation_mode';
const QTY_KEY = 'arkline_presentation_hide_quantities';
const EVENT = 'arkline-presentation-change';
const MASK_LONG = '••••••';
const MASK_SHORT = '••••';

function read(key: string): boolean {
  if (typeof window === 'undefined') return false;
  try {
    return window.localStorage.getItem(key) === '1';
  } catch {
    return false;
  }
}

function write(key: string, value: boolean): void {
  try {
    window.localStorage.setItem(key, value ? '1' : '0');
  } catch {
    /* localStorage may be unavailable; ignore */
  }
  window.dispatchEvent(new Event(EVENT));
}

export interface PresentationMode {
  /** Presentation Mode on/off. */
  presentation: boolean;
  /** When on, also mask asset quantities / share counts. */
  hideQuantities: boolean;
  togglePresentation: () => void;
  setPresentation: (on: boolean) => void;
  toggleHideQuantities: () => void;
  /** True when any money should be hidden. */
  maskCurrency: boolean;
  /** True when quantities should be hidden. */
  maskQuantity: boolean;
  /** Wrap a pre-formatted currency string; returns dots when money is hidden. */
  money: (formatted: string) => string;
  /** Wrap a pre-formatted quantity string; returns dots when quantities are hidden. */
  qty: (formatted: string) => string;
}

export function usePresentationMode(): PresentationMode {
  const [presentation, setPresentationState] = useState(false);
  const [hideQuantities, setHideQuantities] = useState(false);

  useEffect(() => {
    const sync = () => {
      setPresentationState(read(KEY));
      setHideQuantities(read(QTY_KEY));
    };
    sync();
    window.addEventListener(EVENT, sync);
    window.addEventListener('storage', sync);
    return () => {
      window.removeEventListener(EVENT, sync);
      window.removeEventListener('storage', sync);
    };
  }, []);

  const togglePresentation = useCallback(() => write(KEY, !read(KEY)), []);
  const setPresentation = useCallback((on: boolean) => write(KEY, on), []);
  const toggleHideQuantities = useCallback(() => write(QTY_KEY, !read(QTY_KEY)), []);

  const maskCurrency = presentation;
  const maskQuantity = presentation && hideQuantities;

  return {
    presentation,
    hideQuantities,
    togglePresentation,
    setPresentation,
    toggleHideQuantities,
    maskCurrency,
    maskQuantity,
    money: (formatted: string) => (maskCurrency ? MASK_LONG : formatted),
    qty: (formatted: string) => (maskQuantity ? MASK_SHORT : formatted),
  };
}
