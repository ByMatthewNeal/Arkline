'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Sun, Moon, Monitor, Bell, DollarSign, Shield, Trash2, Check, BookOpen, HelpCircle, MessagesSquare, ChevronRight, Lightbulb } from 'lucide-react';
import { GlassCard, Button, Badge, ConfirmDialog, useToast } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { useTheme } from '@/lib/hooks/use-theme';
import { createClient } from '@/lib/supabase/client';
import { deleteAccountData } from '@/lib/api/account';
import { setPreferredCurrency } from '@/lib/utils/format';
import { subscribeToPush, unsubscribeFromPush, isPushSupported, isPushConfigured } from '@/lib/push';
import { FeatureRequestModal } from '@/components/dashboard/shared/feature-request';
import type { NotificationPreferences } from '@/types';

const currencies = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF'] as const;

const themeOptions = [
  { value: 'light' as const, label: 'Light', icon: Sun },
  { value: 'dark' as const, label: 'Dark', icon: Moon },
  { value: 'system' as const, label: 'System', icon: Monitor },
];

/**
 * UI state for server push gating. Mirrors iOS NotificationsDetailView:
 * `signals` is the parent for the four signal sub-toggles; the full
 * notification_preferences map is derived from this on save.
 */
interface PrefsState {
  signals: boolean;
  signalT1Hit: boolean;
  signalStopLoss: boolean;
  signalRunnerClose: boolean;
  signalExpiry: boolean;
  modelPortfolio: boolean;
  breadth: boolean;
  rotation: boolean;
  qps: boolean;
  briefings: boolean;
  broadcast: boolean;
}

/** Server semantics: a missing key means enabled. */
function prefsFromProfile(p?: Partial<NotificationPreferences>): PrefsState {
  const on = (k: keyof NotificationPreferences) => p?.[k] !== false;
  return {
    signals: on('signal_new'),
    signalT1Hit: on('signal_t1_hit'),
    signalStopLoss: on('signal_stop_loss'),
    signalRunnerClose: on('signal_runner_close'),
    signalExpiry: on('signal_expiry'),
    modelPortfolio: on('model_portfolio_rebalance'),
    breadth: on('breadth_crossover'),
    rotation: on('rotation_regime_change'),
    qps: on('qps_change'),
    briefings: on('briefings'),
    broadcast: on('broadcast'),
  };
}

/** Authoritative, complete write — same shape iOS's syncSignalPreferences() sends. */
function prefsToMap(s: PrefsState): NotificationPreferences {
  return {
    signal_new: s.signals,
    signal_proximity: s.signals,
    signal_t1_hit: s.signals && s.signalT1Hit,
    signal_stop_loss: s.signals && s.signalStopLoss,
    signal_runner_close: s.signals && s.signalRunnerClose,
    signal_expiry: s.signals && s.signalExpiry,
    model_portfolio_rebalance: s.modelPortfolio,
    breadth_crossover: s.breadth,
    rotation_regime_change: s.rotation,
    qps_change: s.qps,
    briefings: s.briefings,
    broadcast: s.broadcast,
  };
}

