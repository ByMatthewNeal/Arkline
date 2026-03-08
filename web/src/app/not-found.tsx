'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';
import { ArrowLeft } from 'lucide-react';
import { ArklineLogo, Button } from '@/components/ui';
import { AnimatedBackground } from '@/components/marketing/animated-bg';

export default function NotFound() {
  return (
    <div className="relative flex min-h-screen items-center justify-center px-4">
      <AnimatedBackground />
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="relative text-center"
      >
        <div className="font-[family-name:var(--font-inter)] text-[120px] font-bold leading-none tracking-tighter sm:text-[160px]">
          <span className="bg-gradient-to-r from-ark-primary via-ark-purple to-ark-cyan bg-clip-text text-transparent">
            404
          </span>
        </div>
        <ArklineLogo size="lg" showText={false} className="mx-auto mt-4 justify-center" />
        <h1 className="mt-4 font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text sm:text-3xl">
          Page not found
        </h1>
        <p className="mt-3 text-ark-text-secondary">
          This page doesn&apos;t exist. Head back to Arkline to continue.
        </p>
        <Link href="/" className="mt-8 inline-block">
          <Button size="lg" variant="secondary">
            <ArrowLeft className="h-4 w-4" />
            Back to Home
          </Button>
        </Link>
      </motion.div>
    </div>
  );
}
