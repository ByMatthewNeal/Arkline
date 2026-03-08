'use client';

import { useState } from 'react';
import {
  Users,
  MessageCircle,
  MessagesSquare,
  TrendingUp,
  BarChart3,
  Shield,
  Lightbulb,
  DollarSign,
  Lock,
} from 'lucide-react';
import { GlassCard } from '@/components/ui';
import { cn } from '@/lib/utils/format';

const tabs = [
  { id: 'feed', label: 'Feed', icon: Users },
  { id: 'messages', label: 'Messages', icon: MessageCircle },
  { id: 'rooms', label: 'Chat Rooms', icon: MessagesSquare },
] as const;

type TabId = (typeof tabs)[number]['id'];

const chatRooms = [
  { name: 'BTC & Altcoins', icon: TrendingUp, members: 1243, color: '#F59E0B', description: 'Bitcoin and altcoin discussion' },
  { name: 'Macro Economics', icon: BarChart3, members: 856, color: '#3B82F6', description: 'Global macro and monetary policy' },
  { name: 'Technical Analysis', icon: TrendingUp, members: 672, color: '#8B5CF6', description: 'Charts, patterns, and TA strategies' },
  { name: 'Risk Management', icon: Shield, members: 534, color: '#DC2626', description: 'Position sizing and risk frameworks' },
  { name: 'DCA Strategies', icon: DollarSign, members: 421, color: '#22C55E', description: 'Dollar-cost averaging tips and plans' },
  { name: 'Trading Ideas', icon: Lightbulb, members: 389, color: '#F97316', description: 'Share and discuss trade setups' },
];

const categories = ['Analysis', 'News', 'Discussion', 'Trading Ideas', 'Market Updates'];

export default function CommunityPage() {
  const [activeTab, setActiveTab] = useState<TabId>('feed');

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">
          Community
        </h1>
        <p className="mt-1 text-sm text-ark-text-tertiary">
          Connect with other investors and share insights
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 rounded-xl bg-ark-fill-secondary p-1">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={cn(
              'flex flex-1 items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition-all cursor-pointer',
              activeTab === tab.id
                ? 'bg-ark-surface text-ark-text shadow-sm'
                : 'text-ark-text-tertiary hover:text-ark-text',
            )}
          >
            <tab.icon className="h-4 w-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {activeTab === 'feed' && (
        <div className="space-y-4">
          {/* Category filters */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            <button className="shrink-0 rounded-full bg-ark-primary px-3 py-1 text-xs font-medium text-white cursor-pointer">
              All
            </button>
            {categories.map((cat) => (
              <button
                key={cat}
                className="shrink-0 rounded-full bg-ark-fill-secondary px-3 py-1 text-xs font-medium text-ark-text-secondary hover:bg-ark-fill-tertiary transition-colors cursor-pointer"
              >
                {cat}
              </button>
            ))}
          </div>

          {/* Coming soon state */}
          <GlassCard className="relative overflow-hidden">
            <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/30 to-transparent" />
            <div className="flex flex-col items-center py-12 text-center">
              <div className="relative">
                <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-ark-primary/20 to-violet-500/20">
                  <Users className="h-8 w-8 text-ark-primary" />
                </div>
                <div className="absolute -right-1 -top-1 flex h-6 w-6 items-center justify-center rounded-full bg-ark-warning shadow-md">
                  <Lock className="h-3 w-3 text-white" />
                </div>
              </div>
              <h3 className="mt-4 text-lg font-semibold text-ark-text">Community Feed Coming Soon</h3>
              <p className="mt-2 max-w-sm text-sm text-ark-text-tertiary">
                Share analysis, trading ideas, and market insights with the Arkline community. Post and discuss with fellow investors.
              </p>
              <div className="mt-4 flex gap-2">
                {['Analysis', 'Discussion', 'Trading Ideas'].map((tag) => (
                  <span
                    key={tag}
                    className="rounded-full bg-ark-fill-secondary px-3 py-1 text-xs text-ark-text-tertiary"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </div>
          </GlassCard>
        </div>
      )}

      {activeTab === 'messages' && (
        <GlassCard className="relative overflow-hidden">
          <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-violet-500/30 to-transparent" />
          <div className="flex flex-col items-center py-12 text-center">
            <div className="relative">
              <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500/20 to-ark-primary/20">
                <MessageCircle className="h-8 w-8 text-violet-500" />
              </div>
              <div className="absolute -right-1 -top-1 flex h-6 w-6 items-center justify-center rounded-full bg-ark-warning shadow-md">
                <Lock className="h-3 w-3 text-white" />
              </div>
            </div>
            <h3 className="mt-4 text-lg font-semibold text-ark-text">Direct Messages Coming Soon</h3>
            <p className="mt-2 max-w-sm text-sm text-ark-text-tertiary">
              Send private messages to other Arkline members. Discuss trades, share insights, and connect one-on-one.
            </p>
          </div>
        </GlassCard>
      )}

      {activeTab === 'rooms' && (
        <div className="grid gap-3 sm:grid-cols-2">
          {chatRooms.map((room) => (
            <GlassCard
              key={room.name}
              className="group relative cursor-pointer overflow-hidden transition-all hover:shadow-md"
            >
              <div className="pointer-events-none absolute inset-y-0 left-0 w-1 rounded-l-xl" style={{ backgroundColor: room.color }} />
              <div className="flex items-start gap-3">
                <div
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl"
                  style={{ backgroundColor: `${room.color}20` }}
                >
                  <room.icon className="h-5 w-5" style={{ color: room.color }} />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold text-ark-text group-hover:text-ark-primary transition-colors">
                    {room.name}
                  </p>
                  <p className="mt-0.5 text-xs text-ark-text-tertiary line-clamp-1">
                    {room.description}
                  </p>
                  <div className="mt-2 flex items-center gap-1 text-[10px] text-ark-text-tertiary">
                    <Users className="h-3 w-3" />
                    {room.members.toLocaleString()} members
                  </div>
                </div>
              </div>
            </GlassCard>
          ))}
        </div>
      )}
    </div>
  );
}
