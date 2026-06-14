// Arkline ad components. Three concepts × multiple aspect ratios.
// All ads render at the exact 1080-wide pixel dimensions specified
// in the prompt doc. design_canvas scales them down to fit the canvas.

// Shared chrome ----------------------------------------------------

function Wordmark({ size = 28 }) {
  return (
    <div className="wordmark" style={{ fontSize: size, gap: size * 0.42 }}>
      <span className="mark" style={{ width: size * 0.78, height: size * 0.78 }} />
      <span>Arkline</span>
    </div>
  );
}

function Footer({ pad, bottom, wordmarkSize = 28, urlSize = 22 }) {
  return (
    <div className="footer" style={{ bottom: bottom ?? pad, left: pad, right: pad }}>
      <Wordmark size={wordmarkSize} />
      <span className="url" style={{ fontSize: urlSize }}>arkline.io</span>
    </div>
  );
}

function CTA({ children, size = 26, pad = "22px 32px" }) {
  return (
    <span className="cta" style={{ fontSize: size, padding: pad }}>
      <span>{children}</span>
      <span className="arrow">→</span>
    </span>
  );
}

function AccentLine({ width = 80, top = 0, bottom = 0 }) {
  return <hr className="accent-line" style={{ width, marginTop: top, marginBottom: bottom, marginLeft: 0, marginRight: 0 }} />;
}

// Concept #5 — "150" ------------------------------------------------

function Concept5({ ratio, variant = "urbanist", palette = "dark" }) {
  // Layout per aspect ratio
  const cfg = {
    "1:1":  { pad: 90, num: 440, headSize: 56, bodySize: 26, ctaSize: 24, wm: 28, gap: 28 },
    "4:5":  { pad: 90, num: 500, headSize: 60, bodySize: 28, ctaSize: 26, wm: 30, gap: 32 },
    "9:16": { pad: 100, footerBottom: 65, num: 560, headSize: 68, bodySize: 30, ctaSize: 28, wm: 32, gap: 40 },
  }[ratio];

  const numClass =
    variant === "serif" ? "num num-serif" :
    variant === "inter" ? "num num-inter" :
    variant === "mono"  ? "num mono"      :
    "num";

  const numStyle = variant === "mono" ? { fontWeight: 700, letterSpacing: "-0.06em" } : {};
  // Mono "150" is significantly wider than Urbanist 900 at the same font-size
  // (monospace advance ~0.6em per char). Scale mono down so it doesn't overflow
  // the canvas, especially on 9:16 where horizontal padding is largest.
  const numSize = variant === "mono" ? cfg.num * 0.82 : cfg.num;

  const headClass =
    variant === "serif" ? "hook hook-alt-serif" :
    variant === "inter" ? "hook hook-alt-inter" :
    "hook";

  // For 9:16 we push the giant 150 further down so it sits closer to the optical
  // center of a phone screen (not the geometric center of the canvas).
  const topSpacer = ratio === "9:16" ? 360 : ratio === "4:5" ? 180 : 110;

  return (
    <div className={`ad${palette === "light" ? " light" : ""}`} style={{ width: "100%", height: "100%" }}>
      <div style={{ position: "absolute", inset: 0, padding: `${cfg.pad}px`, display: "flex", flexDirection: "column" }}>
        {/* Eyebrow */}
        <div className="eyebrow" style={{ fontSize: ratio === "9:16" ? 20 : 18, marginTop: topSpacer - cfg.pad }}>
          Founding members · iOS · Spring 2026
        </div>

        {/* Giant numeral */}
        <div style={{ marginTop: cfg.gap * 1.2 }}>
          <span className={numClass} style={{ fontSize: numSize, ...numStyle }}>150</span>
        </div>

        <AccentLine width={88} top={cfg.gap * 1.4} bottom={cfg.gap} />

        <h2 className={headClass} style={{ fontSize: cfg.headSize, marginBottom: cfg.gap * 0.7 }}>
          Founding members.
        </h2>

        <p className="body" style={{ fontSize: cfg.bodySize, maxWidth: 760, margin: 0 }}>
          <strong>$39.99/mo for the life of your membership.</strong><br />
          Arkline launches on iOS this spring.<br />
          After 150, standard pricing applies.
        </p>

        <div style={{ marginTop: cfg.gap * 1.5 }}>
          <CTA size={cfg.ctaSize}>Request an invite</CTA>
        </div>
      </div>
      <Footer pad={cfg.pad} bottom={cfg.footerBottom} wordmarkSize={cfg.wm} urlSize={cfg.wm * 0.78} />
    </div>
  );
}

// Concept #2 — "Stop investing on influencer takes" ----------------

