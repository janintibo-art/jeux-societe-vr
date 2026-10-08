import * as THREE from 'three';
import { CanvasPlane, Button3D, roundRect, hexA, fitFont, FONT_TITLE, FONT_BODY, GOLD } from './ui.js';
import { cardFaceCanvas, cardBackCanvas, texture } from './textures.js';
import { tokenGeometry, tokenMaterial, TOKEN_COLORS, makeDie } from './pieces.js';

export const CATEGORIES = [
  {
    id: 'cartes', name: 'Cartes', desc: 'Plis, levées et coups de bluff', accent: '#d9675c',
    games: [
      { id: 'president', name: 'Le Président', sub: '4 joueurs · 52 cartes' },
      { id: 'tarot', name: 'Le Tarot', sub: '4 joueurs · 78 cartes' },
    ],
  },
  {
    id: 'plateau', name: 'Jeux de plateau', desc: 'Stratégie face à face', accent: GOLD,
    games: [
      { id: 'puissance4', name: 'Puissance 4', sub: 'Alignez quatre jetons' },
      { id: 'reversi', name: 'Reversi', sub: 'Encerclez et retournez' },
      { id: 'abalone', name: 'Abalone', sub: 'Poussez les billes dehors' },
      { id: 'awale', name: 'Awalé', sub: 'Semez, récoltez' },
    ],
  },
  {
    id: 'des', name: 'Dés', desc: 'Le hasard et les nerfs', accent: '#6aa3d8',
    games: [
      { id: '421', name: 'Le 421', sub: 'Trois dés, une combinaison' },
      { id: '10000', name: 'Le 10 000', sub: 'Cumulez sans tout perdre' },
    ],
  },
];

export class Lobby {
  constructor(app) {
    this.app = app;
    this.group = new THREE.Group();
    this.group.name = 'accueil';
    this.interactables = [];
    this.buttons = [];
    this.showcases = [];
    this.spawn = { position: new THREE.Vector3(0, 0, 0), yaw: 0, pitch: 0.05 };
    this.buildTitle();
    const R = 2.05, step = 0.6;
    CATEGORIES.forEach((cat, i) => this.buildCategory(cat, (i - 1) * step, R));
    app.scene.add(this.group);
  }

  buildTitle() {
    const p = new CanvasPlane(2.3, 0.52, 700);
    const g = p.ctx, W = p.canvas.width, H = p.canvas.height;
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    const grad = g.createLinearGradient(0, H * 0.15, 0, H * 0.6);
    grad.addColorStop(0, '#fbe7a9');
    grad.addColorStop(0.5, '#d8b25a');
    grad.addColorStop(1, '#9c7432');
    g.shadowColor = 'rgba(255,200,110,0.55)';
    g.shadowBlur = 24;
    g.fillStyle = grad;
    fitFont(g, 'Salon des Jeux', 700, FONT_TITLE, 150, W * 0.9);
    g.fillText('Salon des Jeux', W / 2, H * 0.4);
    g.shadowBlur = 0;
    g.strokeStyle = hexA(GOLD, 0.7);
    g.lineWidth = 3;
    const y = H * 0.76;
    [[W * 0.14, W * 0.36], [W * 0.64, W * 0.86]].forEach(([a, b]) => {
      g.beginPath(); g.moveTo(a, y); g.lineTo(b, y); g.stroke();
    });
    g.fillStyle = 'rgba(240,226,196,0.85)';
    g.font = `italic 400 44px ${FONT_BODY}`;
    g.fillText('Choisissez votre table', W / 2, y);
    p.refresh();
    p.mesh.position.set(0, 2.95, -2.45);
    p.mesh.lookAt(0, 1.6, 0);
    this.group.add(p.mesh);
  }

  buildCategory(cat, angle, R) {
    const holder = new THREE.Group();
    const PW = 0.96, PH = 0.62 + cat.games.length * 0.19;
    holder.position.set(Math.sin(angle) * R, 2.06 - PH / 2, -Math.cos(angle) * R);
    holder.lookAt(0, 1.5, 0);
    const bg = new CanvasPlane(PW, PH, 640);
    this.drawPanel(bg, cat);
    bg.mesh.renderOrder = 1;
    holder.add(bg.mesh);

    const top = PH / 2 - 0.47;
    cat.games.forEach((game, k) => {
      const available = !!this.app.games[game.id];
      const b = new Button3D({
        width: 0.84, height: 0.165, label: game.name, sub: game.sub,
        badge: available ? 'Jouer' : 'Bientôt', accent: cat.accent, enabled: available,
        sound: this.app.sound, onSelect: () => this.app.openGame(game.id),
      });
      b.place(0, top - k * 0.19, 0.012);
      holder.add(b.mesh);
      this.buttons.push(b);
      this.interactables.push(b.entry);
    });

    const show = this.makeShowcase(cat.id);
    show.position.set(0, PH / 2 + 0.24, 0.05);
    show.userData.baseY = show.position.y;
    holder.add(show);
    this.showcases.push(show);
    this.group.add(holder);
  }

