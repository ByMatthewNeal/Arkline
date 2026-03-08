'use client';

import { type ReactNode } from 'react';
import {
  ResponsiveGridLayout,
  verticalCompactor,
  useContainerWidth,
  type ResponsiveLayouts,
  type Layout,
} from 'react-grid-layout';
import { RotateCcw } from 'lucide-react';
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
}

export type { ResponsiveLayouts };

export function DraggableGrid({ layoutKey, defaultLayouts, children }: DraggableGridProps) {
  const { layouts, onLayoutChange, resetLayout, isReady } = useWidgetLayout(layoutKey, defaultLayouts);
  const { containerRef: widthRef, width } = useContainerWidth({ measureBeforeMount: true });

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
      <button
        onClick={resetLayout}
        className="absolute -top-9 right-0 z-10 flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-[11px] font-medium text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text"
        title="Reset layout"
      >
        <RotateCcw className="h-3 w-3" />
        Reset
      </button>
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
    </div>
  );
}
