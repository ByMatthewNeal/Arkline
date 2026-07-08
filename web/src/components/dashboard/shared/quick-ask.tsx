'use client';

/**
 * Quick-ask modal — lets members fire a question to the Arkline team from
 * anywhere (Broadcasts header, like the iOS Insights Q&A button) without
 * leaving the page they're on.
 */

import { useState } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import Link from 'next/link';
import { X, MessagesSquare } from 'lucide-react';
import { Button, useToast } from '@/components/ui';
import { useQaMutations } from '@/lib/hooks/use-qa';
import { useMounted } from '@/lib/hooks/use-mounted';

export function QuickAskModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const mounted = useMounted();
  const toast = useToast();
  const { ask } = useQaMutations();
  const [text, setText] = useState('');
  const [anon, setAnon] = useState(false);

  const submit = () => {
    if (!text.trim()) return;
    ask.mutate(
      { question: text.trim(), isAnonymous: anon },
      {
        onSuccess: () => {
          toast.success('Question sent — the Arkline team will answer soon');
          setText('');
          setAnon(false);
          onClose();
        },
        onError: () => toast.error('Could not send your question. Please try again.'),
      },
    );
  };

  if (!mounted) return null;

  return createPortal(
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
          className="fixed inset-0 z-[150] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
          onClick={onClose}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.96, y: 8 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 8 }}
            transition={{ type: 'spring', stiffness: 380, damping: 32 }}
            className="w-full max-w-md rounded-2xl border border-ark-divider bg-ark-card p-5 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-ark-primary/10">
                  <MessagesSquare className="h-4 w-4 text-ark-primary" />
                </div>
                <h3 className="font-[family-name:var(--font-urbanist)] text-base font-semibold text-ark-text">Ask the Arkline team</h3>
              </div>
              <button onClick={onClose} className="flex h-8 w-8 items-center justify-center rounded-lg text-ark-text-tertiary hover:bg-ark-fill-secondary">
                <X className="h-4 w-4" />
              </button>
            </div>

            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              rows={4}
              autoFocus
              placeholder="What would you like to ask?"
              className="mt-4 w-full resize-none rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3 text-sm text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
            />

            <div className="mt-3 flex items-center justify-between">
              <label className="flex cursor-pointer items-center gap-2 text-xs text-ark-text-secondary">
                <input type="checkbox" checked={anon} onChange={(e) => setAnon(e.target.checked)} className="h-4 w-4 rounded border-ark-divider" />
                Ask anonymously
              </label>
              <div className="flex items-center gap-2">
                <Link href="/dashboard/qa" onClick={onClose} className="text-xs font-medium text-ark-primary hover:text-ark-accent-light">
                  View all Q&A →
                </Link>
                <Button size="sm" onClick={submit} loading={ask.isPending} disabled={!text.trim()}>
                  Post Question
                </Button>
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body,
  );
}
