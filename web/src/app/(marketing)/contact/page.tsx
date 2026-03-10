'use client';

import { useState, type FormEvent } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Input, Button } from '@/components/ui';
import { AnimatedBackground } from '@/components/marketing/animated-bg';
import { FadeIn } from '@/components/marketing/fade-in';

type Status = 'idle' | 'loading' | 'success' | 'error';

const CONTACT_RATE_LIMIT_KEY = 'arkline_contact_last_submit';
const CONTACT_RATE_LIMIT_MS = 60_000; // 60 seconds between submissions

export default function ContactPage() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');
  const [status, setStatus] = useState<Status>('idle');
  const [errorText, setErrorText] = useState('');

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();

    const trimmedName = name.trim();
    const trimmedEmail = email.trim();
    const trimmedMessage = message.trim();

    if (!trimmedName || !trimmedEmail || !trimmedMessage) {
      setErrorText('Please fill in all fields.');
      setStatus('error');
      return;
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      setErrorText('Please enter a valid email address.');
      setStatus('error');
      return;
    }

    const lastSubmit = Number(localStorage.getItem(CONTACT_RATE_LIMIT_KEY) || '0');
    if (Date.now() - lastSubmit < CONTACT_RATE_LIMIT_MS) {
      setErrorText('Please wait a moment before sending another message.');
      setStatus('error');
      return;
    }

    setStatus('loading');
    setErrorText('');
    localStorage.setItem(CONTACT_RATE_LIMIT_KEY, String(Date.now()));

    try {
      const supabase = createClient();
      const { error } = await supabase
        .from('contact_messages')
        .insert({ name: trimmedName, email: trimmedEmail, message: trimmedMessage });

      if (error) throw error;
      setStatus('success');
    } catch {
      setErrorText('Something went wrong. Please try again.');
      setStatus('error');
    }
  }

  return (
    <section className="relative overflow-hidden pt-32 pb-16 sm:pt-40 sm:pb-20">
      <AnimatedBackground />

      <div className="relative mx-auto max-w-lg px-4 sm:px-6">
        <FadeIn onMount className="text-center">
          <h1 className="font-[family-name:var(--font-urbanist)] text-3xl font-semibold text-ark-text sm:text-4xl">
            Get in Touch
          </h1>
          <p className="mt-3 text-ark-text-secondary">
            Have a question or feedback? We&apos;d love to hear from you.
          </p>
        </FadeIn>

        <FadeIn onMount delay={0.1} className="mt-10">
          {status === 'success' ? (
            <div className="rounded-2xl border border-white/[0.06] bg-white/[0.02] p-8 text-center">
              <p className="text-lg font-medium text-ark-success">
                Message sent!
              </p>
              <p className="mt-2 text-sm text-ark-text-secondary">
                Thanks for reaching out. We&apos;ll get back to you soon.
              </p>
            </div>
          ) : (
            <form
              onSubmit={handleSubmit}
              className="space-y-5 rounded-2xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8"
            >
              <Input
                id="name"
                label="Name"
                placeholder="Your name"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
              <Input
                id="email"
                label="Email"
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
              <div className="flex flex-col gap-1.5">
                <label htmlFor="message" className="text-sm font-medium text-ark-text">
                  Message
                </label>
                <textarea
                  id="message"
                  rows={5}
                  placeholder="How can we help?"
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  className="
                    w-full rounded-lg border bg-ark-fill-secondary px-3 py-2.5
                    text-sm text-ark-text placeholder:text-ark-text-tertiary
                    outline-none transition-colors duration-150
                    border-ark-divider
                    focus:border-ark-primary focus:ring-2 focus:ring-ark-primary/20
                    resize-none
                  "
                />
              </div>

              {status === 'error' && (
                <p className="text-xs text-ark-error">{errorText}</p>
              )}

              <Button type="submit" loading={status === 'loading'} className="w-full">
                Send Message
              </Button>
            </form>
          )}
        </FadeIn>
      </div>
    </section>
  );
}
