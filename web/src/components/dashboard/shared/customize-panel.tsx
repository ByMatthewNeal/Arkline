'use client';

/**
 * Slide-over customize panel — shared by Home and Market dashboards.
 * Mirrors the iOS Customize sheet: per-widget toggles, show/hide all,
 * and up to 2 saveable presets (layout + visibility snapshots).
 */

import { useState } from 'react';
import { motion } from 'framer-motion';
import { X, Check } from 'lucide-react';
import { cn } from '@/lib/utils/format';
import { useDashboardPresets } from '@/lib/hooks/use-dashboard-presets';

export function CustomizePanel({
  title,
  layoutKey,
  widgetKeys,
  widgetTitles,
  isEnabled,
  toggle,
  setAll,
  onClose,
}: {
  title: string;
  layoutKey: string;
  widgetKeys: readonly string[];
  widgetTitles: Record<string, string>;
  isEnabled: (k: string) => boolean;
  toggle: (k: string) => void;
  setAll: (on: boolean) => void;
  onClose: () => void;
}) {
  const enabledCount = widgetKeys.filter(isEnabled).length;
  const { presets, saveCurrent, apply, remove, canSave } = useDashboardPresets(layoutKey);
  const [presetName, setPresetName] = useState('');

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />
      <motion.div
        initial={{ x: 24, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        transition={{ duration: 0.25 }}
        className="relative flex h-full w-full max-w-sm flex-col border-l border-ark-divider bg-ark-bg shadow-2xl"
      >
        <div className="flex items-center justify-between border-b border-ark-divider p-4">
          <div>
            <h3 className="font-[family-name:var(--font-urbanist)] text-base font-semibold text-ark-text">{title}</h3>
            <p className="text-[11px] text-ark-text-disabled">{enabledCount} of {widgetKeys.length} widgets shown</p>
          </div>
          <button onClick={onClose} className="flex h-8 w-8 items-center justify-center rounded-lg text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary">
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Presets */}
        <div className="border-b border-ark-divider px-4 py-3">
          <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">Presets</p>
          {presets.length > 0 && (
            <div className="mt-2 space-y-1.5">
              {presets.map((p) => (
                <div key={p.name} className="flex items-center gap-2">
                  <button onClick={() => apply(p.name)} className="flex-1 rounded-lg bg-ark-fill-secondary/50 px-3 py-1.5 text-left text-sm text-ark-text transition-colors hover:bg-ark-fill-secondary">{p.name}</button>
                  <button onClick={() => remove(p.name)} className="flex h-7 w-7 items-center justify-center rounded-lg text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary"><X className="h-3.5 w-3.5" /></button>
                </div>
              ))}
            </div>
          )}
          <div className="mt-2 flex items-center gap-2">
            <input
              value={presetName}
              onChange={(e) => setPresetName(e.target.value)}
              placeholder={canSave ? 'Save current as…' : 'Max 2 presets'}
              disabled={!canSave}
              className="h-8 flex-1 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2.5 text-xs text-ark-text outline-none placeholder:text-ark-text-tertiary focus:border-ark-primary disabled:opacity-50"
            />
            <button
              onClick={() => { saveCurrent(presetName); setPresetName(''); }}
              disabled={!canSave || !presetName.trim()}
              className="rounded-lg bg-ark-primary px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-ark-accent-dark disabled:opacity-40"
            >Save</button>
          </div>
        </div>

        <div className="flex items-center gap-2 border-b border-ark-divider px-4 py-2">
          <button onClick={() => setAll(true)} className="rounded-lg px-2.5 py-1 text-[11px] font-medium text-ark-primary transition-colors hover:bg-ark-fill-secondary">Show all</button>
          <button onClick={() => setAll(false)} className="rounded-lg px-2.5 py-1 text-[11px] font-medium text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary">Hide all</button>
        </div>
        <div className="flex-1 overflow-y-auto p-2">
          {widgetKeys.map((key) => {
            const on = isEnabled(key);
            return (
              <button
                key={key}
                onClick={() => toggle(key)}
                className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-left transition-colors hover:bg-ark-fill-secondary"
              >
                <span className={cn('text-sm', on ? 'text-ark-text' : 'text-ark-text-tertiary')}>{widgetTitles[key] ?? key}</span>
                <span className={cn('flex h-5 w-9 items-center rounded-full px-0.5 transition-colors', on ? 'justify-end bg-ark-primary' : 'justify-start bg-ark-fill-secondary')}>
                  <span className="flex h-4 w-4 items-center justify-center rounded-full bg-white">
                    {on && <Check className="h-2.5 w-2.5 text-ark-primary" />}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      </motion.div>
    </div>
  );
}
