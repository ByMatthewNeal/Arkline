'use client';

import { motion, type HTMLMotionProps } from 'framer-motion';
import { forwardRef } from 'react';

interface GlassCardProps extends HTMLMotionProps<'div'> {
  hover?: boolean;
  glow?: 'primary' | 'success' | 'warning' | 'error';
}

const glowColors = {
  primary: 'hover:shadow-[0_0_20px_rgba(59,130,246,0.15)]',
  success: 'hover:shadow-[0_0_20px_rgba(34,197,94,0.15)]',
  warning: 'hover:shadow-[0_0_20px_rgba(245,158,11,0.15)]',
  error: 'hover:shadow-[0_0_20px_rgba(220,38,38,0.15)]',
};

export const GlassCard = forwardRef<HTMLDivElement, GlassCardProps>(
  ({ className = '', hover = false, glow, children, ...props }, ref) => {
    return (
      <motion.div
        ref={ref}
        inherit={false}
        className={`
          glass rounded-[16px] p-5
          ${hover ? 'group transition-shadow duration-200' : ''}
          ${glow ? glowColors[glow] : ''}
          ${className}
        `}
        {...props}
      >
        {children}
      </motion.div>
    );
  },
);

GlassCard.displayName = 'GlassCard';
