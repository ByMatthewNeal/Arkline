'use client';

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import Link from 'next/link';
import { BookOpen, ChevronLeft, HelpCircle } from 'lucide-react';
import { useDictionary } from '@/lib/hooks/use-dictionary';
import { logEvent } from '@/lib/api/analytics';
import type { DictionaryTerm } from '@/lib/api/dictionary';
import { cn } from '@/lib/utils/format';

const POPOVER_WIDTH = 320;
const MAX_BACK_STACK = 5;

export type DefineTermVariant = 'icon' | 'underline' | 'wrap';

interface DefineTermProps {
  /** Slug (preferred), or a term/alias string. */
  termKey: string;
  /** Screen name recorded in analytics. */
  screen: string;
  variant?: DefineTermVariant;
  children?: React.ReactNode;
  className?: string;
}

/**
 * Inline "explain this term" trigger. Renders nothing when the key has no
 * dictionary entry, so tap targets can be wired ahead of the copy landing.
 */
export function DefineTerm({
  termKey,
  screen,
  variant = 'icon',
  children,
  className,
}: DefineTermProps) {
  const { lookup } = useDictionary();
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);

  const entry = lookup(termKey);
  if (!entry) return <>{children}</>;

  const label = `Define ${entry.term}`;

  const popover = open ? (
    <TermPopover
      initialTerm={entry}
      screen={screen}
      anchorRef={triggerRef}
      onClose={() => setOpen(false)}
    />
  ) : null;

  if (variant === 'icon') {
    return (
      <span className={cn('inline-flex items-center gap-1', className)}>
        {children}
        <button
          ref={triggerRef}
          type="button"
          aria-label={label}
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
          className="inline-flex h-11 w-11 shrink-0 items-center justify-center text-ark-text-tertiary transition-colors hover:text-ark-text-secondary sm:h-6 sm:w-6"
        >
          <HelpCircle className="h-3.5 w-3.5" aria-hidden />
        </button>
        {popover}
      </span>
    );
  }

  return (
    <button
      ref={triggerRef}
      type="button"
      aria-label={label}
      aria-expanded={open}
      onClick={() => setOpen((v) => !v)}
      className={cn(
        'text-left',
        variant === 'underline' && 'underline decoration-dotted decoration-ark-text-tertiary underline-offset-4',
        className,
      )}
    >
      {children}
      {popover}
    </button>
  );
}

/* ── Popover surface ── */

