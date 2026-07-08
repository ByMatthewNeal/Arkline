'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/lib/hooks/use-theme';
import { ToastProvider } from '@/components/ui/toast';
import { useState } from 'react';

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,
            // Mirror the iOS refresh model: HomeViewModel runs a 5-minute
            // auto-refresh timer and refreshes on foreground. Per-hook
            // refetchInterval (e.g. 60 s live prices) overrides this default.
            refetchInterval: 5 * 60 * 1000,
            refetchOnWindowFocus: true,
            retry: 2,
          },
        },
      }),
  );

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <ToastProvider>{children}</ToastProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
}
