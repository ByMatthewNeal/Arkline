export type UserRole = 'user' | 'premium' | 'admin';
export type SubscriptionStatus = 'active' | 'past_due' | 'canceled' | 'trialing' | 'none';
export type ExperienceLevel = 'beginner' | 'intermediate' | 'advanced' | 'expert';

export type CareerIndustry =
  | 'technology'
  | 'finance'
  | 'healthcare'
  | 'education'
  | 'retail'
  | 'manufacturing'
  | 'marketing'
  | 'legal'
  | 'real_estate'
  | 'other';

export interface SocialLinks {
  twitter?: string;
  linkedin?: string;
  telegram?: string;
  website?: string;
}

export interface NotificationSettings {
  push_enabled: boolean;
  email_enabled: boolean;
  dca_reminders: boolean;
  extreme_moves: boolean;
  sentiment_shifts: boolean;
  insights: boolean;
}

export interface DashboardLayouts {
  home?: import('react-grid-layout').ResponsiveLayouts;
  market?: import('react-grid-layout').ResponsiveLayouts;
}

export interface User {
  id: string;
  username: string;
  email: string;
  full_name?: string;
  avatar_url?: string;
  use_photo_avatar: boolean;
  date_of_birth?: string;
  career_industry?: CareerIndustry;
  experience_level?: ExperienceLevel;
  social_links?: SocialLinks;
  preferred_currency: string;
  risk_coins: string[];
  dark_mode: string;
  notifications?: NotificationSettings;
  dashboard_layouts?: DashboardLayouts;
  passcode_hash?: string;
  face_id_enabled: boolean;
  role: UserRole;
  subscription_status: SubscriptionStatus;
  trial_end?: string;
  created_at: string;
  updated_at: string;
}
