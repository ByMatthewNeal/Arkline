'use client';

import { forwardRef, type InputHTMLAttributes } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className = '', label, error, id, ...props }, ref) => {
    return (
      <div className="flex flex-col gap-1.5">
        {label && (
          <label htmlFor={id} className="text-sm font-medium text-ark-text">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={id}
          className={`
            h-11 w-full rounded-lg border bg-ark-fill-secondary px-3
            text-sm text-ark-text placeholder:text-ark-text-tertiary
            outline-none transition-colors duration-150
            border-ark-divider
            focus:border-ark-primary focus:ring-2 focus:ring-ark-primary/20
            disabled:opacity-50 disabled:cursor-not-allowed
            ${error ? 'border-ark-error focus:border-ark-error focus:ring-ark-error/20' : ''}
            ${className}
          `}
          {...props}
        />
        {error && <p className="text-xs text-ark-error">{error}</p>}
      </div>
    );
  },
);

Input.displayName = 'Input';
