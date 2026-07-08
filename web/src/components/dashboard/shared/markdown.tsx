'use client';

/**
 * Lightweight markdown renderer for broadcast/briefing content — matches the
 * subset the iOS editor produces (headings, bold, italic, inline code, links,
 * bullet & numbered lists, blockquotes, horizontal rules). Zero dependencies;
 * all output styled on ark tokens. Not a full CommonMark parser by design.
 */

import { Fragment, type ReactNode } from 'react';

/* Inline: **bold**, *italic*, `code`, [text](url) */
function renderInline(text: string, keyPrefix: string): ReactNode[] {
  const out: ReactNode[] = [];
  const pattern = /(\*\*(.+?)\*\*|\*([^*]+)\*|`([^`]+)`|\[([^\]]+)\]\((https?:\/\/[^)\s]+)\))/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let k = 0;

  while ((m = pattern.exec(text)) !== null) {
    if (m.index > last) out.push(<Fragment key={`${keyPrefix}-t${k++}`}>{text.slice(last, m.index)}</Fragment>);
    if (m[2] !== undefined) {
      out.push(<strong key={`${keyPrefix}-b${k++}`} className="font-semibold text-ark-text">{renderInline(m[2], `${keyPrefix}-b${k}`)}</strong>);
    } else if (m[3] !== undefined) {
      out.push(<em key={`${keyPrefix}-i${k++}`}>{m[3]}</em>);
    } else if (m[4] !== undefined) {
      out.push(<code key={`${keyPrefix}-c${k++}`} className="rounded bg-ark-fill-secondary px-1 py-0.5 font-mono text-[0.85em]">{m[4]}</code>);
    } else if (m[5] !== undefined && m[6] !== undefined) {
      out.push(
        <a key={`${keyPrefix}-a${k++}`} href={m[6]} target="_blank" rel="noopener noreferrer" className="font-medium text-ark-primary underline-offset-2 hover:underline">
          {m[5]}
        </a>,
      );
    }
    last = pattern.lastIndex;
  }
  if (last < text.length) out.push(<Fragment key={`${keyPrefix}-t${k++}`}>{text.slice(last)}</Fragment>);
  return out;
}

type Block =
  | { type: 'h'; level: number; text: string }
  | { type: 'p'; text: string }
  | { type: 'ul'; items: string[] }
  | { type: 'ol'; items: string[] }
  | { type: 'quote'; text: string }
  | { type: 'hr' };

function parseBlocks(md: string): Block[] {
  const lines = md.replace(/\r\n/g, '\n').split('\n');
  const blocks: Block[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    if (!trimmed) { i++; continue; }

    const h = /^(#{1,6})\s+(.*)$/.exec(trimmed);
    if (h) { blocks.push({ type: 'h', level: h[1].length, text: h[2] }); i++; continue; }

    if (/^(-{3,}|\*{3,}|_{3,})$/.test(trimmed)) { blocks.push({ type: 'hr' }); i++; continue; }

    if (/^>\s?/.test(trimmed)) {
      const quote: string[] = [];
      while (i < lines.length && /^>\s?/.test(lines[i].trim())) {
        quote.push(lines[i].trim().replace(/^>\s?/, ''));
        i++;
      }
      blocks.push({ type: 'quote', text: quote.join(' ') });
      continue;
    }

    if (/^[-*•]\s+/.test(trimmed)) {
      const items: string[] = [];
      while (i < lines.length && /^[-*•]\s+/.test(lines[i].trim())) {
        items.push(lines[i].trim().replace(/^[-*•]\s+/, ''));
        i++;
      }
      blocks.push({ type: 'ul', items });
      continue;
    }

    if (/^\d+[.)]\s+/.test(trimmed)) {
      const items: string[] = [];
      while (i < lines.length && /^\d+[.)]\s+/.test(lines[i].trim())) {
        items.push(lines[i].trim().replace(/^\d+[.)]\s+/, ''));
        i++;
      }
      blocks.push({ type: 'ol', items });
      continue;
    }

    // Paragraph: consume consecutive plain lines.
    const para: string[] = [trimmed];
    i++;
    while (
      i < lines.length &&
      lines[i].trim() &&
      !/^(#{1,6})\s+/.test(lines[i].trim()) &&
      !/^[-*•]\s+/.test(lines[i].trim()) &&
      !/^\d+[.)]\s+/.test(lines[i].trim()) &&
      !/^>\s?/.test(lines[i].trim()) &&
      !/^(-{3,}|\*{3,}|_{3,})$/.test(lines[i].trim())
    ) {
      para.push(lines[i].trim());
      i++;
    }
    blocks.push({ type: 'p', text: para.join(' ') });
  }

  return blocks;
}

const H_STYLES: Record<number, string> = {
  1: 'text-lg font-bold text-ark-text',
  2: 'text-base font-bold text-ark-text',
  3: 'text-sm font-semibold text-ark-text',
  4: 'text-sm font-semibold text-ark-text-secondary',
  5: 'text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary',
  6: 'text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary',
};

export function Markdown({ content, className }: { content: string; className?: string }) {
  const blocks = parseBlocks(content);

  return (
    <div className={className}>
      {blocks.map((b, i) => {
        switch (b.type) {
          case 'h':
            return (
              <p key={i} className={`${H_STYLES[b.level]} ${i > 0 ? 'mt-4' : ''} mb-1.5 font-[family-name:var(--font-urbanist)]`}>
                {renderInline(b.text, `h${i}`)}
              </p>
            );
          case 'hr':
            return <div key={i} className="my-4 h-px bg-ark-divider" />;
          case 'quote':
            return (
              <blockquote key={i} className="my-2 border-l-2 border-ark-primary/40 bg-ark-fill-secondary/40 px-3 py-2 text-sm italic text-ark-text-secondary">
                {renderInline(b.text, `q${i}`)}
              </blockquote>
            );
          case 'ul':
            return (
              <ul key={i} className="my-2 space-y-1 text-sm leading-relaxed text-ark-text-secondary">
                {b.items.map((item, j) => (
                  <li key={j} className="flex gap-2">
                    <span className="mt-[7px] h-1 w-1 shrink-0 rounded-full bg-ark-text-tertiary" />
                    <span>{renderInline(item, `u${i}-${j}`)}</span>
                  </li>
                ))}
              </ul>
            );
          case 'ol':
            return (
              <ol key={i} className="my-2 space-y-1 text-sm leading-relaxed text-ark-text-secondary">
                {b.items.map((item, j) => (
                  <li key={j} className="flex gap-2">
                    <span className="fig shrink-0 font-medium text-ark-text-tertiary">{j + 1}.</span>
                    <span>{renderInline(item, `o${i}-${j}`)}</span>
                  </li>
                ))}
              </ol>
            );
          default:
            return (
              <p key={i} className="my-2 text-sm leading-relaxed text-ark-text-secondary">
                {renderInline(b.text, `p${i}`)}
              </p>
            );
        }
      })}
    </div>
  );
}
