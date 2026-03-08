import { useState, useEffect, type RefObject } from 'react';

interface UseInViewOptions {
  once?: boolean;
  margin?: string;
}

export function useInView(
  ref: RefObject<HTMLElement | null>,
  { once = true, margin = '0px' }: UseInViewOptions = {},
): boolean {
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          if (once) observer.disconnect();
        } else if (!once) {
          setInView(false);
        }
      },
      { rootMargin: margin },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [ref, once, margin]);

  return inView;
}
