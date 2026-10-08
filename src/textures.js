import * as THREE from 'three';

let ANISO = 4;
export function setAnisotropy(n) { ANISO = Math.max(1, Math.min(8, n)); }

export function rng(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}

export function texture(c, repeatX = 1, repeatY = 1, srgb = true) {
  const t = new THREE.CanvasTexture(c);
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(repeatX, repeatY);
  t.anisotropy = ANISO;
  return t;
}

function noise(g, w, h, amount, r) {
  const img = g.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (r() - 0.5) * amount;
    d[i] += n; d[i + 1] += n; d[i + 2] += n;
  }
  g.putImageData(img, 0, 0);
}

function woodGrain(g, x, y, w, h, base, r) {
  g.fillStyle = `hsl(${base.h},${base.s}%,${base.l}%)`;
  g.fillRect(x, y, w, h);
  for (let k = 0; k < 6; k++) {
    g.fillStyle = `hsla(${base.h},${base.s}%,${base.l + (r() - 0.5) * 12}%,0.25)`;
    g.fillRect(x, y + r() * h, w, h * (0.1 + r() * 0.3));
  }
  const lines = Math.round(h / 2.2);
  for (let k = 0; k < lines; k++) {
    const yy = y + r() * h, amp = r() * 4, freq = 0.004 + r() * 0.01, ph = r() * 6;
    g.strokeStyle = `hsla(${base.h},${base.s}%,${Math.max(4, base.l - 6 - r() * 10)}%,${0.12 + r() * 0.25})`;
    g.lineWidth = 0.6 + r() * 1.4;
    g.beginPath();
    for (let s = 0; s <= w; s += 16) {
      const py = yy + Math.sin(s * freq + ph) * amp;
      if (s === 0) g.moveTo(x + s, py); else g.lineTo(x + s, py);
    }
    g.stroke();
  }
}

export function parquetCanvas() {
  const S = 1024, c = canvas(S, S), g = c.getContext('2d'), r = rng(7);
  const rows = 8, h = S / rows;
  for (let i = 0; i < rows; i++) {
    let x = -r() * 400;
    while (x < S) {
      const len = 320 + r() * 420;
      const base = { h: 24 + r() * 10, s: 42 + r() * 18, l: 26 + r() * 14 };
      g.save();
      g.beginPath(); g.rect(Math.max(0, x), i * h, len, h); g.clip();
      woodGrain(g, x, i * h, len, h, base, r);
      g.restore();
      g.fillStyle = 'rgba(0,0,0,0.55)';
      g.fillRect(x, i * h, 3, h);
      x += len;
    }
    g.fillStyle = 'rgba(0,0,0,0.6)';
    g.fillRect(0, i * h, S, 3);
  }
  noise(g, S, S, 10, r);
  return c;
}

export function darkWoodCanvas(seed = 11, l = 20) {
  const W = 512, H = 512, c = canvas(W, H), g = c.getContext('2d'), r = rng(seed);
  woodGrain(g, 0, 0, W, H, { h: 20, s: 45, l }, r);
  noise(g, W, H, 8, r);
  return c;
}

export function wallpaperCanvas() {
  const S = 512, c = canvas(S, S), g = c.getContext('2d'), r = rng(5);
  g.fillStyle = '#20372e';
  g.fillRect(0, 0, S, S);
  for (let x = 0; x < S; x += 64) {
    g.fillStyle = 'rgba(0,0,0,0.10)';
    g.fillRect(x, 0, 6, S);
  }
  const motif = (cx, cy) => {
    g.save();
    g.translate(cx, cy);
    g.fillStyle = 'rgba(214,182,112,0.13)';
    for (let i = 0; i < 4; i++) {
      g.rotate(Math.PI / 2);
      g.beginPath(); g.ellipse(0, -46, 18, 46, 0, 0, Math.PI * 2); g.fill();
    }
    g.fillStyle = 'rgba(214,182,112,0.18)';
    g.beginPath(); g.arc(0, 0, 14, 0, Math.PI * 2); g.fill();
    g.strokeStyle = 'rgba(214,182,112,0.10)';
    g.lineWidth = 3;
    g.beginPath(); g.arc(0, 0, 100, 0, Math.PI * 2); g.stroke();
    g.restore();
  };
  [[0, 0], [S, 0], [0, S], [S, S], [S / 2, S / 2]].forEach(([x, y]) => motif(x, y));
  noise(g, S, S, 9, r);
  return c;
}

export function feltCanvas() {
  const S = 512, c = canvas(S, S), g = c.getContext('2d'), r = rng(9);
  g.fillStyle = '#17583a';
  g.fillRect(0, 0, S, S);
  for (let i = 0; i < 4000; i++) {
    g.fillStyle = r() < 0.5 ? 'rgba(0,0,0,0.06)' : 'rgba(255,255,255,0.04)';
    g.fillRect(r() * S, r() * S, 2 + r() * 3, 1);
  }
  noise(g, S, S, 16, r);
  return c;
}