  drawPanel(p, cat) {
    const g = p.ctx, W = p.canvas.width, H = p.canvas.height;
    const pad = 10;
    roundRect(g, pad, pad, W - 2 * pad, H - 2 * pad, 34);
    const grad = g.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, 'rgba(24,20,22,0.88)');
    grad.addColorStop(1, 'rgba(10,9,11,0.82)');
    g.fillStyle = grad;
    g.fill();
    g.lineWidth = 4;
    g.strokeStyle = hexA(cat.accent, 0.8);
    g.stroke();
    roundRect(g, pad + 12, pad + 12, W - 2 * pad - 24, H - 2 * pad - 24, 26);
    g.lineWidth = 1.5;
    g.strokeStyle = hexA(cat.accent, 0.3);
    g.stroke();

    // Icône
    const cx = W / 2, cy = 78;
    g.fillStyle = cat.accent;
    g.strokeStyle = cat.accent;
    if (cat.id === 'cartes') {
      g.font = '50px sans-serif';
      g.textAlign = 'center'; g.textBaseline = 'middle';
      ['♠', '♥', '♦', '♣'].forEach((s, i) => g.fillText(s, cx + (i - 1.5) * 52, cy));
    } else if (cat.id === 'plateau') {
      for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
        g.globalAlpha = (i + j) % 2 ? 0.35 : 0.9;
        g.beginPath(); g.arc(cx + (i - 1.5) * 28, cy + (j - 1.5) * 18, 9, 0, Math.PI * 2); g.fill();
      }
      g.globalAlpha = 1;
    } else {
      [[-34, -6, -0.2], [34, 4, 0.25]].forEach(([dx, dy, rot]) => {
        g.save(); g.translate(cx + dx, cy + dy); g.rotate(rot);
        g.lineWidth = 4; roundRect(g, -24, -24, 48, 48, 9); g.stroke();
        g.beginPath(); g.arc(-10, -10, 5, 0, 7); g.arc(10, 10, 5, 0, 7); g.fill();
        g.beginPath(); g.arc(10, -10, 5, 0, 7); g.fill();
        g.restore();
      });
    }

    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillStyle = '#f6ead0';
    fitFont(g, cat.name, 700, FONT_TITLE, 60, W - 80);
    g.fillText(cat.name, cx, 160);
    g.fillStyle = 'rgba(232,214,178,0.7)';
    g.font = `italic 400 28px ${FONT_BODY}`;
    g.fillText(cat.desc, cx, 210);
    g.strokeStyle = hexA(cat.accent, 0.5);
    g.lineWidth = 2;
    g.beginPath(); g.moveTo(90, 245); g.lineTo(W - 90, 245); g.stroke();
    g.fillStyle = cat.accent;
    g.beginPath(); g.moveTo(cx, 237); g.lineTo(cx + 8, 245); g.lineTo(cx, 253); g.lineTo(cx - 8, 245); g.fill();
    p.refresh();
  }

  makeShowcase(id) {
    const g = new THREE.Group();
    if (id === 'cartes') {
      const back = new THREE.MeshStandardMaterial({ map: texture(cardBackCanvas()), roughness: 0.5 });
      [['A', '♥'], ['R', '♠'], ['D', '♦']].forEach(([rank, suit], i) => {
        const pivot = new THREE.Group();
        pivot.rotation.z = (1 - i) * 0.32;
        pivot.position.set((i - 1) * 0.02, -0.07, i * 0.004);
        const face = new THREE.Mesh(new THREE.PlaneGeometry(0.1, 0.145),
          new THREE.MeshStandardMaterial({ map: texture(cardFaceCanvas(rank, suit)), roughness: 0.5 }));
        face.position.y = 0.075;
        const rear = new THREE.Mesh(new THREE.PlaneGeometry(0.1, 0.145), back);
        rear.rotation.y = Math.PI;
        rear.position.y = 0.075;
        pivot.add(face, rear);
        g.add(pivot);
      });
    } else if (id === 'plateau') {
      const geo = tokenGeometry(0.045, 0.018);
      const red = new THREE.Mesh(geo, tokenMaterial(TOKEN_COLORS[1]));
      red.position.set(-0.035, 0, 0);
      red.rotation.y = 0.3;
      const yellow = new THREE.Mesh(geo, tokenMaterial(TOKEN_COLORS[2]));
      yellow.position.set(0.035, 0.01, -0.02);
      yellow.rotation.y = -0.3;
      g.add(red, yellow);
    } else {
      const d1 = makeDie(0.065);
      d1.position.set(-0.045, 0, 0);
      d1.rotation.set(0.5, 0.6, 0.2);
      const d2 = makeDie(0.065);
      d2.position.set(0.045, 0.02, 0);
      d2.rotation.set(-0.3, 1.2, 0.5);
      g.add(d1, d2);
    }
    return g;
  }

  enter() { this.group.visible = true; }
  exit() { this.group.visible = false; }

  update(dt, t) {
    this.buttons.forEach((b) => b.update(dt));
    this.showcases.forEach((s, i) => {
      s.rotation.y += dt * 0.6;
      s.position.y = s.userData.baseY + Math.sin(t * 1.4 + i * 2) * 0.02;
    });
  }
}
