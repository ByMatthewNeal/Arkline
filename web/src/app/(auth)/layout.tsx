'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { ArklineLogo } from '@/components/ui';

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="relative flex min-h-screen items-center justify-center px-4">
      <AnimatedBackground />

      {/* Logo */}
      <div className="absolute top-6 left-6 z-10">
        <Link href="/">
          <ArklineLogo size="sm" />
        </Link>
      </div>

      {/* Form */}
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="relative w-full max-w-sm"
      >
        {children}
      </motion.div>
    </div>
  );
}
