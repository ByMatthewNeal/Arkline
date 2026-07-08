'use client';

/**
 * Lightweight toast system (success / error / info), styled on ark tokens.
 * Mirrors the iOS ToastManager: transient, top-of-stack, auto-dismissing.
 *
 * Usage:
 *   const toast = useToast();
 *   toast.success('Portfolio created');
 *   toast.error('Could not save changes');
 */

import { createContext, useCallback, useContext, useRef, useState } from 'react';
import { useMounted } from '@/lib/hooks/use-mounted';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { CheckCircle2, AlertCircle, Info, X } from 'lucide-react';

type ToastKind = 'success' | 'error' | 'info';

interface ToastItem {
  id: number;
  kind: ToastKind;
  message: string;
}

interface ToastContextValue {
  show: (kind: ToastKind, message: string) => void;
  success: (message: string) => void;
  error: (message: string) => void;
  info: (message: string) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

const ICONS: Record<ToastKind, typeof CheckCircle2> = {
  success: CheckCircle2,
  error: AlertCircle,
  info: Info,
};

const COLORS: Record<ToastKind, string> = {
  success: 'var(--ark-success)',
  error: 'var(--ark-error)',
  info: 'var(--ark-primary)',
};

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const nextId = useRef(0);

  // Render the portal only after mount — during SSR/hydration the server and
  // client must produce identical output, and portals are client-only.
  const mounted = useMounted();

  const dismiss = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const show = useCallback(
    (kind: ToastKind, message: string) => {
      const id = nextId.current++;
      setToasts((prev) => [...prev.slice(-2), { id, kind, message }]);
      window.setTimeout(() => dismiss(id), kind === 'error' ? 6000 : 3500);
    },
    [dismiss],
  );

  const value: ToastContextValue = {
    show,
    success: (m) => show('success', m),
    error: (m) => show('error', m),
    info: (m) => show('info', m),
  };

  return (
    <ToastContext.Provider value={value}>
      {children}
      {mounted &&
        createPortal(
          <div className="pointer-events-none fixed inset-x-0 top-4 z-[200] flex flex-col items-center gap-2 px-4">
            <AnimatePresence>
              {toasts.map((t) => {
                const Icon = ICONS[t.kind];
                return (
                  <motion.div
                    key={t.id}
                    initial={{ opacity: 0, y: -16, scale: 0.96 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: -12, scale: 0.96 }}
                    transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                    className="pointer-events-auto flex w-full max-w-sm items-center gap-2.5 rounded-xl border border-ark-divider bg-ark-card px-3.5 py-2.5 shadow-lg"
                  >
                    <Icon className="h-4 w-4 shrink-0" style={{ color: COLORS[t.kind] }} />
                    <p className="flex-1 text-sm text-ark-text">{t.message}</p>
                    <button
                      onClick={() => dismiss(t.id)}
                      className="rounded-md p-1 text-ark-text-tertiary transition-colors hover:text-ark-text"
                      aria-label="Dismiss"
                    >
                      <X className="h-3.5 w-3.5" />
                    </button>
                  </motion.div>
                );
              })}
            </AnimatePresence>
          </div>,
          document.body,
        )}
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within ToastProvider');
  return ctx;
}
