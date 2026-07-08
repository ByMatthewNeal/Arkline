'use client';

/**
 * Styled replacements for native `confirm()` / `prompt()` dialogs.
 * Centered modal on ark tokens with spring animation + Esc/backdrop close —
 * keeps destructive/creation flows inside the app's design language
 * (matches the iOS pattern of styled alerts, never system chrome for web).
 */

import { useEffect, useState } from 'react';
import { useMounted } from '@/lib/hooks/use-mounted';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { Button, Input } from '@/components/ui';

function DialogShell({
  open,
  onClose,
  children,
}: {
  open: boolean;
  onClose: () => void;
  children: React.ReactNode;
}) {
  // Portal only after mount — server and client must hydrate identically.
  const mounted = useMounted();

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, onClose]);

  if (!mounted) return null;

  return createPortal(
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[150] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
          onClick={onClose}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 8 }}
            transition={{ type: 'spring', stiffness: 400, damping: 32 }}
            className="w-full max-w-sm rounded-2xl border border-ark-divider bg-ark-card p-5 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {children}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body,
  );
}

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  destructive = false,
  loading = false,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
  loading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <DialogShell open={open} onClose={onCancel}>
      <h3 className="font-[family-name:var(--font-urbanist)] text-base font-semibold text-ark-text">{title}</h3>
      <p className="mt-2 text-sm text-ark-text-secondary">{message}</p>
      <div className="mt-5 flex justify-end gap-2">
        <Button variant="ghost" size="sm" onClick={onCancel} disabled={loading}>
          {cancelLabel}
        </Button>
        <Button variant={destructive ? 'danger' : 'primary'} size="sm" onClick={onConfirm} loading={loading}>
          {confirmLabel}
        </Button>
      </div>
    </DialogShell>
  );
}

interface PromptDialogProps {
  open: boolean;
  title: string;
  message?: string;
  placeholder?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  loading?: boolean;
  onSubmit: (value: string) => void;
  onCancel: () => void;
}

// Inner form component — mounts fresh each time the dialog opens, so the
// input state resets naturally (no effect needed).
function PromptForm({
  message,
  placeholder,
  confirmLabel,
  cancelLabel,
  loading,
  onSubmit,
  onCancel,
}: Omit<PromptDialogProps, 'open' | 'title'>) {
  const [value, setValue] = useState('');

  return (
    <form
      className="mt-4"
      onSubmit={(e) => {
        e.preventDefault();
        const trimmed = value.trim();
        if (trimmed) onSubmit(trimmed);
      }}
    >
      {message && <p className="mb-4 -mt-2 text-sm text-ark-text-secondary">{message}</p>}
      <Input
        autoFocus
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder={placeholder}
      />
      <div className="mt-5 flex justify-end gap-2">
        <Button type="button" variant="ghost" size="sm" onClick={onCancel} disabled={loading}>
          {cancelLabel}
        </Button>
        <Button type="submit" size="sm" loading={loading} disabled={!value.trim()}>
          {confirmLabel}
        </Button>
      </div>
    </form>
  );
}

export function PromptDialog({
  open,
  title,
  message,
  placeholder,
  confirmLabel = 'Save',
  cancelLabel = 'Cancel',
  loading = false,
  onSubmit,
  onCancel,
}: PromptDialogProps) {
  return (
    <DialogShell open={open} onClose={onCancel}>
      <h3 className="font-[family-name:var(--font-urbanist)] text-base font-semibold text-ark-text">{title}</h3>
      <PromptForm
        message={message}
        placeholder={placeholder}
        confirmLabel={confirmLabel}
        cancelLabel={cancelLabel}
        loading={loading}
        onSubmit={onSubmit}
        onCancel={onCancel}
      />
    </DialogShell>
  );
}
