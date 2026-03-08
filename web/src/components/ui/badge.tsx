interface BadgeProps {
  variant?: 'default' | 'success' | 'warning' | 'error' | 'info';
  children: React.ReactNode;
  className?: string;
}

const variants = {
  default: 'bg-ark-fill-secondary text-ark-text-secondary',
  success: 'bg-ark-success/15 text-ark-success',
  warning: 'bg-ark-warning/15 text-ark-warning',
  error: 'bg-ark-error/15 text-ark-error',
  info: 'bg-ark-info/15 text-ark-info',
};

export function Badge({ variant = 'default', children, className = '' }: BadgeProps) {
  return (
    <span
      className={`
        inline-flex items-center rounded-full px-2.5 py-0.5
        text-xs font-medium
        ${variants[variant]}
        ${className}
      `}
    >
      {children}
    </span>
  );
}
