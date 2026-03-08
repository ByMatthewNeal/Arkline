'use client';

const orbs = [
  { x: '15%', y: '20%', size: 600, color: 'rgba(59,130,246,0.15)', duration: 20 },
  { x: '75%', y: '60%', size: 500, color: 'rgba(99,102,241,0.12)', duration: 25 },
  { x: '50%', y: '80%', size: 400, color: 'rgba(139,92,246,0.10)', duration: 18 },
  { x: '85%', y: '15%', size: 350, color: 'rgba(59,130,246,0.08)', duration: 22 },
];

export function AnimatedBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {orbs.map((orb, i) => (
        <div
          key={i}
          className="absolute rounded-full blur-[100px] animate-orb-float"
          style={{
            width: orb.size,
            height: orb.size,
            background: orb.color,
            left: orb.x,
            top: orb.y,
            transform: 'translate(-50%, -50%)',
            animationDuration: `${orb.duration}s`,
            animationDelay: `${i * -5}s`,
          }}
        />
      ))}

      {/* Grid overlay */}
      <div
        className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)',
          backgroundSize: '64px 64px',
        }}
      />
    </div>
  );
}