function TermPopover({
  initialTerm,
  screen,
  anchorRef,
  onClose,
}: {
  initialTerm: DictionaryTerm;
  screen: string;
  anchorRef: React.RefObject<HTMLButtonElement | null>;
  onClose: () => void;
}) {
  const { lookup } = useDictionary();
  const [current, setCurrent] = useState<DictionaryTerm>(initialTerm);
  const [backStack, setBackStack] = useState<DictionaryTerm[]>([]);
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null);
  const panelRef = useRef<HTMLDivElement>(null);

  // One log per opened term, including each related-chip hop.
  useEffect(() => {
    void logEvent('glossary_term_viewed', {
      slug: initialTerm.slug,
      screen,
      source: 'inline',
    });
  }, [initialTerm.slug, screen]);

  useLayoutEffect(() => {
    const anchor = anchorRef.current;
    if (!anchor) return;
    const rect = anchor.getBoundingClientRect();
    const margin = 8;
    const left = Math.min(
      Math.max(margin, rect.left + rect.width / 2 - POPOVER_WIDTH / 2),
      window.innerWidth - POPOVER_WIDTH - margin,
    );
    const spaceBelow = window.innerHeight - rect.bottom;
    const top = spaceBelow > 280 ? rect.bottom + margin : Math.max(margin, rect.top - 280 - margin);
    setPos({ top, left });
  }, [anchorRef]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose();
    }
    function onPointer(e: PointerEvent) {
      const target = e.target as Node;
      if (panelRef.current?.contains(target)) return;
      if (anchorRef.current?.contains(target)) return;
      onClose();
    }
    document.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onPointer);
    return () => {
      document.removeEventListener('keydown', onKey);
      document.removeEventListener('pointerdown', onPointer);
    };
  }, [onClose, anchorRef]);

  const openRelated = useCallback(
    (entry: DictionaryTerm) => {
      setBackStack((stack) => [...stack, current].slice(-MAX_BACK_STACK));
      setCurrent(entry);
      void logEvent('glossary_term_viewed', {
        slug: entry.slug,
        screen,
        source: 'related-chip',
      });
    },
    [current, screen],
  );

  const goBack = useCallback(() => {
    setBackStack((stack) => {
      const previous = stack[stack.length - 1];
      if (previous) setCurrent(previous);
      return stack.slice(0, -1);
    });
  }, []);

  if (typeof document === 'undefined' || !pos) return null;

  const previous = backStack[backStack.length - 1];

  return createPortal(
    <div
      ref={panelRef}
      role="dialog"
      aria-label={current.term}
      style={{ top: pos.top, left: pos.left, width: POPOVER_WIDTH }}
      className="fixed z-50 select-text rounded-xl border border-ark-divider bg-ark-card p-4 shadow-lg motion-safe:animate-in"
      onClick={(e) => e.stopPropagation()}
    >
      {previous && (
        <button
          type="button"
          onClick={goBack}
          className="mb-2 inline-flex items-center gap-1 text-[11px] font-medium text-ark-primary"
        >
          <ChevronLeft className="h-3 w-3" aria-hidden />
          <span className="line-clamp-1">{previous.term}</span>
        </button>
      )}

      <div className="flex items-start justify-between gap-2">
        <h3 className="text-sm font-semibold text-ark-text">{current.term}</h3>
        {current.category && (
          <span className="shrink-0 rounded-full bg-ark-fill-secondary px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-ark-text-secondary">
            {current.category}
          </span>
        )}
      </div>

      <p className="mt-2 text-xs leading-relaxed text-ark-text-secondary">{current.definition}</p>

      {current.example && (
        <div className="mt-3 rounded-lg bg-ark-fill-secondary p-2.5">
          <p className="text-[10px] font-semibold uppercase tracking-wide text-ark-primary">
            For example
          </p>
          <p className="mt-1 text-[11px] leading-relaxed text-ark-text-secondary">
            {current.example}
          </p>
        </div>
      )}

      {current.related_terms.length > 0 && (
        <div className="mt-3">
          <p className="text-[10px] font-semibold uppercase tracking-wide text-ark-text-tertiary">
            Related
          </p>
          <div className="mt-1.5 flex flex-wrap gap-1.5">
            {current.related_terms.map((name) => {
              const related = lookup(name);
              // Terms with no dictionary entry render muted — never a dead tap.
              if (!related || related.id === current.id) {
                return (
                  <span
                    key={name}
                    className="rounded-full bg-ark-fill-secondary px-2 py-0.5 text-[10px] text-ark-text-disabled"
                  >
                    {name}
                  </span>
                );
              }
              return (
                <button
                  key={name}
                  type="button"
                  aria-label={`Define ${related.term}`}
                  onClick={() => openRelated(related)}
                  className="rounded-full bg-ark-fill-secondary px-2 py-0.5 text-[10px] font-medium text-ark-primary transition-colors hover:bg-ark-divider"
                >
                  {name}
                </button>
              );
            })}
          </div>
        </div>
      )}

      <Link
        href="/dashboard/dictionary"
        className="mt-3 inline-flex items-center gap-1.5 text-[11px] font-medium text-ark-primary"
        onClick={onClose}
      >
        <BookOpen className="h-3 w-3" aria-hidden />
        Open full glossary
      </Link>
    </div>,
    document.body,
  );
}
