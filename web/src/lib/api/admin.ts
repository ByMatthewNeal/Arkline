import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Admin API — all calls are admin-gated server-side (edge functions verify
 * the JWT's profile role; table access rides is_admin() RLS; the readers RPC
 * raises for non-admins). The web UI hides these behind role === 'admin',
 * but the server is the enforcement point.
 */

/* ── Members (admin-members edge function) ── */

export interface AdminSubscription {
  id: string;
  user_id: string;
  source: 'stripe' | 'apple' | 'comp' | string;
  plan: string | null;
  status: string;
  current_period_start: string | null;
  current_period_end: string | null;
  trial_end: string | null;
}

export interface AdminMember {
  id: string;
  email: string | null;
  username: string | null;
  full_name: string | null;
  role: string;
  subscription_status: string | null;
  is_active: boolean | null;
  created_at: string;
  is_internal: boolean;
  subscriptions: AdminSubscription[];
}

export type MemberFilter = 'all' | 'paying' | 'comp' | 'none' | 'active' | 'canceled';

export async function fetchMembers(opts: { search?: string; status?: MemberFilter; page?: number } = {}): Promise<{ members: AdminMember[]; total: number }> {
  if (!isSupabaseConfigured()) return { members: [], total: 0 };
  const supabase = createClient();
  const { data, error } = await supabase.functions.invoke('admin-members', {
    body: { search: opts.search || null, status: opts.status ?? 'all', page: opts.page ?? 1, per_page: 100 },
  });
  if (error) throw error;
  return { members: data?.members ?? [], total: data?.total ?? 0 };
}

/* ── Revenue metrics (get-admin-metrics edge function) ── */

export interface AdminMetrics {
  mrr: number;
  arr: number;
  revenue_breakdown?: Record<string, number>;
  comped_active: number;
  comped_potential_mrr: number;
  comped_potential_arr: number;
  trials_active: number;
  trial_potential_mrr: number;
  total_members: number;
  active_members: number;
  trialing_members: number;
  past_due_members: number;
  canceled_members: number;
  incomplete_members: number;
  churn_rate: number;
  founding_members: number;
  founding_pending: number;
  founding_remaining: number;
}

export async function fetchAdminMetrics(): Promise<AdminMetrics | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = createClient();
  const { data, error } = await supabase.functions.invoke('get-admin-metrics', { body: {} });
  if (error) throw error;
  return data as AdminMetrics;
}

/* ── Comp a member (grant-comp edge function) ── */

export interface GrantCompInput {
  email: string;
  tier?: 'founding' | 'standard';
  plan?: 'monthly' | 'annual';
  days?: number; // 0 = forever
  revoke?: boolean;
}

export async function grantComp(input: GrantCompInput): Promise<{ ok: boolean; message?: string }> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = createClient();
  const { data, error } = await supabase.functions.invoke('grant-comp', { body: input });
  if (error) throw error;
  return data as { ok: boolean; message?: string };
}

/* ── Invite codes (generate-invite edge function) ── */

export interface GenerateInviteInput {
  email?: string;
  recipient_name?: string;
  note?: string;
  expiration_days?: number;
  trial_days?: number;
  comped?: boolean;
  tier?: string;
  send_email?: boolean;
  created_by?: string;
}

export async function generateInvite(input: GenerateInviteInput): Promise<{ code?: string; invite_code?: string; [k: string]: unknown }> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = createClient();
  const { data, error } = await supabase.functions.invoke('generate-invite', { body: input });
  if (error) throw error;
  return data as { code?: string; invite_code?: string };
}

/* ── System health (health-check edge function, admin-JWT path) ── */

export interface HealthCheckResult {
  name: string;
  ok: boolean;
  detail: string;
}

export interface HealthReport {
  healthy: boolean;
  checks: HealthCheckResult[];
  timestamp?: string;
}

export async function fetchHealth(): Promise<HealthReport> {
  if (!isSupabaseConfigured()) return { healthy: false, checks: [] };
  const supabase = createClient();
  const { data, error } = await supabase.functions.invoke('health-check', { body: {} });
  if (error) throw error;
  return data as HealthReport;
}

/* ── Broadcast readers (get_broadcast_readers RPC — SECURITY DEFINER) ── */

export interface BroadcastReader {
  user_id: string;
  display_name: string | null;
  email: string | null;
  read_at: string;
}

