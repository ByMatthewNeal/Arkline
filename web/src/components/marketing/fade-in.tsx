'use client';

import React, { useRef, type ReactNode, type CSSProperties } from 'react';
import { useInView } from '@/lib/hooks/use-in-view';

interface FadeInProps {
  children: ReactNode;
  className?: string;
  delay?: number;
  /** 'up' (default), 'none', or 'scale' */
  variant?: 'up' | 'none' | 'scale';
  as?: React.ElementType;
  style?: CSSProperties;
  /** If true, animate on mount instead of on scroll */
  onMount?: boolean;
}

export function FadeIn({
  children,
  className = '',
  delay = 0,
  variant = 'up',
  as: Tag = 'div',
  style,
  onMount = false,
}: FadeInProps) {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true, margin: '-40px' });
  const visible = onMount || isInView;

  const baseStyle: CSSProperties = {
    ...style,
    transitionProperty: 'opacity, transform',
    transitionDuration: '0.5s',
    transitionTimingFunction: 'cubic-bezier(0.16, 1, 0.3, 1)',
    transitionDelay: `${delay}s`,
  };

  if (!visible) {
    baseStyle.opacity = 0;
    if (variant === 'up') baseStyle.transform = 'translateY(16px)';
    if (variant === 'scale') {
      baseStyle.transform = 'scale(0.95)';
    }
  } else {
    baseStyle.opacity = 1;
    baseStyle.transform = 'none';
  }

  return (
    <Tag ref={ref} className={className} style={baseStyle}>
      {children}
    </Tag>
  );
}
