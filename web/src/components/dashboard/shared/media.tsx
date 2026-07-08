'use client';

/**
 * Broadcast media components: image grid + fullscreen lightbox, and a
 * styled audio player for voice notes. Mirrors the iOS broadcast content
 * experience (FullscreenImageViewer / AudioPlayerView).
 */

import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { X, ChevronLeft, ChevronRight, Play, Pause, Mic } from 'lucide-react';
import { cn } from '@/lib/utils/format';
import { useMounted } from '@/lib/hooks/use-mounted';

/* ── Image grid + lightbox ── */

export function ImageGallery({ images, title }: { images: string[]; title?: string }) {
  const [openIdx, setOpenIdx] = useState<number | null>(null);
  const mounted = useMounted();

  useEffect(() => {
    if (openIdx === null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpenIdx(null);
      if (e.key === 'ArrowRight') setOpenIdx((v) => (v === null ? v : Math.min(v + 1, images.length - 1)));
      if (e.key === 'ArrowLeft') setOpenIdx((v) => (v === null ? v : Math.max(v - 1, 0)));
    };
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [openIdx, images.length]);

  if (!images.length) return null;

  return (
    <>
      <div className={cn('mt-3 grid gap-2', images.length === 1 ? 'grid-cols-1' : 'grid-cols-2')}>
        {images.slice(0, 4).map((src, i) => (
          <button
            key={i}
            onClick={(e) => { e.stopPropagation(); setOpenIdx(i); }}
            className="group/img relative overflow-hidden rounded-xl border border-ark-divider"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={src}
              alt={title ? `${title} — image ${i + 1}` : `Image ${i + 1}`}
              loading="lazy"
              className="h-40 w-full object-cover transition-transform duration-300 group-hover/img:scale-[1.03]"
            />
            {i === 3 && images.length > 4 && (
              <span className="absolute inset-0 flex items-center justify-center bg-black/50 text-sm font-semibold text-white">
                +{images.length - 4} more
              </span>
            )}
          </button>
        ))}
      </div>

      {mounted &&
        createPortal(
          <AnimatePresence>
            {openIdx !== null && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="fixed inset-0 z-[160] flex items-center justify-center bg-black/90 p-4"
                onClick={() => setOpenIdx(null)}
              >
                <button
                  onClick={() => setOpenIdx(null)}
                  className="absolute right-4 top-4 flex h-9 w-9 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20"
                  aria-label="Close"
                >
                  <X className="h-4 w-4" />
                </button>
                {openIdx > 0 && (
                  <button
                    onClick={(e) => { e.stopPropagation(); setOpenIdx(openIdx - 1); }}
                    className="absolute left-4 flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20"
                    aria-label="Previous image"
                  >
                    <ChevronLeft className="h-5 w-5" />
                  </button>
                )}
                {openIdx < images.length - 1 && (
                  <button
                    onClick={(e) => { e.stopPropagation(); setOpenIdx(openIdx + 1); }}
                    className="absolute right-4 top-1/2 flex h-10 w-10 -translate-y-1/2 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20"
                    aria-label="Next image"
                  >
                    <ChevronRight className="h-5 w-5" />
                  </button>
                )}
                <motion.img
                  key={openIdx}
                  initial={{ opacity: 0, scale: 0.97 }}
                  animate={{ opacity: 1, scale: 1 }}
                  src={images[openIdx]}
                  alt={title ?? 'Image'}
                  className="max-h-[88vh] max-w-full rounded-xl object-contain"
                  onClick={(e) => e.stopPropagation()}
                />
                {images.length > 1 && (
                  <span className="fig absolute bottom-4 rounded-full bg-white/10 px-3 py-1 text-xs font-medium text-white">
                    {openIdx + 1} / {images.length}
                  </span>
                )}
              </motion.div>
            )}
          </AnimatePresence>,
          document.body,
        )}
    </>
  );
}

/* ── Voice-note audio player ── */

function fmtTime(s: number): string {
  if (!isFinite(s)) return '0:00';
  const m = Math.floor(s / 60);
  const sec = Math.floor(s % 60);
  return `${m}:${sec.toString().padStart(2, '0')}`;
}

export function AudioPlayer({ src }: { src: string }) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [duration, setDuration] = useState(0);
  const [current, setCurrent] = useState(0);

  const toggle = (e: React.MouseEvent) => {
    e.stopPropagation();
    const a = audioRef.current;
    if (!a) return;
    if (playing) a.pause();
    else a.play();
  };

  const seek = (e: React.MouseEvent<HTMLDivElement>) => {
    e.stopPropagation();
    const a = audioRef.current;
    if (!a || !duration) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const pct = (e.clientX - rect.left) / rect.width;
    a.currentTime = pct * duration;
  };

  return (
    <div
      className="mt-3 flex items-center gap-3 rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 py-2.5"
      onClick={(e) => e.stopPropagation()}
    >
      <audio
        ref={audioRef}
        src={src}
        preload="metadata"
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
        onEnded={() => { setPlaying(false); setProgress(0); setCurrent(0); }}
        onLoadedMetadata={(e) => setDuration(e.currentTarget.duration)}
        onTimeUpdate={(e) => {
          const a = e.currentTarget;
          setCurrent(a.currentTime);
          setProgress(a.duration ? a.currentTime / a.duration : 0);
        }}
      />
      <button
        onClick={toggle}
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-ark-primary text-white shadow-sm transition-transform hover:scale-105"
        aria-label={playing ? 'Pause voice note' : 'Play voice note'}
      >
        {playing ? <Pause className="h-4 w-4" /> : <Play className="ml-0.5 h-4 w-4" />}
      </button>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-1.5 text-[11px] font-medium text-ark-text-secondary">
          <Mic className="h-3 w-3 text-ark-primary" /> Voice note
        </div>
        <div className="mt-1.5 h-1.5 cursor-pointer rounded-full bg-ark-fill-secondary" onClick={seek}>
          <div className="h-full rounded-full bg-ark-primary transition-[width]" style={{ width: `${progress * 100}%` }} />
        </div>
      </div>
      <span className="fig shrink-0 text-[11px] text-ark-text-tertiary">
        {fmtTime(current)} / {fmtTime(duration)}
      </span>
    </div>
  );
}
