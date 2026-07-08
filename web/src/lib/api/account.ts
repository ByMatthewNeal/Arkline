import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Delete all of the user's data, then sign out.
 *
 * Mirrors iOS `SettingsViewModel.deleteAccount()`: row-level deletes across
 * every user-owned table (order matters for foreign keys), continuing past
 * individual failures. Like iOS, the auth user itself can't be deleted
 * client-side — that requires a service-role edge function; until one exists
 * this removes all data and signs the user out.
 */
export async function deleteAccountData(userId: string): Promise<void> {
  if (!isSupabaseConfigured()) return;
  const supabase = createClient();

  // Portfolio-scoped tables need portfolio ids first.
  let portfolioIds: string[] = [];
  try {
    const { data } = await supabase.from('portfolios').select('id').eq('user_id', userId);
    portfolioIds = (data ?? []).map((r: { id: string }) => r.id);
  } catch {
    // continue — user-scoped deletes below still run
  }

  const byPortfolio = ['portfolio_history', 'transactions', 'holdings'];
  const byUser: [table: string, column: string][] = [
    ['risk_dca_investments', 'user_id'],
    ['risk_based_dca_reminders', 'user_id'],
    ['dca_reminders', 'user_id'],
    ['broadcast_reads', 'user_id'],
    ['broadcast_reactions', 'user_id'],
    ['broadcast_bookmarks', 'user_id'],
    ['member_question_likes', 'user_id'],
    ['community_posts', 'user_id'],
    ['user_devices', 'user_id'],
    ['feature_requests', 'user_id'],
    ['favorites', 'user_id'],
  ];

  for (const table of byPortfolio) {
    for (const pid of portfolioIds) {
      try {
        await supabase.from(table).delete().eq('portfolio_id', pid);
      } catch {
        // continue cleanup even if an individual table delete fails (matches iOS)
      }
    }
  }

  for (const [table, column] of byUser) {
    try {
      await supabase.from(table).delete().eq(column, userId);
    } catch {
      // continue
    }
  }

  // Portfolios after their children, profile last.
  try {
    await supabase.from('portfolios').delete().eq('user_id', userId);
  } catch {
    // continue
  }
  try {
    await supabase.from('profiles').delete().eq('id', userId);
  } catch {
    // continue
  }

  await supabase.auth.signOut();
}