function Concept2({ ratio, palette = "dark" }) {
  const cfg = {
    "1:1":  { pad: 90, hook: 102, body: 26, tag: 28, cta: 24, wm: 28, top: 130 },
    "4:5":  { pad: 90, hook: 112, body: 28, tag: 30, cta: 26, wm: 30, top: 200 },
    "9:16": { pad: 100, hook: 124, body: 32, tag: 34, cta: 28, wm: 32, top: 420 },
  }[ratio];

  return (
    <div className={`ad${palette === "light" ? " light" : ""}`} style={{ width: "100%", height: "100%" }}>
      <div style={{ position: "absolute", inset: 0, padding: cfg.pad, display: "flex", flexDirection: "column" }}>
        <div style={{ marginTop: cfg.top - cfg.pad }}>
          <h1 className="hook" style={{ fontSize: cfg.hook }}>
            Stop investing<br />on influencer<br />takes.
          </h1>
        </div>

        <AccentLine width={88} top={42} bottom={48} />

        <p className="body" style={{ fontSize: cfg.body, color: "var(--fg)", fontWeight: 500, margin: 0 }}>
          Built by an investor tired of crypto Twitter noise.
        </p>

        <p className="body" style={{ fontSize: cfg.body, margin: "26px 0 0", maxWidth: 820 }}>
          Multi-factor risk scoring. Macro regime detection.<br />
          AI-generated briefings. For retail investors<br />
          who want signal, not screaming.
        </p>

        <p className="body" style={{ fontSize: cfg.tag, color: "var(--fg)", fontWeight: 500, margin: "44px 0 0" }}>
          Arkline. Invest with conviction.
        </p>

        <div style={{ marginTop: ratio === "9:16" ? 80 : 56 }}>
          <CTA size={cfg.cta}>Request an invite</CTA>
        </div>
      </div>
      <Footer pad={cfg.pad} wordmarkSize={cfg.wm} urlSize={cfg.wm * 0.78} />
    </div>
  );
}

// Concept #1 — "Today's BTC risk" ----------------------------------

// Decorative low-opacity chart line behind the hero number.
function ChartGhost() {
  // Hand-tuned polyline that looks like a risk-score timeline.
  const pts = [
    [0, 70], [60, 65], [120, 72], [180, 60], [240, 50], [300, 58],
    [360, 45], [420, 40], [480, 50], [540, 35], [600, 30], [660, 38],
    [720, 28], [780, 32], [840, 22], [900, 30], [960, 25], [1020, 20], [1080, 28]
  ].map(p => p.join(",")).join(" ");
  return (
    <svg className="chart" viewBox="0 0 1080 100" preserveAspectRatio="none" style={{ height: "100%", width: "100%" }}>
      <polyline points={pts} fill="none" stroke="currentColor" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

function Concept1({ ratio, palette = "dark" }) {
  const cfg = {
    "1:1":  { pad: 90, num: 340, head: 44, body: 24, cta: 24, wm: 28, top: 200, eyebrow: 18 },
    "4:5":  { pad: 90, num: 380, head: 50, body: 26, cta: 26, wm: 30, top: 290, eyebrow: 20 },
    "9:16": { pad: 100, footerBottom: 90, num: 400, head: 60, body: 30, cta: 28, wm: 32, top: 520, eyebrow: 22, stackChip: true },
  }[ratio];

  return (
    <div className={`ad${palette === "light" ? " light" : ""}`} style={{ width: "100%", height: "100%" }}>
      {/* Decorative chart strip behind the number */}
      <div style={{ position: "absolute", left: 0, right: 0, top: cfg.top + 40, height: cfg.num * 0.9 }}>
        <ChartGhost />
      </div>

      <div style={{ position: "absolute", inset: 0, padding: cfg.pad, display: "flex", flexDirection: "column" }}>
        <div style={{ marginTop: cfg.top - cfg.pad, display: "flex", alignItems: "baseline", gap: 16 }}>
          <span className="mono eyebrow" style={{ fontSize: cfg.eyebrow, letterSpacing: "0.22em" }}>
            BTC RISK · TODAY
          </span>
        </div>

        <div style={{ marginTop: 20, display: "flex", flexDirection: cfg.stackChip ? "column" : "row", alignItems: cfg.stackChip ? "flex-start" : "baseline", gap: cfg.stackChip ? 18 : 24 }}>
          <span className="num mono" style={{ fontSize: cfg.num, fontWeight: 700, letterSpacing: "-0.05em" }}>0.42</span>
          <span className="mono" style={{ color: "var(--accent)", fontSize: cfg.stackChip ? 28 : cfg.num * 0.14, fontWeight: 500, letterSpacing: "0.12em" }}>
            ▲ LOW
          </span>
        </div>

        <AccentLine width={88} top={40} bottom={36} />

        <h2 className="hook" style={{ fontSize: cfg.head, fontWeight: 700, letterSpacing: "-0.025em" }}>
          Historically a low-risk reading.
        </h2>

        <p className="body" style={{ fontSize: cfg.body, margin: "26px 0 0", maxWidth: 820 }}>
          Arkline's 8-factor model identifies<br />
          inflection points before they're obvious.<br />
          Signal, not screaming.
        </p>

        <div style={{ marginTop: 44 }}>
          <CTA size={cfg.cta}>Request an invite</CTA>
        </div>
      </div>
      <Footer pad={cfg.pad} bottom={cfg.footerBottom} wordmarkSize={cfg.wm} urlSize={cfg.wm * 0.78} />
    </div>
  );
}

Object.assign(window, { Concept5, Concept2, Concept1, Footer, Wordmark, CTA, AccentLine, ChartGhost });