function ToggleRow({
  label,
  description,
  checked,
  onChange,
}: {
  label: string;
  description: string;
  checked: boolean;
  onChange: (val: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between py-3">
      <div>
        <p className="text-sm font-medium text-ark-text">{label}</p>
        <p className="text-xs text-ark-text-tertiary">{description}</p>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className={`
          relative h-6 w-11 shrink-0 cursor-pointer rounded-full transition-colors
          ${checked ? 'bg-ark-primary' : 'bg-ark-divider'}
        `}
      >
        <span
          className={`
            absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform
            ${checked ? 'translate-x-5' : 'translate-x-0'}
          `}
        />
      </button>
    </div>
  );
}

export default function SettingsPage() {
  const { profile } = useAuth();
  const { theme, setTheme } = useTheme();
  const [currency, setCurrency] = useState(profile?.preferred_currency ?? 'USD');
  const [pushEnabled, setPushEnabled] = useState(true);
  const [prefs, setPrefs] = useState<PrefsState>(() => prefsFromProfile(profile?.notification_preferences));
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [featureRequestOpen, setFeatureRequestOpen] = useState(false);
  const toast = useToast();

  const updatePref = (key: keyof PrefsState, value: boolean) => {
    setPrefs((prev) => ({ ...prev, [key]: value }));
  };

  // Master push toggle actually subscribes/unsubscribes this browser
  // (stored in user_devices, platform 'web' — the APNs equivalent).
  const handlePushToggle = async (on: boolean) => {
    setPushEnabled(on);
    if (!profile) return;
    if (on) {
      if (!isPushSupported()) {
        toast.info('This browser does not support push notifications.');
        return;
      }
      if (!isPushConfigured()) {
        toast.info('Browser push is coming soon — your preference is saved.');
        return;
      }
      try {
        const result = await subscribeToPush(profile.id);
        if (result === 'subscribed') toast.success('Push notifications enabled for this browser');
        else if (result === 'denied') {
          setPushEnabled(false);
          toast.error('Notifications are blocked — allow them in your browser settings.');
        }
      } catch {
        toast.error('Could not enable push notifications.');
      }
    } else {
      try {
        await unsubscribeFromPush(profile.id);
      } catch { /* row cleanup is best-effort */ }
    }
  };

  const handleSave = async () => {
    if (!profile) return;
    setSaving(true);
    try {
      const supabase = createClient();
      const { error } = await supabase
        .from('profiles')
        .update({
          preferred_currency: currency,
          // Server push gating — the column send-broadcast-notification reads.
          notification_preferences: prefsToMap(prefs),
          dark_mode: theme,
        })
        .eq('id', profile.id);
      if (error) throw error;
      // Apply immediately app-wide (formatting only — values stay USD-denominated, matching iOS).
      setPreferredCurrency(currency);
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } catch {
      toast.error('Could not save settings. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (!profile) return;
    setDeleting(true);
    try {
      await deleteAccountData(profile.id);
      window.location.href = '/';
    } catch {
      setDeleting(false);
      setDeleteConfirm(false);
      toast.error('Account deletion failed. Please contact support.');
    }
  };

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text">
        Settings
      </h1>

      {/* Appearance */}
      <GlassCard>
        <div className="mb-4 flex items-center gap-2">
          <Sun className="h-4 w-4 text-ark-text-tertiary" />
          <h2 className="text-sm font-semibold text-ark-text">Appearance</h2>
        </div>
        <div className="grid grid-cols-3 gap-2">
          {themeOptions.map((opt) => (
            <button
              key={opt.value}
              onClick={() => setTheme(opt.value)}
              className={`
                flex flex-col items-center gap-2 rounded-xl px-3 py-4 text-sm font-medium
                transition-colors cursor-pointer
                ${
                  theme === opt.value
                    ? 'bg-ark-primary/10 text-ark-primary ring-2 ring-ark-primary'
                    : 'bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-divider'
                }
              `}
            >
              <opt.icon className="h-5 w-5" />
              {opt.label}
            </button>
          ))}
        </div>
      </GlassCard>

      {/* Currency */}
      <GlassCard>
        <div className="mb-4 flex items-center gap-2">
          <DollarSign className="h-4 w-4 text-ark-text-tertiary" />
          <h2 className="text-sm font-semibold text-ark-text">Preferred Currency</h2>
        </div>
        <div className="flex flex-wrap gap-2">
          {currencies.map((c) => (
            <button
              key={c}
              onClick={() => setCurrency(c)}
              className={`
                rounded-lg px-3 py-1.5 text-sm font-medium transition-colors cursor-pointer
                ${
                  currency === c
                    ? 'bg-ark-primary text-white'
                    : 'bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-divider'
                }
              `}
            >
              {c}
            </button>
          ))}
        </div>
      </GlassCard>

      {/* Notifications */}
      <GlassCard>
        <div className="mb-2 flex items-center gap-2">
          <Bell className="h-4 w-4 text-ark-text-tertiary" />
          <h2 className="text-sm font-semibold text-ark-text">Notifications</h2>
        </div>
        <div className="divide-y divide-ark-divider">
          <ToggleRow
            label="Push Notifications"
            description="Enable browser push on this device"
            checked={pushEnabled}
            onChange={handlePushToggle}
          />
          <ToggleRow
            label="Trade Signals"
            description="New setups, entry-zone proximity, and outcome alerts"
            checked={prefs.signals}
            onChange={(v) => updatePref('signals', v)}
          />
          {prefs.signals && (
            <div className="ml-4 divide-y divide-ark-divider/60 border-l-2 border-ark-divider pl-4">
              <ToggleRow label="Target 1 hit" description="When a signal reaches T1" checked={prefs.signalT1Hit} onChange={(v) => updatePref('signalT1Hit', v)} />
              <ToggleRow label="Stop loss" description="When a signal is stopped out" checked={prefs.signalStopLoss} onChange={(v) => updatePref('signalStopLoss', v)} />
              <ToggleRow label="Runner close" description="When a trailing runner closes" checked={prefs.signalRunnerClose} onChange={(v) => updatePref('signalRunnerClose', v)} />
              <ToggleRow label="Expiry" description="When a signal expires" checked={prefs.signalExpiry} onChange={(v) => updatePref('signalExpiry', v)} />
            </div>
          )}
          <ToggleRow
            label="Model Portfolio Rebalances"
            description="When a strategy you follow rebalances"
            checked={prefs.modelPortfolio}
            onChange={(v) => updatePref('modelPortfolio', v)}
          />
          <ToggleRow
            label="Market Breadth Crossovers"
            description="EMA breadth crossover alerts"
            checked={prefs.breadth}
            onChange={(v) => updatePref('breadth', v)}
          />
          <ToggleRow
            label="Rotation Regime Shifts"
            description="Crypto ↔ equities rotation changes"
            checked={prefs.rotation}
            onChange={(v) => updatePref('rotation', v)}
          />
          <ToggleRow
            label="Positioning Changes"
            description="Daily positioning (QPS) signal changes"
            checked={prefs.qps}
            onChange={(v) => updatePref('qps', v)}
          />
          <ToggleRow
            label="Daily Briefings"
            description="Morning AI market briefing"
            checked={prefs.briefings}
            onChange={(v) => updatePref('briefings', v)}
          />
          <ToggleRow
            label="Insights & Broadcasts"
            description="New insights published in the Insights tab"
            checked={prefs.broadcast}
            onChange={(v) => updatePref('broadcast', v)}
          />
        </div>
        <p className="mt-2 text-[11px] text-ark-text-tertiary">
          These preferences apply to pushes on all your devices, including the iOS app. Remember to save.
        </p>
      </GlassCard>

      {/* Resources */}
      <GlassCard>
        <div className="mb-3 flex items-center gap-2">
          <BookOpen className="h-4 w-4 text-ark-text-tertiary" />
          <h2 className="text-sm font-semibold text-ark-text">Resources</h2>
        </div>
        <div className="divide-y divide-ark-divider/60">
          <Link href="/dashboard/dictionary" className="flex items-center gap-3 py-3 transition-colors hover:opacity-80">
            <BookOpen className="h-4 w-4 text-ark-info" />
            <div className="flex-1"><p className="text-sm font-medium text-ark-text">Dictionary</p><p className="text-xs text-ark-text-disabled">Crypto &amp; investing terms explained</p></div>
            <ChevronRight className="h-4 w-4 text-ark-text-disabled" />
          </Link>
          <Link href="/dashboard/faq" className="flex items-center gap-3 py-3 transition-colors hover:opacity-80">
            <HelpCircle className="h-4 w-4 text-ark-primary" />
            <div className="flex-1"><p className="text-sm font-medium text-ark-text">FAQ</p><p className="text-xs text-ark-text-disabled">Answers to common questions</p></div>
            <ChevronRight className="h-4 w-4 text-ark-text-disabled" />
          </Link>
          <Link href="/dashboard/qa" className="flex items-center gap-3 py-3 transition-colors hover:opacity-80">
            <MessagesSquare className="h-4 w-4 text-ark-violet" />
            <div className="flex-1"><p className="text-sm font-medium text-ark-text">Member Q&amp;A</p><p className="text-xs text-ark-text-disabled">Ask the Arkline team a question</p></div>
            <ChevronRight className="h-4 w-4 text-ark-text-disabled" />
          </Link>
          <button onClick={() => setFeatureRequestOpen(true)} className="flex w-full items-center gap-3 py-3 text-left transition-colors hover:opacity-80">
            <Lightbulb className="h-4 w-4 text-ark-warning" />
            <div className="flex-1"><p className="text-sm font-medium text-ark-text">Request a Feature / Report a Bug</p><p className="text-xs text-ark-text-disabled">Tell us what to build next — or what broke</p></div>
            <ChevronRight className="h-4 w-4 text-ark-text-disabled" />
          </button>
        </div>
      </GlassCard>

      <FeatureRequestModal open={featureRequestOpen} onClose={() => setFeatureRequestOpen(false)} />

      {/* Subscription */}
      <GlassCard>
        <div className="mb-4 flex items-center gap-2">
          <Shield className="h-4 w-4 text-ark-text-tertiary" />
          <h2 className="text-sm font-semibold text-ark-text">Subscription</h2>
        </div>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-ark-text">
              Current plan:{' '}
              <span className="font-semibold capitalize">{profile?.role ?? 'user'}</span>
            </p>
            <p className="text-xs text-ark-text-tertiary">
              Status:{' '}
              <Badge
                variant={
                  profile?.subscription_status === 'active'
                    ? 'success'
                    : profile?.subscription_status === 'trialing'
                      ? 'info'
                      : 'default'
                }
              >
                {profile?.subscription_status ?? 'none'}
              </Badge>
            </p>
          </div>
        </div>
        <p className="mt-3 text-xs text-ark-text-tertiary">
          Subscriptions are managed on the web — contact support for billing changes.
        </p>
      </GlassCard>

      {/* Danger Zone */}
      <GlassCard className="border border-ark-error/20">
        <div className="mb-4 flex items-center gap-2">
          <Trash2 className="h-4 w-4 text-ark-error" />
          <h2 className="text-sm font-semibold text-ark-error">Danger Zone</h2>
        </div>
        <p className="text-sm text-ark-text-secondary">
          Permanently delete your account and all associated data. This action cannot be undone.
        </p>
        <Button
          variant="danger"
          size="sm"
          className="mt-3"
          onClick={() => setDeleteConfirm(true)}
        >
          Delete Account
        </Button>
        <ConfirmDialog
          open={deleteConfirm}
          title="Delete your account?"
          message="This permanently deletes your portfolios, transactions, DCA reminders, and profile data. This action cannot be undone."
          confirmLabel="Yes, delete everything"
          destructive
          loading={deleting}
          onConfirm={handleDeleteAccount}
          onCancel={() => setDeleteConfirm(false)}
        />
      </GlassCard>

      {/* Save */}
      <div className="sticky bottom-20 md:bottom-4">
        <Button onClick={handleSave} loading={saving} className="w-full">
          {saved ? (
            <>
              <Check className="h-4 w-4" />
              Saved
            </>
          ) : (
            'Save Changes'
          )}
        </Button>
      </div>
    </div>
  );
}
