import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Web Push subscription management — the desktop counterpart of the iOS
 * APNs registration (`BroadcastNotificationService`). Subscriptions are
 * stored in the same `user_devices` table with platform = 'web'; the
 * `device_token` column holds the serialized PushSubscription.
 *
 * Requires `NEXT_PUBLIC_VAPID_PUBLIC_KEY` at build time. Server-side
 * sending (edge function) uses the matching private key.
 */

const VAPID_PUBLIC_KEY = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY ?? '';

export function isPushSupported(): boolean {
  return (
    typeof window !== 'undefined' &&
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    'Notification' in window
  );
}

export function isPushConfigured(): boolean {
  return VAPID_PUBLIC_KEY.length > 0;
}

function urlBase64ToUint8Array(base64: string): Uint8Array {
  const padding = '='.repeat((4 - (base64.length % 4)) % 4);
  const raw = atob((base64 + padding).replace(/-/g, '+').replace(/_/g, '/'));
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

async function getRegistration(): Promise<ServiceWorkerRegistration> {
  const existing = await navigator.serviceWorker.getRegistration('/sw.js');
  if (existing) return existing;
  return navigator.serviceWorker.register('/sw.js');
}

/**
 * Ask permission, subscribe, and store the subscription. Returns 'subscribed',
 * 'denied' (user refused the browser prompt), or 'unsupported'.
 */
export async function subscribeToPush(userId: string): Promise<'subscribed' | 'denied' | 'unsupported'> {
  if (!isPushSupported() || !isPushConfigured() || !isSupabaseConfigured()) return 'unsupported';

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return 'denied';

  const registration = await getRegistration();
  const subscription =
    (await registration.pushManager.getSubscription()) ??
    (await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY) as BufferSource,
    }));

  const supabase = createClient();
  const { error } = await supabase.from('user_devices').upsert(
    {
      user_id: userId,
      device_token: JSON.stringify(subscription.toJSON()),
      platform: 'web',
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,device_token' },
  );
  if (error) throw error;
  return 'subscribed';
}

/** Unsubscribe this browser and remove its stored subscription row. */
export async function unsubscribeFromPush(userId: string): Promise<void> {
  if (!isPushSupported()) return;
  const registration = await navigator.serviceWorker.getRegistration('/sw.js');
  const subscription = await registration?.pushManager.getSubscription();
  if (!subscription) return;

  const token = JSON.stringify(subscription.toJSON());
  await subscription.unsubscribe();

  if (isSupabaseConfigured()) {
    const supabase = createClient();
    await supabase.from('user_devices').delete().eq('user_id', userId).eq('device_token', token);
  }
}

/** Whether this browser currently holds an active push subscription. */
export async function hasPushSubscription(): Promise<boolean> {
  if (!isPushSupported()) return false;
  const registration = await navigator.serviceWorker.getRegistration('/sw.js');
  const sub = await registration?.pushManager.getSubscription();
  return !!sub;
}
