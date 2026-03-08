// Design tokens matching iOS AppColors, AppFonts, ArkSpacing
// Source of truth: ArkLine/Core/Theme/Colors.swift

export const colors = {
  // Brand
  primary: '#3B82F6',
  accent: '#3B82F6',
  accentDark: '#2563EB',
  accentLight: '#60A5FA',

  // Secondary accents
  purple: '#8B5CF6',
  violet: '#7C3AED',
  cyan: '#06B6D4',

  // Semantic
  success: '#22C55E',
  successMuted: '#16A34A',
  warning: '#F59E0B',
  error: '#DC2626',
  info: '#3B82F6',
  focusRing: '#0EA5E9',

  // Backgrounds (dark / light)
  background: { dark: '#0F0F0F', light: '#F8F8F8' },
  surface: { dark: '#0A0A0B', light: '#FFFFFF' },
  card: { dark: '#1F1F1F', light: '#FFFFFF' },
  divider: { dark: '#2A2A2A', light: '#E2E8F0' },
  cardBorder: { dark: 'transparent', light: '#E2E8F0' },
  fillSecondary: { dark: '#2A2A2E', light: '#F5F5F5' },
  fillTertiary: { dark: '#303038', light: '#E2E8F0' },

  // Text
  textPrimary: { dark: '#FFFFFF', light: '#1E293B' },
  textSecondary: '#475569',
  textTertiary: { dark: '#71717A', light: '#64748B' },
  textDisabled: { dark: '#4A4A5A', light: '#CCCCCC' },

  // Glass
  glass: {
    bg: { dark: 'rgba(20,20,25,0.85)', light: 'rgba(255,255,255,0.72)' },
    border: { dark: 'rgba(255,255,255,0.15)', light: 'rgba(226,232,240,0.6)' },
  },

  // Mesh gradient
  meshPurple: '#2F2858',
  meshBlue: '#3B82F6',
  meshPink: '#6366F1',
  meshIndigo: '#1E3A8A',

  // Glow
  glowPrimary: '#3B82F6',
  glowSuccess: '#22C55E',
  glowWarning: '#F59E0B',
  glowError: '#DC2626',
} as const;

export const spacing = {
  xxxs: '0.125rem', // 2px
  xxs: '0.25rem',   // 4px
  xs: '0.5rem',     // 8px
  sm: '0.75rem',    // 12px
  md: '1rem',       // 16px
  lg: '1.25rem',    // 20px
  xl: '1.5rem',     // 24px
  xxl: '2rem',      // 32px
  xxxl: '2.5rem',   // 40px
  xxxxl: '3rem',    // 48px
} as const;

export const radius = {
  xs: '0.25rem',    // 4px
  sm: '0.5rem',     // 8px
  md: '0.75rem',    // 12px
  lg: '1rem',       // 16px
  xl: '1.25rem',    // 20px
  xxl: '1.5rem',    // 24px
  full: '9999px',
  card: '1rem',     // 16px
  button: '0.5rem', // 8px
  input: '0.5rem',  // 8px
} as const;

export const shadows = {
  card: '0 2px 8px rgba(0,0,0,0.06)',
  sm: '0 2px 4px rgba(0,0,0,0.1)',
  md: '0 4px 8px rgba(0,0,0,0.15)',
  lg: '0 8px 16px rgba(0,0,0,0.2)',
} as const;
