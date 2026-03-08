'use client';

import { Sun, Moon, Monitor } from 'lucide-react';
import { useTheme } from '@/lib/hooks/use-theme';

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  const cycle = () => {
    const next = theme === 'dark' ? 'light' : theme === 'light' ? 'system' : 'dark';
    setTheme(next);
  };

  return (
    <button
      onClick={cycle}
      className="flex h-9 w-9 items-center justify-center rounded-xl
        text-ark-text-tertiary hover:bg-ark-fill-secondary hover:text-ark-text
        transition-colors cursor-pointer"
      title={`Theme: ${theme}`}
    >
      {theme === 'dark' && <Moon className="h-4 w-4" />}
      {theme === 'light' && <Sun className="h-4 w-4" />}
      {theme === 'system' && <Monitor className="h-4 w-4" />}
    </button>
  );
}
