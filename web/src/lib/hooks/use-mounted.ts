'use client';

import { useSyncExternalStore } from 'react';

const emptySubscribe = () => () => {};

/**
 * True after hydration, false during SSR/first client render.
 * Use to gate client-only output (portals) so server and client
 * hydrate identically. Lint-clean alternative to the
 * setState-in-useEffect "mounted" flag.
 */
export function useMounted(): boolean {
  return useSyncExternalStore(
    emptySubscribe,
    () => true, // client snapshot
    () => false, // server snapshot
  );
}
