'use client';

/**
 * Feature request form — mirrors iOS FeatureRequestFormView.
 * Writes to the same `feature_requests` table (category, title, description,
 * author_id/email, status 'pending') so requests land in the same admin
 * backlog triage on iOS.
 */

import { useState } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { X, Lightbulb } from 'lucide-react';
import { Button, useToast } from '@/components/ui';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import { useAuth } from '@/lib/hooks/use-auth';
import { useMounted } from '@/lib/hooks/use-mounted';
import { cn } from '@/lib/utils/format';

const CATEGORIES = [
  { key: 'portfolio', label: 'Portfolio & DCA' },
  { key: 'market', label: 'Market Data & Charts' },
  { key: 'signals', label: 'Signals & Alerts' },
  { key: 'insights', label: 'Insights' },
  { key: 'ai_briefings', label: 'AI Briefings' },
  { key: 'risk_analysis', label: 'Risk Analysis' },
  { key: 'ui_ux', label: 'UI / UX' },
  { key: 'other', label: 'Other' },
] as const;

const MAX_TITLE = 80;
const MAX_DESC = 600;

export function FeatureRequestModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const mounted = useMounted();
  const { authUser, profile } = useAuth();
  const toast = useToast();

  const [category, setCategory] = useState<string>('other');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [saving, setSaving] = useState(false);

  const valid =
    title.trim().length > 0 && title.length <= MAX_TITLE &&
    description.trim().length > 0 && description.length <= MAX_DESC;

  const submit = async () => {
    if (!valid || !authUser || !isSupabaseConfigured()) return;
    setSaving(true);
    try {
      const supabase = createClient();
      const { error } = await supabase.from('feature_requests').insert({
        title: title.trim(),
        description: description.trim(),
        category,
        author_id: authUser.id,
        author_email: authUser.email ?? profile?.email ?? null,
        status: 'pending',
      });
      if (error) throw error;
      toast.success('Request submitted — thanks for the idea!');
      setTitle('');
      setDescription('');
      setCategory('other');
      onClose();
    } catch {
      toast.error('Could not submit your request. Please try again.');
    } finally {
      setSaving(false);
    }
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
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-ark-warning/10">
                  <Lightbulb className="h-4 w-4 text-ark-warning" />
                </div>
                <h3 className="font-[family-name:var(--font-urbanist)] text-base font-semibold text-ark-text">Request a feature</h3>
              </div>
              <button onClick={onClose} className="flex h-8 w-8 items-center justify-center rounded-lg text-ark-text-tertiary hover:bg-ark-fill-secondary">
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="mt-4 space-y-4">
              <div>
                <p className="mb-1.5 text-xs font-semibold text-ark-text-secondary">Category</p>
                <div className="flex flex-wrap gap-1.5">
                  {CATEGORIES.map((c) => (
                    <button
                      key={c.key}
                      onClick={() => setCategory(c.key)}
                      className={cn(
                        'rounded-full px-2.5 py-1 text-[11px] font-medium transition-colors',
                        category === c.key ? 'bg-ark-primary text-white' : 'bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-divider',
                      )}
                    >
                      {c.label}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <div className="mb-1.5 flex items-center justify-between">
                  <p className="text-xs font-semibold text-ark-text-secondary">Title</p>
                  <span className={cn('fig text-[10px]', title.length > MAX_TITLE ? 'text-ark-error' : 'text-ark-text-disabled')}>{title.length}/{MAX_TITLE}</span>
                </div>
                <input
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="What would you like to see?"
                  className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary px-3 text-sm text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
                />
              </div>

              <div>
                <div className="mb-1.5 flex items-center justify-between">
                  <p className="text-xs font-semibold text-ark-text-secondary">Details</p>
                  <span className={cn('fig text-[10px]', description.length > MAX_DESC ? 'text-ark-error' : 'text-ark-text-disabled')}>{description.length}/{MAX_DESC}</span>
                </div>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={4}
                  placeholder="Describe the feature and why it would help you…"
                  className="w-full resize-none rounded-xl border border-ark-divider bg-ark-fill-secondary p-3 text-sm text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
                />
              </div>

              <div className="flex justify-end gap-2">
                <Button variant="ghost" size="sm" onClick={onClose} disabled={saving}>Cancel</Button>
                <Button size="sm" onClick={submit} loading={saving} disabled={!valid}>Submit request</Button>
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body,
  );
}
