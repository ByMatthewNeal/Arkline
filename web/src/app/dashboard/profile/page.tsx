'use client';

import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  User,
  Mail,
  Calendar,
  Briefcase,
  BarChart3,
  Globe,
  Camera,
  Check,
  ExternalLink,
} from 'lucide-react';
import { GlassCard, Button, Input, Badge } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { createClient } from '@/lib/supabase/client';
import { formatDate } from '@/lib/utils/format';
import type { ExperienceLevel, CareerIndustry } from '@/types';

const experienceLevels: { value: ExperienceLevel; label: string }[] = [
  { value: 'beginner', label: 'Beginner' },
  { value: 'intermediate', label: 'Intermediate' },
  { value: 'advanced', label: 'Advanced' },
  { value: 'expert', label: 'Expert' },
];

const industries: { value: CareerIndustry; label: string }[] = [
  { value: 'technology', label: 'Technology' },
  { value: 'finance', label: 'Finance' },
  { value: 'healthcare', label: 'Healthcare' },
  { value: 'education', label: 'Education' },
  { value: 'retail', label: 'Retail' },
  { value: 'manufacturing', label: 'Manufacturing' },
  { value: 'marketing', label: 'Marketing' },
  { value: 'legal', label: 'Legal' },
  { value: 'real_estate', label: 'Real Estate' },
  { value: 'other', label: 'Other' },
];

const schema = z.object({
  username: z.string().min(2, 'Username must be at least 2 characters'),
  full_name: z.string().optional(),
  date_of_birth: z.string().optional(),
  career_industry: z.string().optional(),
  experience_level: z.string().optional(),
  twitter: z.string().optional(),
  linkedin: z.string().optional(),
  telegram: z.string().optional(),
  website: z.string().url('Invalid URL').optional().or(z.literal('')),
});

type FormValues = z.infer<typeof schema>;

