import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import { demoReminders } from '@/lib/demo-data';
import type { DCAReminder } from '@/types';

function getSupabase() {
  return createClient();
}

export async function fetchDCAReminders(userId: string): Promise<DCAReminder[]> {
  if (!isSupabaseConfigured()) return demoReminders;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('dca_reminders')
    .select('*')
    .eq('user_id', userId)
    .order('next_reminder_date', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function fetchActiveReminders(userId: string): Promise<DCAReminder[]> {
  if (!isSupabaseConfigured()) return demoReminders.filter(r => r.is_active);
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('dca_reminders')
    .select('*')
    .eq('user_id', userId)
    .eq('is_active', true)
    .order('next_reminder_date', { ascending: true });
  if (error) throw error;
  return data ?? [];
}
