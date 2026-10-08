import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { Button3D, CanvasPlane, roundRect, hexA, fitFont, FONT_TITLE, FONT_BODY, GOLD } from '../ui.js';
import { tokenGeometry, tokenMaterial, TOKEN_COLORS } from '../pieces.js';
import { Confetti } from '../effects.js';
import { TABLE_POS } from '../environment.js';

const COLS = 7, ROWS = 6;
const CELL = 0.075, HOLE = 0.029, TOKEN_R = 0.0325, TOKEN_T = 0.013;
const GAP = 0.017, PLATE = 0.007, BEVEL = 0.0015, MARGIN = 0.032, FEET = 0.035;
const BOARD_W = COLS * CELL + 2 * MARGIN;
const BOARD_H = ROWS * CELL + 2 * MARGIN;
const Y0 = FEET + MARGIN + CELL / 2;
const TOP = FEET + BOARD_H;
const DROP_Y = TOP + 0.06;
const GRAVITY = 6.5;

const LEVELS = [
  { name: 'Facile', depth: 2, randomness: 0.4 },
  { name: 'Moyen', depth: 4, randomness: 0.05 },
  { name: 'Difficile', depth: 7, randomness: 0 },
];
const NAMES = { 1: 'Rouge', 2: 'Jaune' };
const CSS = { 1: '#e2333a', 2: '#f6c623' };

const colX = (c) => (c - (COLS - 1) / 2) * CELL;
const rowY = (r) => Y0 + r * CELL;
const ease = (k) => k * k * (3 - 2 * k);

export class Puissance4 {
  constructor(app) {
    this.app = app;
    this.group = new THREE.Group();
    this.group.name = 'puissance4';
    this.group.position.copy(TABLE_POS);
    this.group.visible = false;
    app.scene.add(this.group);
    this.group.updateMatrixWorld(true);

    this.spawn = { position: new THREE.Vector3(TABLE_POS.x, 0, TABLE_POS.z + 0.78), yaw: 0, pitch: -0.55 };
    this.eye = new THREE.Vector3(TABLE_POS.x, 1.5, TABLE_POS.z + 0.78);
    this.interactables = [];
    this.buttons = [];
    this.anims = [];
    this.tokenGeo = tokenGeometry(TOKEN_R, TOKEN_T);
    this.baseMat = { 1: tokenMaterial(TOKEN_COLORS[1]), 2: tokenMaterial(TOKEN_COLORS[2]) };

    this.mode = 'ia';
    this.level = 1;
    this.scores = { 1: 0, 2: 0 };
    this.starter = 1;
    this.gameId = 0;
    this.started = false;
    this.hoverCol = null;

    this.buildBoard();
    this.buildGhosts();
    this.buildUI();
    this.confetti = new Confetti(this.group);

    this.worker = new Worker(new URL('./puissance4-ia.js', import.meta.url));
    this.worker.onmessage = (e) => this.onAI(e.data);
  }