export function rugCanvas() {
  const S = 1024, c = canvas(S, S), g = c.getContext('2d'), r = rng(3), C = S / 2;
  const ring = (rad, col) => { g.fillStyle = col; g.beginPath(); g.arc(C, C, rad, 0, Math.PI * 2); g.fill(); };
  ring(512, '#3a1016'); ring(492, '#c9a24a'); ring(480, '#1c2340'); ring(432, '#c9a24a'); ring(424, '#7a1a24');
  g.save(); g.translate(C, C);
  for (let i = 0; i < 64; i++) {
    g.rotate(Math.PI * 2 / 64);
    g.fillStyle = i % 2 ? '#c9a24a' : '#8a2a30';
    g.beginPath(); g.arc(456, 0, 9, 0, Math.PI * 2); g.fill();
  }
  for (let i = 0; i < 16; i++) {
    g.rotate(Math.PI * 2 / 16);
    g.fillStyle = 'rgba(201,162,74,0.85)';
    g.beginPath(); g.ellipse(305, 0, 85, 26, 0, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#1c2340';
    g.beginPath(); g.ellipse(305, 0, 50, 11, 0, 0, Math.PI * 2); g.fill();
    g.fillStyle = 'rgba(201,162,74,0.6)';
    g.beginPath(); g.arc(205, 60, 10, 0, Math.PI * 2); g.fill();
  }
  g.restore();
  ring(182, '#c9a24a'); ring(172, '#1c2340'); ring(124, '#7a1a24'); ring(60, '#c9a24a'); ring(48, '#1c2340');
  noise(g, S, S, 22, r);
  return c;
}

export function nightSkyCanvas() {
  const W = 512, H = 768, c = canvas(W, H), g = c.getContext('2d'), r = rng(21);
  const grad = g.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, '#050817'); grad.addColorStop(0.6, '#15183d'); grad.addColorStop(1, '#3b2a57');
  g.fillStyle = grad; g.fillRect(0, 0, W, H);
  for (let i = 0; i < 260; i++) {
    const a = 0.3 + r() * 0.7;
    g.fillStyle = `rgba(255,255,240,${a})`;
    const s = r() < 0.92 ? 1.2 : 2.4;
    g.fillRect(r() * W, r() * H * 0.8, s, s);
  }
  const glow = g.createRadialGradient(360, 170, 10, 360, 170, 140);
  glow.addColorStop(0, 'rgba(255,250,220,0.5)'); glow.addColorStop(1, 'rgba(255,250,220,0)');
  g.fillStyle = glow; g.fillRect(0, 0, W, H);
  g.fillStyle = '#f6f0d8';
  g.beginPath(); g.arc(360, 170, 38, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#0b0d22';
  g.beginPath(); g.moveTo(0, H);
  for (let x = 0; x <= W; x += 8) g.lineTo(x, H - 120 - Math.sin(x * 0.012) * 40 - Math.sin(x * 0.041) * 12);
  g.lineTo(W, H); g.fill();
  g.fillStyle = '#05060f';
  for (let i = 0; i < 14; i++) {
    const x = r() * W, h = 60 + r() * 90, b = H - 70 - r() * 30;
    g.beginPath(); g.moveTo(x, b - h); g.lineTo(x - 18, b); g.lineTo(x + 18, b); g.fill();
  }
  g.fillRect(0, H - 80, W, 80);
  return c;
}

export function paintingCanvas() {
  const W = 768, H = 512, c = canvas(W, H), g = c.getContext('2d'), r = rng(42);
  const sky = g.createLinearGradient(0, 0, 0, H);
  sky.addColorStop(0, '#2b2350'); sky.addColorStop(0.45, '#c8603a'); sky.addColorStop(0.62, '#f0b45a');
  g.fillStyle = sky; g.fillRect(0, 0, W, H);
  g.fillStyle = 'rgba(255,230,160,0.95)';
  g.beginPath(); g.arc(470, 300, 46, 0, Math.PI * 2); g.fill();
  const layers = ['#6b3a4a', '#4a2e4a', '#2e2440', '#1a1830'];
  layers.forEach((col, i) => {
    g.fillStyle = col;
    g.beginPath(); g.moveTo(0, H);
    const base = 300 + i * 50, ph = r() * 6;
    for (let x = 0; x <= W; x += 6) g.lineTo(x, base - Math.sin(x * 0.006 + ph) * 40 - Math.sin(x * 0.02 + ph) * 10);
    g.lineTo(W, H); g.fill();
  });
  for (let i = 0; i < 1800; i++) {
    g.strokeStyle = `rgba(${200 + r() * 55},${120 + r() * 100},${80 + r() * 90},${0.04 + r() * 0.05})`;
    g.lineWidth = 2 + r() * 4;
    const x = r() * W, y = r() * H;
    g.beginPath(); g.moveTo(x, y); g.lineTo(x + 8 + r() * 18, y + (r() - 0.5) * 6); g.stroke();
  }
  noise(g, W, H, 14, r);
  return c;
}

export function flameCanvas() {
  const W = 128, H = 256, c = canvas(W, H), g = c.getContext('2d');
  g.save();
  g.translate(W / 2, H * 0.72);
  g.scale(1, 2.6);
  const grad = g.createRadialGradient(0, 0, 0, 0, 0, W / 2);
  grad.addColorStop(0, 'rgba(255,250,220,1)');
  grad.addColorStop(0.25, 'rgba(255,200,90,0.9)');
  grad.addColorStop(0.6, 'rgba(255,110,30,0.45)');
  grad.addColorStop(1, 'rgba(255,60,0,0)');
  g.fillStyle = grad;
  g.beginPath(); g.arc(0, 0, W / 2, 0, Math.PI * 2); g.fill();
  g.restore();
  return c;
}

export function glowCanvas(color = '255,200,120') {
  const S = 128, c = canvas(S, S), g = c.getContext('2d');
  const grad = g.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
  grad.addColorStop(0, `rgba(${color},1)`);
  grad.addColorStop(0.3, `rgba(${color},0.35)`);
  grad.addColorStop(1, `rgba(${color},0)`);
  g.fillStyle = grad; g.fillRect(0, 0, S, S);
  return c;
}

function rr(g, x, y, w, h, rad) {
  g.beginPath();
  g.moveTo(x + rad, y);
  g.arcTo(x + w, y, x + w, y + h, rad);
  g.arcTo(x + w, y + h, x, y + h, rad);
  g.arcTo(x, y + h, x, y, rad);
  g.arcTo(x, y, x + w, y, rad);
  g.closePath();
}

export function cardFaceCanvas(rank, suit) {
  const W = 256, H = 372, c = canvas(W, H), g = c.getContext('2d');
  const red = suit === '♥' || suit === '♦';
  const col = red ? '#c4161c' : '#16161a';
  g.fillStyle = '#fbf8ef'; rr(g, 2, 2, W - 4, H - 4, 18); g.fill();
  g.strokeStyle = '#d8d0bc'; g.lineWidth = 3; g.stroke();
  g.fillStyle = col; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.font = "700 46px 'Nunito', sans-serif";
  g.fillText(rank, 34, 40);
  g.font = "38px sans-serif";
  g.fillText(suit, 34, 84);
  g.save(); g.translate(W - 34, H - 40); g.rotate(Math.PI);
  g.font = "700 46px 'Nunito', sans-serif"; g.fillText(rank, 0, 0);
  g.font = "38px sans-serif"; g.fillText(suit, 0, -44);
  g.restore();
  g.font = "150px sans-serif";
  g.fillText(suit, W / 2, H / 2 + 6);
  return c;
}

export function cardBackCanvas() {
  const W = 256, H = 372, c = canvas(W, H), g = c.getContext('2d');
  g.fillStyle = '#fbf8ef'; rr(g, 2, 2, W - 4, H - 4, 18); g.fill();
  g.fillStyle = '#7a1424'; rr(g, 16, 16, W - 32, H - 32, 10); g.fill();
  g.save(); rr(g, 16, 16, W - 32, H - 32, 10); g.clip();
  g.strokeStyle = 'rgba(214,182,112,0.6)'; g.lineWidth = 2;
  for (let i = -H; i < W + H; i += 18) {
    g.beginPath(); g.moveTo(i, 0); g.lineTo(i + H, H); g.stroke();
    g.beginPath(); g.moveTo(i, H); g.lineTo(i + H, 0); g.stroke();
  }
  g.restore();
  g.strokeStyle = '#d6b670'; g.lineWidth = 4; rr(g, 26, 26, W - 52, H - 52, 8); g.stroke();
  return c;
}

export function dieFaceCanvas(n) {
  const S = 128, c = canvas(S, S), g = c.getContext('2d');
  g.fillStyle = '#f7f2e6'; g.fillRect(0, 0, S, S);
  const P = { 1: [[0.5, 0.5]], 2: [[0.27, 0.27], [0.73, 0.73]], 3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
    4: [[0.27, 0.27], [0.73, 0.27], [0.27, 0.73], [0.73, 0.73]],
    5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
    6: [[0.27, 0.22], [0.73, 0.22], [0.27, 0.5], [0.73, 0.5], [0.27, 0.78], [0.73, 0.78]] };
  P[n].forEach(([x, y]) => {
    const grad = g.createRadialGradient(x * S - 3, y * S - 3, 1, x * S, y * S, 12);
    grad.addColorStop(0, n === 1 ? '#e0353a' : '#3a3a40'); grad.addColorStop(1, n === 1 ? '#8a0f14' : '#0c0c10');
    g.fillStyle = grad;
    g.beginPath(); g.arc(x * S, y * S, n === 1 ? 15 : 11, 0, Math.PI * 2); g.fill();
  });
  return c;
}
