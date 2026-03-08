import { createBrowserClient } from '@supabase/ssr';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '';

const isConfigured =
  supabaseUrl.startsWith('http') && supabaseKey.length > 0;

export function createClient() {
  if (!isConfigured) return null as any;
  return createBrowserClient(supabaseUrl, supabaseKey);
}

export function isSupabaseConfigured() {
  return isConfigured;
}
