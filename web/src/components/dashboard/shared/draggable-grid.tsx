'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';
import {
  ResponsiveGridLayout,
  verticalCompactor,
  type ResponsiveLayouts,
} from 'react-grid-layout';
import { useWidgetLayout } from '@/lib/hooks/use-widget-layout';
import { Skeleton } from '@/components/ui';

import 'react-grid-layout/css/styles.css';
import 'react-resizable/css/styles.css';

const BREAKPOINTS = { lg: 1200, md: 768, sm: 0 } as const;
const COLS = { lg: 4, md: 3, sm: 2 } as const;
const MARGIN: readonly [number, number] = [8, 8];
const ROW_HEIGHT = 80;

interface DraggableGridProps {
  layoutKey: string;
  defaultLayouts: ResponsiveLayouts;
  children: ReactNode;
  /** Optional: receives the reset function so a parent can render its own Reset control. */
  resetRef?: { current: (() => void) | null };
}

export type { ResponsiveLayouts };

export function DraggableGrid({ layoutKey, defaultLayouts, children, resetRef }: DraggableGridProps) {
  const { layouts, onLayoutChange, resetLayout, isReady } = useWidgetLayout(layoutKey, defaultLayouts);

  useEffect(() => {
    if (resetRef) resetRef.current = resetLayout;
  }, [resetRef, resetLayout]);

  // Measure the actual container width ourselves so the grid always fills the
  // available space (react-grid-layout's useContainerWidth can get stuck at its
  // 1280px default on wide screens).
  const widthRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);

  useEffect(() => {
    const node = widthRef.current;
    if (!node) return;
    const measure = () => setWidth(node.offsetWidth);
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(node);
    window.addEventListener('resize', measure);
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', measure);
    };
  }, [isReady]);

  if (!isReady) {
    return (
      <div className="grid gap-2 lg:grid-cols-4 md:max-lg:grid-cols-3 max-md:grid-cols-2">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-44 rounded-2xl" />
        ))}
      </div>
    );
  }

  return (
    <div ref={widthRef} className="relative">
      {width > 0 && (
        <ResponsiveGridLayout
          className="arkline-grid"
          width={width}
          layouts={layouts}
          breakpoints={BREAKPOINTS}
          cols={COLS}
          rowHeight={ROW_HEIGHT}
          margin={MARGIN}
          containerPadding={[0, 0]}
          dragConfig={{ handle: '.drag-handle' }}
          compactor={verticalCompactor}
          onLayoutChange={onLayoutChange}
        >
          {children}
        </ResponsiveGridLayout>
      )}
    </div>
  );
}
