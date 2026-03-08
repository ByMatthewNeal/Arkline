'use client';

import { useEffect, useCallback, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';

interface DetailDrawerProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
}

function useIsMobile() {
  const [isMobile, setIsMobile] = useState(false);
  useEffect(() => {
    const mql = window.matchMedia('(max-width: 767px)');
    setIsMobile(mql.matches);
    const handler = (e: MediaQueryListEvent) => setIsMobile(e.matches);
    mql.addEventListener('change', handler);
    return () => mql.removeEventListener('change', handler);
  }, []);
  return isMobile;
}

export function DetailDrawer({ open, onClose, title, children }: DetailDrawerProps) {
  const isMobile = useIsMobile();

  const handleEscape = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    },
    [onClose],
  );

  useEffect(() => {
    if (!open) return;
    document.addEventListener('keydown', handleEscape);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [open, handleEscape]);

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            className="fixed inset-0 z-50 bg-black/50 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={onClose}
          />

          {/* Centered modal */}
          <motion.div
            className={`fixed z-50 flex flex-col bg-[var(--ark-bg)] border border-ark-divider shadow-2xl
              ${isMobile
                ? 'inset-x-4 bottom-4 top-4 rounded-2xl'
                : 'left-1/2 top-1/2 max-h-[90vh] w-[min(94vw,1100px)] rounded-2xl'
              }`}
            initial={isMobile
              ? { y: '100%', opacity: 0 }
              : { opacity: 0, scale: 0.95, x: '-50%', y: '-50%' }
            }
            animate={isMobile
              ? { y: 0, opacity: 1 }
              : { opacity: 1, scale: 1, x: '-50%', y: '-50%' }
            }
            exit={isMobile
              ? { y: '100%', opacity: 0 }
              : { opacity: 0, scale: 0.95, x: '-50%', y: '-50%' }
            }
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
          >
            {/* Mobile drag handle */}
            {isMobile && (
              <div className="mx-auto mt-2 h-1 w-10 rounded-full bg-ark-divider" />
            )}

            {/* Header */}
            <div className="flex items-center justify-between border-b border-ark-divider px-5 py-4">
              <h2 className="text-sm font-semibold text-ark-text">{title}</h2>
              <button
                onClick={onClose}
                className="flex h-8 w-8 items-center justify-center rounded-lg bg-ark-fill-secondary text-ark-text-tertiary transition-colors hover:text-ark-text cursor-pointer"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Content — scrollable */}
            <div className="flex-1 overflow-y-auto p-5">
              {children}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
