export class Sound {
  constructor() {
    this.ctx = null;
    this.master = null;
  }

  ensure() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return false;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.9;
      this.master.connect(this.ctx.destination);
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
    return true;
  }

  tone(freq, dur, type = 'sine', vol = 0.1, when = 0, slideTo = null) {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime + when;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t0);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t0 + dur);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(vol, t0 + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g).connect(this.master);
    o.start(t0);
    o.stop(t0 + dur + 0.02);
  }

  noise(dur, freq, q, vol, when = 0) {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime + when;
    const len = Math.max(1, Math.floor(this.ctx.sampleRate * dur));
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3);
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    const f = this.ctx.createBiquadFilter();
    f.type = 'bandpass';
    f.frequency.value = freq;
    f.Q.value = q;
    const g = this.ctx.createGain();
    g.gain.value = vol;
    src.connect(f).connect(g).connect(this.master);
    src.start(t0);
  }

  hover() { this.tone(1500, 0.035, 'sine', 0.025); }
  click() { this.tone(900, 0.07, 'triangle', 0.08, 0, 1300); }
  deny() { this.tone(240, 0.1, 'square', 0.035); this.tone(180, 0.14, 'square', 0.035, 0.08); }
  whoosh() { this.noise(0.25, 900, 0.8, 0.12); }

  clack(strength = 1) {
    const v = Math.min(1, strength);
    this.noise(0.06, 2600, 2.5, 0.5 * v);
    this.tone(420 + Math.random() * 60, 0.08, 'sine', 0.12 * v, 0, 260);
  }

  win() {
    [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => this.tone(f, 0.35, 'triangle', 0.09, i * 0.11));
    this.tone(1318.5, 0.6, 'sine', 0.05, 0.44);
  }

  lose() {
    [392, 349.23, 311.13, 261.63].forEach((f, i) => this.tone(f, 0.3, 'triangle', 0.07, i * 0.14));
  }

  draw() {
    this.tone(440, 0.25, 'triangle', 0.07);
    this.tone(440, 0.25, 'triangle', 0.07, 0.2);
  }
}
