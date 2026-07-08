'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Sun, Moon, Monitor, Bell, DollarSign, Shield, Trash2, Check, BookOpen, HelpCircle, MessagesSquare, ChevronRight } from 'lucide-react';
import { GlassCard, Button, Badge, ConfirmDialog, useToast } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { useTheme } from '@/lib/hooks/use-theme';
import { createClient } from '@/lib/supabase/client';
import { deleteAccountData } from '@/lib/api/account';
import { setPreferredCurrency } from '@/lib/utils/format';
import type { NotificationSettings } from '@/types';

const currencies = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF'] as const;

const themeOptions = [
  { value: 'light' as const, label: 'Light', icon: Sun },
  { value: 'dark' as const, label: 'Dark', icon: Moon },
  { value: 'system' as const, label: 'System', icon: Monitor },
];

const defaultNotifications: NotificationSettings = {
  push_enabled: true,
  email_enabled: false,
  dca_reminders: true,
  extreme_moves: true,
  sentiment_shifts: false,
  insights: true,
};

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
  const [notifications, setNotifications] = useState<NotificationSettings>(
    profile?.notifications ?? defaultNotifications,
  );
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const toast = useToast();

  const updateNotification = (key: keyof NotificationSettings, value: boolean) => {
    setNotifications((prev) => ({ ...prev, [key]: value }));
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
          notifications,
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
            description="Browser push notifications for alerts"
            checked={notifications.push_enabled}
            onChange={(v) => updateNotification('push_enabled', v)}
          />
          <ToggleRow
            label="Email Notifications"
            description="Email alerts for important events"
            checked={notifications.email_enabled}
            onChange={(v) => updateNotification('email_enabled', v)}
          />
          <ToggleRow
            label="DCA Reminders"
            description="Notify when it's time to DCA"
            checked={notifications.dca_reminders}
            onChange={(v) => updateNotification('dca_reminders', v)}
          />
          <ToggleRow
            label="Extreme Moves"
            description="Alert on large price swings"
            checked={notifications.extreme_moves}
            onChange={(v) => updateNotification('extreme_moves', v)}
          />
          <ToggleRow
            label="Sentiment Shifts"
            description="Fear & Greed zone changes"
            checked={notifications.sentiment_shifts}
            onChange={(v) => updateNotification('sentiment_shifts', v)}
          />
          <ToggleRow
            label="AI Insights"
            description="Daily AI-generated briefing notifications"
            checked={notifications.insights}
            onChange={(v) => updateNotification('insights', v)}
          />
        </div>
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
        </div>
      </GlassCard>

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
