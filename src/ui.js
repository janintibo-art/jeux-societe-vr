import * as THREE from 'three';
import { canvas } from './textures.js';

export const FONT_TITLE = "'Cinzel', Georgia, serif";
export const FONT_BODY = "'Nunito', 'Segoe UI', Roboto, sans-serif";
export const GOLD = '#d8b25a';

export function roundRect(g, x, y, w, h, r) {
  g.beginPath();
  g.moveTo(x + r, y);
  g.arcTo(x + w, y, x + w, y + h, r);
  g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r);
  g.arcTo(x, y, x + w, y, r);
  g.closePath();
}

export function hexA(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

export function fitFont(g, text, weight, family, size, maxWidth) {
  let s = size;
  g.font = `${weight} ${s}px ${family}`;
  while (s > 8 && g.measureText(text).width > maxWidth) {
    s -= 2;
    g.font = `${weight} ${s}px ${family}`;
  }
  return s;
}

export class CanvasPlane {
  constructor(width, height, ppm = 1000) {
    this.width = width;
    this.height = height;
    this.canvas = canvas(Math.round(width * ppm), Math.round(height * ppm));
    this.ctx = this.canvas.getContext('2d');
    this.texture = new THREE.CanvasTexture(this.canvas);
    this.texture.colorSpace = THREE.SRGBColorSpace;
    this.texture.anisotropy = 4;
    this.mesh = new THREE.Mesh(
      new THREE.PlaneGeometry(width, height),
      new THREE.MeshBasicMaterial({ map: this.texture, transparent: true, toneMapped: false, depthWrite: false })
    );
  }
  refresh() { this.texture.needsUpdate = true; }
}

export class Button3D {
  constructor({ width = 0.8, height = 0.15, label = '', sub = '', badge = null, accent = GOLD,
    enabled = true, active = false, align = 'left', sound = null, onSelect = null, ppm = 1100 }) {
    this.plane = new CanvasPlane(width, height, ppm);
    this.mesh = this.plane.mesh;
    this.mesh.renderOrder = 2;
    Object.assign(this, { label, sub, badge, accent, enabled, active, align, sound, onSelect });
    this.hovered = false;
    this.pulse = 0;
    this.shake = 0;
    this.baseX = 0;
    this.entry = {
      object: this.mesh,
      onHover: (on) => this.setHover(on),
      onSelect: () => this.press(),
    };
    this.draw();
  }

  place(x, y, z) {
    this.mesh.position.set(x, y, z);
    this.baseX = x;
    return this;
  }

  set(props) {
    Object.assign(this, props);
    this.draw();
  }

  setHover(on) {
    this.hovered = on;
    this.draw();
    if (on && this.enabled) this.sound?.hover();
  }

  press() {
    if (!this.enabled) {
      this.shake = 0.35;
      this.sound?.deny();
      return;
    }
    this.pulse = 1;
    this.sound?.click();
    this.onSelect?.();
  }

  update(dt) {
    const target = this.hovered && this.enabled ? 1.045 : 1;
    let s = this.mesh.scale.x + (target - this.mesh.scale.x) * Math.min(1, dt * 14);
    if (this.pulse > 0) {
      this.pulse = Math.max(0, this.pulse - dt * 4);
      s -= this.pulse * 0.03;
    }
    this.mesh.scale.setScalar(s);
    if (this.shake > 0) {
      this.shake = Math.max(0, this.shake - dt);
      this.mesh.position.x = this.baseX + Math.sin(this.shake * 70) * 0.006 * (this.shake / 0.35);
    } else {
      this.mesh.position.x = this.baseX;
    }
  }

  draw() {
    const g = this.plane.ctx, W = this.plane.canvas.width, H = this.plane.canvas.height;
    const pad = H * 0.12, R = H * 0.26;
    const hov = this.hovered && this.enabled;
    g.clearRect(0, 0, W, H);

    g.save();
    if (hov) { g.shadowColor = hexA(this.accent, 0.9); g.shadowBlur = H * 0.22; }
    roundRect(g, pad, pad, W - 2 * pad, H - 2 * pad, R);
    const grad = g.createLinearGradient(0, pad, 0, H - pad);
    if (this.active) {
      grad.addColorStop(0, hexA(this.accent, 0.55));
      grad.addColorStop(1, hexA(this.accent, 0.3));
    } else if (hov) {
      grad.addColorStop(0, 'rgba(62,50,34,0.97)');
      grad.addColorStop(1, 'rgba(34,27,19,0.97)');
    } else {
      grad.addColorStop(0, 'rgba(30,28,33,0.93)');
      grad.addColorStop(1, 'rgba(15,14,17,0.93)');
    }
    g.fillStyle = grad;
    g.fill();
    g.restore();

    g.lineWidth = H * 0.03;
    g.strokeStyle = this.enabled ? (hov ? this.accent : hexA(this.accent, 0.55)) : 'rgba(255,255,255,0.14)';
    roundRect(g, pad, pad, W - 2 * pad, H - 2 * pad, R);
    g.stroke();

    const textCol = this.enabled ? '#f5ecd8' : 'rgba(245,236,216,0.45)';
    const subCol = this.enabled ? 'rgba(232,214,178,0.75)' : 'rgba(232,214,178,0.35)';
    g.textBaseline = 'middle';
    let maxW = W - pad * 2 - H * 0.6;
    if (this.badge) maxW -= H * 1.6;

    if (this.align === 'center') {
      g.textAlign = 'center';
      g.fillStyle = textCol;
      fitFont(g, this.label, 800, FONT_BODY, Math.round(H * (this.sub ? 0.3 : 0.36)), maxW);
      g.fillText(this.label, W / 2, this.sub ? H * 0.42 : H * 0.52);
      if (this.sub) {
        g.fillStyle = subCol;
        fitFont(g, this.sub, 400, FONT_BODY, Math.round(H * 0.19), maxW);
        g.fillText(this.sub, W / 2, H * 0.71);
      }
    } else {
      const x = pad + H * 0.32;
      g.textAlign = 'left';
      g.fillStyle = textCol;
      fitFont(g, this.label, 800, FONT_BODY, Math.round(H * 0.32), maxW);
      g.fillText(this.label, x, this.sub ? H * 0.4 : H * 0.52);
      if (this.sub) {
        g.fillStyle = subCol;
        fitFont(g, this.sub, 400, FONT_BODY, Math.round(H * 0.19), maxW);
        g.fillText(this.sub, x, H * 0.7);
      }
    }

    if (this.badge) {
      const bw = H * 1.45, bh = H * 0.32, bx = W - pad - H * 0.25 - bw, by = H / 2 - bh / 2;
      roundRect(g, bx, by, bw, bh, bh / 2);
      g.fillStyle = this.enabled ? hexA(this.accent, hov ? 1 : 0.85) : 'rgba(255,255,255,0.08)';
      g.fill();
      g.strokeStyle = this.enabled ? hexA(this.accent, 1) : 'rgba(255,255,255,0.18)';
      g.lineWidth = 2;
      g.stroke();
      g.fillStyle = this.enabled ? '#1b140c' : 'rgba(245,236,216,0.6)';
      g.textAlign = 'center';
      g.font = `700 ${Math.round(H * 0.17)}px ${FONT_BODY}`;
      g.fillText(this.badge, bx + bw / 2, H / 2 + 1);
    }
    this.plane.refresh();
  }
}