export async function fetchBroadcastReaders(broadcastId: string): Promise<BroadcastReader[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  const { data, error } = await supabase.rpc('get_broadcast_readers', { p_broadcast_id: broadcastId });
  if (error) throw error;
  return (data ?? []) as BroadcastReader[];
}

/** Feed reach (impressions) — distinct users who saw the card in their feed. */
export async function fetchBroadcastReach(broadcastId: string): Promise<number> {
  if (!isSupabaseConfigured()) return 0;
  const supabase = createClient();
  const { data, error } = await supabase
    .from('broadcast_impressions')
    .select('user_id')
    .eq('broadcast_id', broadcastId);
  if (error) return 0;
  return new Set((data ?? []).map((r: { user_id: string }) => r.user_id)).size;
}

/* ── Feature requests / bug reports (direct table via is_admin() RLS) ── */

export interface FeatureRequestRow {
  id: string;
  title: string;
  description: string;
  category: string | null;
  author_email: string | null;
  status: string;
  priority: string | null;
  vote_count: number | null;
  created_at: string;
  admin_notes: string | null;
  ai_analysis: string | null;
  request_type: string | null; // 'feature' | 'bug'
  app_version: string | null;
  device_info: string | null;
}

export async function fetchFeatureRequests(): Promise<FeatureRequestRow[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  const { data, error } = await supabase
    .from('feature_requests')
    .select('id, title, description, category, author_email, status, priority, vote_count, created_at, admin_notes, ai_analysis, request_type, app_version, device_info')
    .order('created_at', { ascending: false })
    .limit(200);
  if (error) throw error;
  return (data ?? []) as FeatureRequestRow[];
}

export async function updateFeatureRequest(id: string, patch: Partial<Pick<FeatureRequestRow, 'status' | 'priority' | 'admin_notes'>>): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase
    .from('feature_requests')
    .update({ ...patch, reviewed_at: new Date().toISOString() })
    .eq('id', id);
  if (error) throw error;
}

export async function deleteFeatureRequest(id: string): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.from('feature_requests').delete().eq('id', id);
  if (error) throw error;
}

/* ── Broadcast composer (direct table; select RLS already admin-aware) ── */

export interface ComposeBroadcastInput {
  title: string;
  content: string;
  tags: string[];
  is_pinned: boolean;
  /** 'now' and 'scheduled' both go through the publish-scheduled cron, which
   *  flips status to published AND sends the push — same path iOS scheduling
   *  uses. 'now' just sets published_at to the current time (≤1 min delay). */
  mode: 'draft' | 'now' | 'scheduled';
  publishAt?: string | null; // ISO, required for mode 'scheduled'
  video_url?: string | null;
  meeting_link?: string | null;
  author_id: string;
}

export async function createBroadcast(input: ComposeBroadcastInput): Promise<string> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = createClient();
  const publishAt = input.mode === 'now'
    ? new Date().toISOString()
    : input.mode === 'scheduled' ? input.publishAt ?? null : null;
  const { data, error } = await supabase
    .from('broadcasts')
    .insert({
      title: input.title.trim(),
      content: input.content,
      tags: input.tags,
      is_pinned: input.is_pinned,
      status: input.mode === 'draft' ? 'draft' : 'scheduled',
      video_url: input.video_url || null,
      meeting_link: input.meeting_link || null,
      // publish-scheduled cron publishes rows with status='scheduled' whose
      // published_at has passed, then sends the "New Insight" push.
      published_at: publishAt,
      scheduled_at: input.mode === 'scheduled' ? input.publishAt ?? null : null,
      author_id: input.author_id,
      target_audience: { type: 'all' },
    })
    .select('id')
    .single();
  if (error) throw error;
  return (data as { id: string }).id;
}

/** All broadcasts including drafts/scheduled — admin RLS grants full select. */
export async function fetchBroadcastsAdmin(): Promise<{ id: string; title: string; status: string; published_at: string | null; scheduled_at: string | null; view_count: number; created_at: string }[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  const { data, error } = await supabase
    .from('broadcasts')
    .select('id, title, status, published_at, scheduled_at, view_count, created_at')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []) as { id: string; title: string; status: string; published_at: string | null; scheduled_at: string | null; view_count: number; created_at: string }[];
}
