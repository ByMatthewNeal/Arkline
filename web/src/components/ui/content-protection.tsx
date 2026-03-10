'use client';

import { useEffect } from 'react';

export function ContentProtection() {
  useEffect(() => {
    function preventContextMenu(e: MouseEvent) {
      e.preventDefault();
    }

    function preventKeyShortcuts(e: KeyboardEvent) {
      // Block Ctrl/Cmd + S (save), Ctrl/Cmd + U (view source), Ctrl/Cmd + P (print)
      if ((e.ctrlKey || e.metaKey) && ['s', 'u', 'p'].includes(e.key.toLowerCase())) {
        e.preventDefault();
      }
      // Block Ctrl/Cmd + Shift + I (dev tools), Ctrl/Cmd + Shift + J (console)
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && ['i', 'j'].includes(e.key.toLowerCase())) {
        e.preventDefault();
      }
      // Block F12
      if (e.key === 'F12') {
        e.preventDefault();
      }
    }

    function preventDragStart(e: DragEvent) {
      const target = e.target as HTMLElement;
      if (target.tagName === 'IMG' || target.tagName === 'svg') {
        e.preventDefault();
      }
    }

    document.addEventListener('contextmenu', preventContextMenu);
    document.addEventListener('keydown', preventKeyShortcuts);
    document.addEventListener('dragstart', preventDragStart);

    return () => {
      document.removeEventListener('contextmenu', preventContextMenu);
      document.removeEventListener('keydown', preventKeyShortcuts);
      document.removeEventListener('dragstart', preventDragStart);
    };
  }, []);

  return null;
}
