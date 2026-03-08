'use client';

import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { Loader2 } from 'lucide-react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
}

const variants = {
  primary:
    'bg-ark-primary text-white hover:bg-ark-accent-dark active:bg-ark-accent-dark/90 shadow-md',
  secondary:
    'bg-ark-fill-secondary text-ark-text hover:bg-ark-divider',
  ghost:
    'bg-transparent text-ark-text hover:bg-ark-fill-secondary',
  danger:
    'bg-ark-error text-white hover:bg-ark-error/90',
};

const sizes = {
  sm: 'h-8 px-3 text-sm rounded-lg',
  md: 'h-11 px-4 text-sm rounded-lg',
  lg: 'h-[52px] px-6 text-base rounded-lg',
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className = '', variant = 'primary', size = 'md', loading, disabled, children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={`
          inline-flex items-center justify-center gap-2 font-medium
          transition-colors duration-150 cursor-pointer
          disabled:opacity-50 disabled:cursor-not-allowed
          ${variants[variant]}
          ${sizes[size]}
          ${className}
        `}
        disabled={disabled || loading}
        {...props}
      >
        {loading && <Loader2 className="h-4 w-4 animate-spin" />}
        {children}
      </button>
    );
  },
);

Button.displayName = 'Button';
