'use client';

import { motion } from 'framer-motion';
import { ArklineLogo } from '@/components/ui';
import { EmailCapture } from '@/components/marketing/email-capture';

const ease = [0.25, 0.1, 0.25, 1] as const; // Apple-style cubic-bezier

export default function LoginPage() {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.96 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.5, ease }}
      className="overflow-hidden rounded-2xl border border-white/[0.08] bg-ark-bg/80 shadow-2xl backdrop-blur-xl"
    >
      {/* Top accent */}
      <motion.div
        initial={{ scaleX: 0 }}
        animate={{ scaleX: 1 }}
        transition={{ delay: 0.3, duration: 0.8, ease }}
        className="h-px origin-center bg-gradient-to-r from-transparent via-ark-primary/50 to-transparent"
      />

      <div className="flex flex-col items-center p-8 sm:p-10 text-center">
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2, duration: 0.6, ease }}
        >
          <ArklineLogo size="lg" showText={false} className="mb-6 justify-center" />
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.35, duration: 0.5, ease }}
          className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text"
        >
          Arkline is Coming Soon
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.45, duration: 0.5, ease }}
          className="mt-3 max-w-sm text-sm leading-relaxed text-ark-text-secondary"
        >
          The full dashboard experience — portfolio, risk scoring, AI briefings — coming to your browser soon.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.55, duration: 0.5, ease }}
          className="mt-8 w-full"
        >
          <EmailCapture />
        </motion.div>
      </div>
    </motion.div>
  );
}