export default function ProfilePage() {
  const { profile, authUser } = useAuth();
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [avatarUploading, setAvatarUploading] = useState(false);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
  });

  useEffect(() => {
    if (profile) {
      reset({
        username: profile.username,
        full_name: profile.full_name ?? '',
        date_of_birth: profile.date_of_birth ?? '',
        career_industry: profile.career_industry ?? '',
        experience_level: profile.experience_level ?? '',
        twitter: profile.social_links?.twitter ?? '',
        linkedin: profile.social_links?.linkedin ?? '',
        telegram: profile.social_links?.telegram ?? '',
        website: profile.social_links?.website ?? '',
      });
    }
  }, [profile, reset]);

  const onSubmit = async (data: FormValues) => {
    if (!profile) return;
    setSaving(true);
    try {
      const supabase = createClient();
      await supabase
        .from('profiles')
        .update({
          username: data.username,
          full_name: data.full_name || null,
          date_of_birth: data.date_of_birth || null,
          career_industry: data.career_industry || null,
          experience_level: data.experience_level || null,
          social_links: {
            twitter: data.twitter || undefined,
            linkedin: data.linkedin || undefined,
            telegram: data.telegram || undefined,
            website: data.website || undefined,
          },
        })
        .eq('id', profile.id);
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } finally {
      setSaving(false);
    }
  };

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !profile) return;

    setAvatarUploading(true);
    try {
      const supabase = createClient();
      const ext = file.name.split('.').pop();
      const path = `${profile.id}/avatar.${ext}`;

      await supabase.storage.from('avatars').upload(path, file, { upsert: true });
      const { data: urlData } = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase
        .from('profiles')
        .update({ avatar_url: urlData.publicUrl, use_photo_avatar: true })
        .eq('id', profile.id);

      window.location.reload();
    } finally {
      setAvatarUploading(false);
    }
  };

  const initial = profile?.full_name?.[0] ?? profile?.username?.[0] ?? '?';

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text">
        Profile
      </h1>

      {/* Avatar + Account Overview */}
      <GlassCard>
        <div className="flex items-start gap-5">
          {/* Avatar */}
          <div className="relative shrink-0">
            {profile?.avatar_url && profile.use_photo_avatar ? (
              <img
                src={profile.avatar_url}
                alt="Avatar"
                className="h-20 w-20 rounded-2xl object-cover"
              />
            ) : (
              <div className="flex h-20 w-20 items-center justify-center rounded-2xl bg-ark-primary/15">
                <span className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-primary">
                  {initial.toUpperCase()}
                </span>
              </div>
            )}
            <label className="absolute -bottom-1 -right-1 flex h-7 w-7 cursor-pointer items-center justify-center rounded-full bg-ark-primary text-white shadow-lg transition-transform hover:scale-110">
              <Camera className="h-3.5 w-3.5" />
              <input
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handleAvatarUpload}
                disabled={avatarUploading}
              />
            </label>
          </div>

          {/* Info */}
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-semibold text-ark-text truncate">
              {profile?.full_name ?? profile?.username ?? 'User'}
            </h2>
            <p className="text-sm text-ark-text-tertiary truncate">{profile?.email}</p>
            <div className="mt-2 flex flex-wrap items-center gap-2">
              <Badge
                variant={
                  profile?.role === 'premium' || profile?.role === 'admin' ? 'info' : 'default'
                }
              >
                {profile?.role ?? 'user'}
              </Badge>
              {profile?.experience_level && (
                <Badge variant="default">{profile.experience_level}</Badge>
              )}
            </div>
            <p className="mt-2 text-[10px] text-ark-text-tertiary">
              Member since {profile?.created_at ? formatDate(profile.created_at) : '—'}
            </p>
          </div>
        </div>
      </GlassCard>

      {/* Edit Form */}
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {/* Personal Info */}
        <GlassCard>
          <div className="mb-4 flex items-center gap-2">
            <User className="h-4 w-4 text-ark-text-tertiary" />
            <h2 className="text-sm font-semibold text-ark-text">Personal Information</h2>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Input
              id="username"
              label="Username"
              placeholder="your_username"
              error={errors.username?.message}
              {...register('username')}
            />
            <Input
              id="full_name"
              label="Full Name"
              placeholder="John Doe"
              error={errors.full_name?.message}
              {...register('full_name')}
            />
            <div className="flex flex-col gap-1.5">
              <label htmlFor="email" className="text-sm font-medium text-ark-text">
                Email
              </label>
              <div className="flex h-11 items-center gap-2 rounded-lg border border-ark-divider bg-ark-fill-secondary px-3 text-sm text-ark-text-tertiary">
                <Mail className="h-4 w-4 shrink-0" />
                <span className="truncate">{authUser?.email ?? '—'}</span>
              </div>
            </div>
            <Input
              id="date_of_birth"
              type="date"
              label="Date of Birth"
              {...register('date_of_birth')}
            />
          </div>
        </GlassCard>

        {/* Professional Info */}
        <GlassCard>
          <div className="mb-4 flex items-center gap-2">
            <Briefcase className="h-4 w-4 text-ark-text-tertiary" />
            <h2 className="text-sm font-semibold text-ark-text">Professional</h2>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="career_industry" className="text-sm font-medium text-ark-text">
                Industry
              </label>
              <select
                id="career_industry"
                {...register('career_industry')}
                className="h-11 w-full rounded-lg border border-ark-divider bg-ark-fill-secondary px-3 text-sm text-ark-text outline-none focus:border-ark-primary focus:ring-2 focus:ring-ark-primary/20 cursor-pointer"
              >
                <option value="">Select industry</option>
                {industries.map((ind) => (
                  <option key={ind.value} value={ind.value}>
                    {ind.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex flex-col gap-1.5">
              <label htmlFor="experience_level" className="text-sm font-medium text-ark-text">
                Experience Level
              </label>
              <div className="flex gap-2">
                {experienceLevels.map((lvl) => (
                  <label
                    key={lvl.value}
                    className={`
                      flex-1 cursor-pointer rounded-lg px-2 py-2 text-center text-xs font-medium
                      transition-colors
                    `}
                  >
                    <input
                      type="radio"
                      value={lvl.value}
                      {...register('experience_level')}
                      className="peer sr-only"
                    />
                    <span className="block rounded-lg px-1 py-1.5 peer-checked:bg-ark-primary/10 peer-checked:text-ark-primary bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-divider transition-colors">
                      {lvl.label}
                    </span>
                  </label>
                ))}
              </div>
            </div>
          </div>
        </GlassCard>

        {/* Social Links */}
        <GlassCard>
          <div className="mb-4 flex items-center gap-2">
            <Globe className="h-4 w-4 text-ark-text-tertiary" />
            <h2 className="text-sm font-semibold text-ark-text">Social Links</h2>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Input
              id="twitter"
              label="Twitter / X"
              placeholder="@username"
              {...register('twitter')}
            />
            <Input
              id="linkedin"
              label="LinkedIn"
              placeholder="linkedin.com/in/username"
              {...register('linkedin')}
            />
            <Input
              id="telegram"
              label="Telegram"
              placeholder="@username"
              {...register('telegram')}
            />
            <Input
              id="website"
              label="Website"
              placeholder="https://example.com"
              error={errors.website?.message}
              {...register('website')}
            />
          </div>
        </GlassCard>

        {/* Account Info (read-only) */}
        <GlassCard>
          <div className="mb-4 flex items-center gap-2">
            <BarChart3 className="h-4 w-4 text-ark-text-tertiary" />
            <h2 className="text-sm font-semibold text-ark-text">Account</h2>
          </div>
          <div className="grid gap-3 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-ark-text-tertiary">User ID</span>
              <span className="font-mono text-xs text-ark-text-secondary truncate max-w-[200px]">
                {profile?.id}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-ark-text-tertiary">Joined</span>
              <span className="text-ark-text-secondary">
                {profile?.created_at ? formatDate(profile.created_at) : '—'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-ark-text-tertiary">Last Updated</span>
              <span className="text-ark-text-secondary">
                {profile?.updated_at ? formatDate(profile.updated_at) : '—'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-ark-text-tertiary">Watchlist</span>
              <span className="text-ark-text-secondary">
                {(profile?.risk_coins ?? []).length} coins
              </span>
            </div>
          </div>
        </GlassCard>

        {/* Save */}
        <div className="sticky bottom-20 md:bottom-4">
          <Button type="submit" loading={saving} className="w-full">
            {saved ? (
              <>
                <Check className="h-4 w-4" />
                Saved
              </>
            ) : (
              'Save Profile'
            )}
          </Button>
        </div>
      </form>
    </div>
  );
}
