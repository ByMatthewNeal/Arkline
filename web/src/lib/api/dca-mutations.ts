import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import type { DCAReminder } from '@/types';

function getSupabase() {
  return createClient();
}

function advance(fromISO: string, freq: string): string {
  const d = new Date(fromISO + (fromISO.length <= 10 ? 'T12:00:00' : ''));
  switch (freq) {
    case 'daily': d.setDate(d.getDate() + 1); break;
    case 'twice_weekly': d.setDate(d.getDate() + 3); break;
    case 'weekly': d.setDate(d.getDate() + 7); break;
    case 'biweekly': d.setDate(d.getDate() + 14); break;
    case 'monthly': d.setMonth(d.getMonth() + 1); break;
    default: d.setDate(d.getDate() + 7);
  }
  return d.toISOString().split('T')[0];
}

export interface DCAReminderInput {
  symbol: string;
  name: string;
  amount: number;
  frequency: string;
  notification_time: string; // HH:MM
  start_date: string;        // YYYY-MM-DD
}

export async function createReminder(userId: string, input: DCAReminderInput): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const { error } = await supabase.from('dca_reminders').insert({
    user_id: userId,
    symbol: input.symbol.toUpperCase(),
    name: input.name,
    amount: input.amount,
    frequency: input.frequency,
    notification_time: input.notification_time.length === 5 ? `${input.notification_time}:00` : input.notification_time,
    start_date: input.start_date,
    next_reminder_date: advance(input.start_date, input.frequency),
    is_active: true,
    completed_purchases: 0,
  });
  if (error) throw error;
}

export async function updateReminder(id: string, patch: Partial<DCAReminderInput> & { is_active?: boolean }): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const body: Record<string, unknown> = { updated_at: new Date().toISOString() };
  if (patch.symbol != null) body.symbol = patch.symbol.toUpperCase();
  if (patch.name != null) body.name = patch.name;
  if (patch.amount != null) body.amount = patch.amount;
  if (patch.frequency != null) body.frequency = patch.frequency;
  if (patch.notification_time != null) body.notification_time = patch.notification_time.length === 5 ? `${patch.notification_time}:00` : patch.notification_time;
  if (patch.start_date != null) body.start_date = patch.start_date;
  if (patch.is_active != null) body.is_active = patch.is_active;
  const { error } = await supabase.from('dca_reminders').update(body).eq('id', id);
  if (error) throw error;
}

export async function deleteReminder(id: string): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const { error } = await supabase.from('dca_reminders').delete().eq('id', id);
  if (error) throw error;
}

// Marks one scheduled buy as done: bumps the purchase count and rolls the next date forward.
export async function logInvestment(reminder: DCAReminder): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = getSupabase();
  const base = reminder.next_reminder_date ?? new Date().toISOString().split('T')[0];
  const { error } = await supabase.from('dca_reminders').update({
    completed_purchases: (reminder.completed_purchases ?? 0) + 1,
    next_reminder_date: advance(base, reminder.frequency),
    updated_at: new Date().toISOString(),
  }).eq('id', reminder.id);
  if (error) throw error;
}
