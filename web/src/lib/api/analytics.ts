import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Fire-and-forget write to `analytics_events`.
 *
 * RLS on that table is `auth.uid() = user_id`, so the insert MUST carry the
 * signed-in user's id — anonymous events are rejected and silently dropped.
 */
export async function logEvent(
  eventName: string,
  properties: Record<string, string | number | boolean> = {},
): Promise<void> {
  if (!isSupabaseConfigured()) return;
  try {
    const supabase = createClient();
    const { data } = await supabase.auth.getUser();
    const userId = data?.user?.id;
    if (!userId) return;

    await supabase.from('analytics_events').insert({
      user_id: userId,
      event_name: eventName,
      properties,
    });
  } catch {
    // Analytics must never surface an error to the user.
  }
}