  // ---------------------------------------------------------------- construction
  buildBoard() {
    const board = new THREE.Group();
    board.position.set(0, 0, -0.06);
    this.board = board;
    const mat = new THREE.MeshPhysicalMaterial({ color: 0x1846c9, roughness: 0.28, clearcoat: 0.9, clearcoatRoughness: 0.12 });

    const x0 = -BOARD_W / 2, x1 = BOARD_W / 2, y0 = FEET, y1 = FEET + BOARD_H, rc = 0.02;
    const shape = new THREE.Shape();
    shape.moveTo(x0 + rc, y0);
    shape.lineTo(x1 - rc, y0);
    shape.quadraticCurveTo(x1, y0, x1, y0 + rc);
    shape.lineTo(x1, y1 - rc);
    shape.quadraticCurveTo(x1, y1, x1 - rc, y1);
    shape.lineTo(x0 + rc, y1);
    shape.quadraticCurveTo(x0, y1, x0, y1 - rc);
    shape.lineTo(x0, y0 + rc);
    shape.quadraticCurveTo(x0, y0, x0 + rc, y0);
    for (let c = 0; c < COLS; c++) for (let r = 0; r < ROWS; r++) {
      const hole = new THREE.Path();
      hole.absarc(colX(c), rowY(r), HOLE, 0, Math.PI * 2, true);
      shape.holes.push(hole);
    }
    const plateGeo = new THREE.ExtrudeGeometry(shape, {
      depth: PLATE, bevelEnabled: true, bevelThickness: BEVEL, bevelSize: BEVEL, bevelSegments: 2, curveSegments: 20,
    });
    const front = new THREE.Mesh(plateGeo, mat);
    front.position.z = GAP / 2 + BEVEL;
    const back = new THREE.Mesh(plateGeo, mat);
    back.position.z = -GAP / 2 - PLATE - BEVEL;
    board.add(front, back);

    const rail = (w, h, x, y) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, GAP), mat);
      m.position.set(x, y, 0);
      board.add(m);
    };
    const railW = MARGIN * 0.6;
    rail(railW, BOARD_H, -BOARD_W / 2 + railW / 2, FEET + BOARD_H / 2);
    rail(railW, BOARD_H, BOARD_W / 2 - railW / 2, FEET + BOARD_H / 2);
    const barH = Y0 - TOKEN_R - FEET;
    rail(BOARD_W, barH, 0, FEET + barH / 2);

    const footMat = new THREE.MeshPhysicalMaterial({ color: 0x1238a3, roughness: 0.35, clearcoat: 0.6 });
    [-1, 1].forEach((s) => {
      const foot = new THREE.Mesh(new RoundedBoxGeometry(0.035, 0.16, 0.22, 3, 0.012), footMat);
      foot.position.set(s * (BOARD_W / 2 + 0.016), 0.08, 0);
      board.add(foot);
    });
    board.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });

    // Zones de visée invisibles, une par colonne
    const hitMat = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false, colorWrite: false });
    const hitGeo = new THREE.BoxGeometry(CELL, BOARD_H + 0.14, 0.09);
    for (let c = 0; c < COLS; c++) {
      const hit = new THREE.Mesh(hitGeo, hitMat);
      hit.position.set(colX(c), FEET + (BOARD_H + 0.14) / 2, 0);
      board.add(hit);
      this.interactables.push({
        object: hit,
        onHover: (on) => this.setHoverCol(on ? c : (this.hoverCol === c ? null : this.hoverCol)),
        onSelect: () => this.humanPlay(c),
      });
    }
    this.group.add(board);
  }

  buildGhosts() {
    this.ghostMat = new THREE.MeshPhysicalMaterial({ color: TOKEN_COLORS[1], transparent: true, opacity: 0.55, roughness: 0.3, clearcoat: 0.5, depthWrite: false });
    this.landMat = new THREE.MeshBasicMaterial({ color: TOKEN_COLORS[1], transparent: true, opacity: 0.22, depthWrite: false });
    this.ghost = new THREE.Mesh(this.tokenGeo, this.ghostMat);
    this.landing = new THREE.Mesh(this.tokenGeo, this.landMat);
    this.ghost.visible = this.landing.visible = false;
    this.board.add(this.ghost, this.landing);
  }

  buildUI() {
    const sound = this.app.sound;

    // Bandeau d'état au-dessus du plateau
    this.status = new CanvasPlane(0.7, 0.11, 1300);
    this.status.mesh.position.set(0, TOP + 0.16, -0.08);
    this.group.add(this.status.mesh);
    this.status.mesh.lookAt(this.eye);

    // Tableau des scores à gauche
    this.scorePanel = new CanvasPlane(0.3, 0.2, 1300);
    this.scorePanel.mesh.position.set(-0.6, 0.42, 0.1);
    this.group.add(this.scorePanel.mesh);
    this.scorePanel.mesh.lookAt(this.eye);

    // Commandes à droite
    const holder = new THREE.Group();
    holder.position.set(0.6, 0.4, 0.1);
    this.group.add(holder);
    holder.lookAt(this.eye);
    const mk = (y, label, onSelect, accent = GOLD) => {
      const b = new Button3D({ width: 0.3, height: 0.072, label, align: 'center', accent, sound, onSelect, ppm: 1500 });
      b.place(0, y, 0);
      holder.add(b.mesh);
      this.buttons.push(b);
      this.interactables.push(b.entry);
      return b;
    };
    this.btnNew = mk(0.135, 'Nouvelle partie', () => this.newGame());
    this.btnMode = mk(0.045, '', () => this.toggleMode());
    this.btnLevel = mk(-0.045, '', () => this.cycleLevel());
    this.btnBack = mk(-0.135, 'Retour au salon', () => this.app.goLobby(), '#9fb4c8');
    this.refreshButtons();
  }

  refreshButtons() {
    this.btnMode.set({ label: this.mode === 'ia' ? 'Contre l’ordinateur' : 'À deux joueurs' });
    this.btnLevel.set({
      label: `Niveau : ${LEVELS[this.level].name}`,
      enabled: this.mode === 'ia',
    });
  }

  // ---------------------------------------------------------------- affichages
  drawStatus(text, color = null, sub = '') {
    const p = this.status, g = p.ctx, W = p.canvas.width, H = p.canvas.height;
    g.clearRect(0, 0, W, H);
    roundRect(g, 6, 6, W - 12, H - 12, H * 0.3);
    g.fillStyle = 'rgba(14,12,16,0.85)';
    g.fill();
    g.strokeStyle = hexA(GOLD, 0.6);
    g.lineWidth = 3;
    g.stroke();
    let x = W / 2;
    g.textBaseline = 'middle';
    g.textAlign = 'center';
    g.fillStyle = '#f6ead0';
    fitFont(g, text, 800, FONT_BODY, Math.round(H * (sub ? 0.36 : 0.42)), W * 0.78);
    const tw = g.measureText(text).width;
    if (color) {
      x += H * 0.22;
      const dx = W / 2 - tw / 2 - H * 0.2;
      g.fillStyle = color;
      g.beginPath(); g.arc(dx, sub ? H * 0.4 : H / 2, H * 0.15, 0, Math.PI * 2); g.fill();
      g.strokeStyle = 'rgba(255,255,255,0.4)';
      g.lineWidth = 2;
      g.stroke();
      g.fillStyle = '#f6ead0';
    }
    g.fillText(text, x, sub ? H * 0.4 : H / 2);
    if (sub) {
      g.fillStyle = 'rgba(232,214,178,0.7)';
      g.font = `400 ${Math.round(H * 0.2)}px ${FONT_BODY}`;
      g.fillText(sub, W / 2, H * 0.74);
    }
    p.refresh();
  }

  drawScores() {
    const p = this.scorePanel, g = p.ctx, W = p.canvas.width, H = p.canvas.height;
    g.clearRect(0, 0, W, H);
    roundRect(g, 6, 6, W - 12, H - 12, 30);
    g.fillStyle = 'rgba(14,12,16,0.85)';
    g.fill();
    g.strokeStyle = hexA(GOLD, 0.6);
    g.lineWidth = 3;
    g.stroke();
    g.textBaseline = 'middle';
    g.fillStyle = GOLD;
    g.textAlign = 'center';
    g.font = `700 ${Math.round(H * 0.13)}px ${FONT_TITLE}`;
    g.fillText('Score', W / 2, H * 0.17);
    const names = this.mode === 'ia' ? { 1: 'Vous', 2: 'Ordinateur' } : NAMES;
    [1, 2].forEach((pl, i) => {
      const y = H * (0.45 + i * 0.3);
      g.fillStyle = CSS[pl];
      g.beginPath(); g.arc(W * 0.14, y, H * 0.07, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#f6ead0';
      g.textAlign = 'left';
      g.font = `700 ${Math.round(H * 0.13)}px ${FONT_BODY}`;
      g.fillText(names[pl], W * 0.24, y);
      g.textAlign = 'right';
      g.font = `800 ${Math.round(H * 0.16)}px ${FONT_BODY}`;
      g.fillText(String(this.scores[pl]), W * 0.88, y);
    });
    p.refresh();
  }

  updateStatus() {
    if (this.over) return;
    const p = this.current;
    if (this.mode === 'ia') {
      if (p === 1) this.drawStatus('À vous de jouer', CSS[1], 'Visez une colonne et appuyez sur la gâchette');
      else this.drawStatus('L’ordinateur réfléchit…', CSS[2]);
    } else {
      this.drawStatus(`Au tour de ${NAMES[p]}`, CSS[p]);
    }
  }

  // ---------------------------------------------------------------- piles de jetons
  pilePosition(player, i) {
    const side = player === 1 ? -1 : 1;
    const stack = Math.floor(i / 7), k = i % 7;
    const off = [[0, 0], [0.072, 0.02], [0.036, -0.045]][stack];
    return new THREE.Vector3(side * (0.4 + off[0]), 0.003 + TOKEN_T / 2 + k * (TOKEN_T + 0.0004), 0.1 + off[1]);
  }

  buildPiles() {
    this.piles = { 1: [], 2: [] };
    for (const pl of [1, 2]) {
      for (let i = 0; i < 21; i++) {
        const m = new THREE.Mesh(this.tokenGeo, this.baseMat[pl]);
        m.position.copy(this.pilePosition(pl, i));
        m.rotation.set(-Math.PI / 2, 0, Math.random() * 6);
        m.castShadow = true;
        m.receiveShadow = true;
        m.scale.setScalar(0.001);
        this.group.add(m);
        this.piles[pl].push(m);
        this.anims.push({ t: -i * 0.015, dur: 0.25, mesh: m, kind: 'grow' });
      }
    }
  }

  // ---------------------------------------------------------------- déroulement
  newGame() {
    this.gameId++;
    this.thinking = false;
    const old = [];
    if (this.cells) this.cells.flat().forEach((m) => m && old.push(m));
    if (this.piles) [1, 2].forEach((pl) => this.piles[pl].forEach((m) => old.push(m)));
    this.anims = this.anims.filter((a) => a.kind === 'out');
    old.forEach((m, i) => this.anims.push({ t: -i * 0.008, dur: 0.35, mesh: m, kind: 'out', y: m.position.y }));
    if (old.length) this.app.sound.whoosh();

    this.grid = Array.from({ length: COLS }, () => new Array(ROWS).fill(0));
    this.cells = Array.from({ length: COLS }, () => new Array(ROWS).fill(null));
    this.moves = 0;
    this.winLine = null;
    this.over = false;
    this.busy = false;
    this.current = this.starter;
    this.starter = 3 - this.starter;
    this.buildPiles();
    this.drawScores();
    this.updateStatus();
    this.refreshGhost();
    if (this.isAITurn()) this.askAI();
  }

  isAITurn() { return this.mode === 'ia' && this.current === 2 && !this.over; }

  toggleMode() {
    this.mode = this.mode === 'ia' ? 'duo' : 'ia';
    this.scores = { 1: 0, 2: 0 };
    this.starter = 1;
    this.refreshButtons();
    this.newGame();
  }

  cycleLevel() {
    this.level = (this.level + 1) % LEVELS.length;
    this.refreshButtons();
    if (this.moves === 0 || this.over) this.newGame();
  }

  lowest(c) {
    for (let r = 0; r < ROWS; r++) if (!this.grid[c][r]) return r;
    return -1;
  }

  humanPlay(c) {
    if (this.busy || this.over || this.isAITurn()) return;
    if (this.lowest(c) < 0) { this.app.sound.deny(); return; }
    this.play(c);
  }

  play(c) {
    const r = this.lowest(c);
    if (r < 0) return;
    const pl = this.current;
    this.grid[c][r] = pl;
    this.moves++;
    this.busy = true;
    this.refreshGhost();

    let mesh = this.piles[pl].pop();
    if (!mesh) {
      mesh = new THREE.Mesh(this.tokenGeo, this.baseMat[pl]);
      mesh.position.copy(this.pilePosition(pl, 0));
      this.group.add(mesh);
    }
    mesh.material = this.baseMat[pl].clone();
    mesh.castShadow = true;
    this.board.attach(mesh);
    this.cells[c][r] = mesh;
    this.anims.push({
      kind: 'fly', t: 0, dur: 0.42, mesh, c, r, pl, gid: this.gameId,
      from: mesh.position.clone(), fromQ: mesh.quaternion.clone(),
      to: new THREE.Vector3(colX(c), DROP_Y, 0),
    });
    this.app.sound.whoosh();
  }

  landed(a) {
    if (a.gid !== this.gameId) return;
    const win = this.findWin(a.c, a.r, a.pl);
    if (win) return this.finish(a.pl, win);
    if (this.moves >= COLS * ROWS) return this.finish(0, null);
    this.current = 3 - this.current;
    this.busy = false;
    this.updateStatus();
    this.refreshGhost();
    if (this.isAITurn()) this.askAI();
  }

  findWin(c, r, p) {
    const at = (cc, rr) => (cc >= 0 && cc < COLS && rr >= 0 && rr < ROWS ? this.grid[cc][rr] : -1);
    for (const [dc, dr] of [[1, 0], [0, 1], [1, 1], [1, -1]]) {
      const line = [[c, r]];
      for (let k = 1; at(c + dc * k, r + dr * k) === p; k++) line.push([c + dc * k, r + dr * k]);
      for (let k = 1; at(c - dc * k, r - dr * k) === p; k++) line.unshift([c - dc * k, r - dr * k]);
      if (line.length >= 4) return line;
    }
    return null;
  }

  finish(winner, line) {
    this.over = true;
    this.busy = false;
    this.refreshGhost();
    const snd = this.app.sound;
    if (!winner) {
      this.drawStatus('Match nul !', null, 'Le plateau est plein');
      snd.draw();
      return;
    }
    this.scores[winner]++;
    this.drawScores();
    this.winLine = line.map(([c, r]) => this.cells[c][r]);
    this.winT = 0;
    const humanLost = this.mode === 'ia' && winner === 2;
    if (this.mode === 'ia') {
      this.drawStatus(humanLost ? 'L’ordinateur gagne' : 'Vous avez gagné !', CSS[winner], 'Appuyez sur « Nouvelle partie » pour rejouer');
    } else {
      this.drawStatus(`${NAMES[winner]} gagne !`, CSS[winner], 'Appuyez sur « Nouvelle partie » pour rejouer');
    }
    if (humanLost) snd.lose();
    else {
      snd.win();
      const mid = new THREE.Vector3();
      this.winLine.forEach((m) => mid.add(m.position));
      mid.multiplyScalar(1 / this.winLine.length).add(this.board.position);
      this.confetti.burst(mid);
    }
  }

  askAI() {
    this.thinking = true;
    this.aiAsked = performance.now();
    const flat = [];
    for (let c = 0; c < COLS; c++) for (let r = 0; r < ROWS; r++) flat.push(this.grid[c][r]);
    const lv = LEVELS[this.level];
    this.worker.postMessage({ id: this.gameId, board: flat, player: 2, depth: lv.depth, randomness: lv.randomness });
    this.updateStatus();
  }

  onAI({ id, col }) {
    if (id !== this.gameId || !this.thinking) return;
    const wait = Math.max(0, 650 - (performance.now() - this.aiAsked));
    setTimeout(() => {
      if (id !== this.gameId || !this.thinking) return;
      this.thinking = false;
      this.play(col);
    }, wait);
  }

  // ---------------------------------------------------------------- survol
  setHoverCol(c) {
    this.hoverCol = c;
    this.refreshGhost();
  }

  refreshGhost() {
    const c = this.hoverCol;
    const ok = c !== null && !this.busy && !this.over && !this.isAITurn() && this.lowest(c) >= 0;
    this.ghost.visible = this.landing.visible = ok;
    if (!ok) return;
    const col = TOKEN_COLORS[this.current];
    this.ghostMat.color.setHex(col);
    this.landMat.color.setHex(col);
    this.ghost.position.set(colX(c), DROP_Y, 0);
    this.landing.position.set(colX(c), rowY(this.lowest(c)), 0);
  }

  // ---------------------------------------------------------------- cycle de vie
  enter() {
    this.group.visible = true;
    if (!this.started) {
      this.started = true;
      this.newGame();
    } else if (this.isAITurn() && !this.thinking && !this.busy) {
      this.askAI();
    }
  }

  exit() {
    this.group.visible = false;
    if (this.thinking) { this.thinking = false; this.gameId++; }
    this.setHoverCol(null);
  }

  update(dt, t) {
    this.buttons.forEach((b) => b.update(dt));
    this.confetti.update(dt);
    if (this.ghost.visible) this.ghost.position.y = DROP_Y + Math.sin(t * 4) * 0.006;

    const keep = [];
    for (const a of this.anims) {
      a.t += dt;
      if (a.t < 0) { keep.push(a); continue; }
      const k = Math.min(1, a.t / (a.dur || 1));
      const m = a.mesh;
      if (a.kind === 'grow') {
        m.scale.setScalar(Math.max(0.001, ease(k)));
        if (k < 1) keep.push(a);
      } else if (a.kind === 'out') {
        m.position.y = a.y - ease(k) * 0.1;
        m.scale.setScalar(Math.max(0.001, 1 - ease(k)));
        if (k < 1) keep.push(a);
        else { m.parent?.remove(m); if (m.material !== this.baseMat[1] && m.material !== this.baseMat[2]) m.material.dispose(); }
      } else if (a.kind === 'fly') {
        const e = ease(k);
        m.position.lerpVectors(a.from, a.to, e);
        m.position.y += Math.sin(Math.PI * k) * 0.12;
        m.quaternion.slerpQuaternions(a.fromQ, new THREE.Quaternion(), e);
        if (k < 1) keep.push(a);
        else {
          a.kind = 'drop';
          a.v = 0;
          a.bounces = 0;
          m.quaternion.identity();
          keep.push(a);
        }
      } else if (a.kind === 'drop') {
        a.v -= GRAVITY * dt;
        m.position.y += a.v * dt;
        const target = rowY(a.r);
        if (m.position.y <= target) {
          m.position.y = target;
          const speed = -a.v;
          if (a.bounces === 0) this.app.sound.clack(0.4 + speed * 0.4);
          if (speed > 0.35 && a.bounces < 2) {
            a.v = speed * 0.28;
            a.bounces++;
            keep.push(a);
          } else {
            this.landed(a);
          }
        } else keep.push(a);
      }
    }
    this.anims = keep;

    if (this.over && this.winLine) {
      this.winT += dt;
      const glow = 0.35 + Math.sin(this.winT * 6) * 0.3;
      this.winLine.forEach((m) => {
        m.material.emissive.setHex(0xffd27a);
        m.material.emissiveIntensity = Math.max(0, glow);
      });
    }
  }
}
