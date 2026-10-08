import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import {
  texture, rng, parquetCanvas, darkWoodCanvas, wallpaperCanvas, feltCanvas, rugCanvas,
  nightSkyCanvas, paintingCanvas, flameCanvas, glowCanvas,
} from './textures.js';

// Pièce : x de -6 à 6, z de -6 à 7, hauteur 4,2 m.
const X0 = -6, X1 = 6, Z0 = -6, Z1 = 7, H = 4.2;
export const TABLE_POS = new THREE.Vector3(0, 0.76, 3.6);

export function buildEnvironment(scene) {
  const room = new THREE.Group();
  room.name = 'salon';
  const updaters = [];

  const darkWoodTex = texture(darkWoodCanvas(11, 18), 1, 1);
  const midWoodTex = texture(darkWoodCanvas(12, 26), 1, 1);
  const woodMat = new THREE.MeshStandardMaterial({ map: darkWoodTex, roughness: 0.45, metalness: 0.0 });
  const midWoodMat = new THREE.MeshStandardMaterial({ map: midWoodTex, roughness: 0.5 });
  const brassMat = new THREE.MeshStandardMaterial({ color: 0xc89b55, metalness: 1, roughness: 0.32 });
  const glowTex = texture(glowCanvas(), 1, 1);

  // ---------- Sol ----------
  const W = X1 - X0, D = Z1 - Z0;
  const floorTex = texture(parquetCanvas(), W / 1.3, D / 1.3);
  const floor = new THREE.Mesh(
    new THREE.PlaneGeometry(W, D),
    new THREE.MeshStandardMaterial({ map: floorTex, roughness: 0.42, metalness: 0.0 })
  );
  floor.rotation.x = -Math.PI / 2;
  floor.position.set((X0 + X1) / 2, 0, (Z0 + Z1) / 2);
  floor.receiveShadow = true;
  room.add(floor);

  // ---------- Plafond ----------
  const ceil = new THREE.Mesh(new THREE.PlaneGeometry(W, D), new THREE.MeshStandardMaterial({ color: 0x241a14, roughness: 0.9 }));
  ceil.rotation.x = Math.PI / 2;
  ceil.position.set((X0 + X1) / 2, H, (Z0 + Z1) / 2);
  room.add(ceil);
  for (let x = X0 + 2; x < X1; x += 2) {
    const beam = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.26, D), woodMat);
    beam.position.set(x, H - 0.13, (Z0 + Z1) / 2);
    room.add(beam);
  }

  // ---------- Murs ----------
  const wallpaperTex = texture(wallpaperCanvas(), 1, (H - 1.05) / 0.9);
  const wainscotTex = texture(darkWoodCanvas(13, 22), 1, 1);
  function wall(width, x, z, rotY) {
    const g = new THREE.Group();
    g.position.set(x, 0, z);
    g.rotation.y = rotY;
    const wpTex = wallpaperTex.clone();
    wpTex.repeat.set(width / 0.9, (H - 1.05) / 0.9);
    wpTex.needsUpdate = true;
    const paper = new THREE.Mesh(new THREE.PlaneGeometry(width, H - 1.05),
      new THREE.MeshStandardMaterial({ map: wpTex, roughness: 0.85 }));
    paper.position.y = 1.05 + (H - 1.05) / 2;
    g.add(paper);
    const wsTex = wainscotTex.clone();
    wsTex.repeat.set(width / 2, 1);
    wsTex.needsUpdate = true;
    const wains = new THREE.Mesh(new THREE.PlaneGeometry(width, 1.05),
      new THREE.MeshStandardMaterial({ map: wsTex, roughness: 0.5 }));
    wains.position.y = 0.525;
    g.add(wains);
    for (let px = -width / 2 + 0.6; px < width / 2 - 0.3; px += 1.2) {
      const panel = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.62, 0.02), midWoodMat);
      panel.position.set(px + 0.3, 0.55, 0.01);
      g.add(panel);
    }
    const rail = new THREE.Mesh(new THREE.BoxGeometry(width, 0.06, 0.05), woodMat);
    rail.position.set(0, 1.05, 0.025);
    g.add(rail);
    const base = new THREE.Mesh(new THREE.BoxGeometry(width, 0.16, 0.035), woodMat);
    base.position.set(0, 0.08, 0.017);
    g.add(base);
    const crown = new THREE.Mesh(new THREE.BoxGeometry(width, 0.14, 0.08), woodMat);
    crown.position.set(0, H - 0.07, 0.04);
    g.add(crown);
    room.add(g);
    return g;
  }
  const backWall = wall(W, 0, Z0, 0);
  const frontWall = wall(W, 0, Z1, Math.PI);
  wall(D, X0, (Z0 + Z1) / 2, Math.PI / 2);
  wall(D, X1, (Z0 + Z1) / 2, -Math.PI / 2);

  // ---------- Fenêtres sur la nuit (mur du fond) ----------
  const skyTex = texture(nightSkyCanvas(), 1, 1);
  const curtainMat = new THREE.MeshStandardMaterial({ color: 0x6a1220, roughness: 0.85, side: THREE.DoubleSide });
  function curtain(w, h) {
    const geo = new THREE.PlaneGeometry(w, h, 40, 1);
    const p = geo.attributes.position;
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i);
      p.setZ(i, Math.sin(x / w * Math.PI * 9) * 0.035 + 0.06);
    }
    geo.computeVertexNormals();
    return new THREE.Mesh(geo, curtainMat);
  }
  [-3.4, 3.4].forEach((wx) => {
    const win = new THREE.Group();
    win.position.set(wx, 0, 0.01);
    const sky = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 2.1), new THREE.MeshBasicMaterial({ map: skyTex, toneMapped: false, color: 0xbbbbcc }));
    sky.position.set(0, 2.25, 0);
    win.add(sky);
    const fr = (w, h, x, y) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.09), woodMat);
      m.position.set(x, y, 0.04);
      win.add(m);
    };
    fr(1.56, 0.1, 0, 3.33); fr(1.56, 0.12, 0, 1.17); fr(0.1, 2.26, -0.75, 2.25); fr(0.1, 2.26, 0.75, 2.25);
    fr(0.04, 2.1, 0, 2.25); fr(1.4, 0.04, 0, 2.6); fr(1.4, 0.04, 0, 1.9);
    const sill = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.05, 0.25), woodMat);
    sill.position.set(0, 1.12, 0.12);
    win.add(sill);
    const rod = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.018, 2.4, 12), brassMat);
    rod.rotation.z = Math.PI / 2;
    rod.position.set(0, 3.55, 0.14);
    win.add(rod);
    [-1, 1].forEach((s) => {
      const c = curtain(0.55, 3.5);
      c.position.set(s * 0.98, 1.8, 0.02);
      win.add(c);
    });
    backWall.add(win);
    const moonLight = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 2.3),
      new THREE.MeshBasicMaterial({ map: glowTex, color: 0x5a6aa8, transparent: true, opacity: 0.18, depthWrite: false, blending: THREE.AdditiveBlending }));
    moonLight.position.set(wx, 2.25, Z0 + 0.12);
    room.add(moonLight);
  });

  // ---------- Appliques murales ----------
  const bulbMat = new THREE.MeshBasicMaterial({ color: 0xffd9a0, toneMapped: false });
  function sconce(parent, x, y) {
    const s = new THREE.Group();
    s.position.set(x, y, 0);
    const plate = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.02, 20), brassMat);
    plate.rotation.x = Math.PI / 2;
    plate.position.z = 0.01;
    s.add(plate);
    const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.2, 8), brassMat);
    arm.rotation.x = Math.PI / 2;
    arm.position.set(0, 0, 0.1);
    s.add(arm);
    const cup = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.025, 0.05, 16), brassMat);
    cup.position.set(0, 0.02, 0.2);
    s.add(cup);
    const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.03, 16, 12), bulbMat);
    bulb.position.set(0, 0.07, 0.2);
    s.add(bulb);
    const shade = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.1, 0.13, 20, 1, true),
      new THREE.MeshStandardMaterial({ color: 0xf2dcb4, emissive: 0xffb860, emissiveIntensity: 0.8, roughness: 0.9, side: THREE.DoubleSide, transparent: true, opacity: 0.92 }));
    shade.position.set(0, 0.1, 0.2);
    s.add(shade);
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color: 0xffc070, transparent: true, opacity: 0.55, depthWrite: false, blending: THREE.AdditiveBlending }));
    glow.scale.setScalar(0.7);
    glow.position.set(0, 0.1, 0.22);
    s.add(glow);
    parent.add(s);
  }
  [-5, -1.6, 1.6, 5].forEach((x) => sconce(backWall, x, 2.4));
  [-4, 4].forEach((x) => sconce(frontWall, x, 2.4));

  // ---------- Cheminée (mur gauche) ----------
  const fire = new THREE.Group();
  fire.position.set(X0, 0, 0.6);
  fire.rotation.y = Math.PI / 2;
  const stoneMat = new THREE.MeshStandardMaterial({ color: 0xb9ab95, roughness: 0.75 });
  const box = (w, h, d, x, y, z, mat) => {
    const m = new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 2, 0.015), mat);
    m.position.set(x, y, z);
    fire.add(m);
    return m;
  };
  box(0.35, 1.25, 0.4, -0.78, 0.625, 0.2, stoneMat);
  box(0.35, 1.25, 0.4, 0.78, 0.625, 0.2, stoneMat);
  box(1.95, 0.3, 0.42, 0, 1.1, 0.21, stoneMat);
  box(2.2, 0.08, 0.5, 0, 1.29, 0.25, woodMat);
  box(2.1, 0.06, 0.75, 0, 0.03, 0.37, stoneMat);
  const back = new THREE.Mesh(new THREE.BoxGeometry(1.25, 0.95, 0.05), new THREE.MeshStandardMaterial({ color: 0x15100d, roughness: 1 }));
  back.position.set(0, 0.48, 0.03);
  fire.add(back);
  const logMat = new THREE.MeshStandardMaterial({ color: 0x3b2618, roughness: 0.95 });
  [[-0.15, 0.3], [0.15, -0.3], [0, 0.05]].forEach(([x, rz], i) => {
    const log = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.07, 0.7, 10), logMat);
    log.rotation.set(0, rz, Math.PI / 2);
    log.position.set(x * 0.3, 0.12 + i * 0.07, 0.2);
    fire.add(log);
  });
  const embers = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.25),
    new THREE.MeshBasicMaterial({ map: glowTex, color: 0xff5a10, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
  embers.rotation.x = -Math.PI / 2;
  embers.position.set(0, 0.08, 0.2);
  fire.add(embers);
  const flameTex = texture(flameCanvas(), 1, 1);
  const flames = [];
  for (let i = 0; i < 7; i++) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: flameTex, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, color: i % 2 ? 0xffb050 : 0xff7a20 }));
    const bx = (i - 3) * 0.09;
    sp.position.set(bx, 0.33, 0.2 + (i % 2) * 0.05);
    flames.push({ sp, bx, ph: i * 1.7, base: 0.28 + (3 - Math.abs(i - 3)) * 0.06 });
    fire.add(sp);
  }
  const fireLight = new THREE.PointLight(0xff8a3a, 6, 9, 2);
  fireLight.position.set(0, 0.6, 0.7);
  fire.add(fireLight);
  // Tableau au-dessus de la cheminée
  const frameMat = new THREE.MeshStandardMaterial({ color: 0xb0884a, metalness: 0.9, roughness: 0.35 });
  const painting = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 1.0), new THREE.MeshStandardMaterial({ map: texture(paintingCanvas(), 1, 1), roughness: 0.7 }));
  painting.position.set(0, 2.3, 0.04);
  fire.add(painting);
  [[1.66, 0.1, 0, 0.55], [1.66, 0.1, 0, -0.55], [0.1, 1.2, 0.8, 0], [0.1, 1.2, -0.8, 0]].forEach(([w, h, x, y]) => {
    const f = new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.06), frameMat);
    f.position.set(x, 2.3 + y, 0.04);
    fire.add(f);
  });
  room.add(fire);
  updaters.push((dt, t) => {
    let sum = 0;
    flames.forEach((f) => {
      const n = Math.sin(t * 7 + f.ph) * 0.5 + Math.sin(t * 13.3 + f.ph * 2) * 0.3 + Math.sin(t * 3.1 + f.ph) * 0.2;
      const h = f.base * (1 + n * 0.25);
      f.sp.scale.set(h * 0.55, h, 1);
      f.sp.position.y = 0.16 + h / 2;
      f.sp.position.x = f.bx + Math.sin(t * 2.3 + f.ph) * 0.015;
      sum += n;
    });
    fireLight.intensity = 6 * (0.85 + sum * 0.03 + Math.sin(t * 17) * 0.03);
    embers.material.opacity = 0.75 + Math.sin(t * 5) * 0.15;
  });

  // ---------- Fauteuils ----------
  const leather = new THREE.MeshPhysicalMaterial({ color: 0x5b2617, roughness: 0.55, clearcoat: 0.3, clearcoatRoughness: 0.5 });
  function armchair() {
    const g = new THREE.Group();
    const rb = (w, h, d, x, y, z, rx = 0) => {
      const m = new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 3, 0.05), leather);
      m.position.set(x, y, z);
      m.rotation.x = rx;
      m.castShadow = true;
      g.add(m);
    };
    rb(0.78, 0.22, 0.74, 0, 0.3, 0);
    rb(0.6, 0.12, 0.6, 0, 0.46, 0.04);
    rb(0.78, 0.7, 0.18, 0, 0.72, -0.3, -0.12);
    rb(0.15, 0.36, 0.74, -0.38, 0.5, 0);
    rb(0.15, 0.36, 0.74, 0.38, 0.5, 0);
    [[-0.32, -0.28], [0.32, -0.28], [-0.32, 0.28], [0.32, 0.28]].forEach(([x, z]) => {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.018, 0.2, 8), woodMat);
      leg.position.set(x, 0.1, z);
      g.add(leg);
    });
    return g;
  }
  const c1 = armchair(); c1.position.set(-4.2, 0, -0.5); c1.rotation.y = -Math.PI / 2 - 0.45; room.add(c1);
  const c2 = armchair(); c2.position.set(-4.2, 0, 1.7); c2.rotation.y = -Math.PI / 2 + 0.45; room.add(c2);

  // ---------- Bibliothèques (mur droit) ----------
  const r = rng(77);
  const bookColors = [0x6b1a1f, 0x1f2e4a, 0x234d34, 0x8a6a2a, 0x4a2c1c, 0x2a2a2e, 0x7a4a1a, 0x5a3a5a, 0x3d5a6b];
  function bookcase() {
    const g = new THREE.Group();
    const bw = 1.5, bh = 2.6, bd = 0.38;
    const part = (w, h, d, x, y, z) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), woodMat);
      m.position.set(x, y, z);
      g.add(m);
    };
    part(0.05, bh, bd, -bw / 2, bh / 2, bd / 2);
    part(0.05, bh, bd, bw / 2, bh / 2, bd / 2);
    part(bw + 0.1, 0.08, bd + 0.04, 0, bh, bd / 2);
    part(bw, 0.02, 0.02, 0, bh / 2, 0.01);
    const backP = new THREE.Mesh(new THREE.PlaneGeometry(bw, bh), new THREE.MeshStandardMaterial({ color: 0x1a120c, roughness: 0.9 }));
    backP.position.set(0, bh / 2, 0.012);
    g.add(backP);
    const shelfY = [0.08, 0.6, 1.12, 1.64, 2.16];
    shelfY.forEach((y) => part(bw, 0.035, bd, 0, y, bd / 2));
    const books = [];
    shelfY.forEach((y, si) => {
      let x = -bw / 2 + 0.05;
      while (x < bw / 2 - (si === 4 ? 0.36 : 0.08)) {
        if (r() < 0.07) { x += 0.08 + r() * 0.12; continue; }
        const w = 0.025 + r() * 0.03, h = 0.22 + r() * 0.17, d = 0.2 + r() * 0.08;
        books.push({ x: x + w / 2, y: y + 0.0175 + h / 2, z: 0.04 + d / 2, w, h: Math.min(h, 0.48), d, c: bookColors[Math.floor(r() * bookColors.length)] });
        x += w + 0.002;
      }
      if (si === 4) {
        for (let k = 0; k < 4; k++) books.push({ x: bw / 2 - 0.2, y: y + 0.0175 + 0.02 + k * 0.04, z: 0.18, w: 0.22, h: 0.035, d: 0.16, c: bookColors[k] });
      }
    });
    const inst = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshStandardMaterial({ roughness: 0.65 }), books.length);
    const dm = new THREE.Object3D(), col = new THREE.Color();
    books.forEach((b, i) => {
      dm.position.set(b.x, b.y, b.z);
      dm.scale.set(b.w, b.h, b.d);
      dm.updateMatrix();
      inst.setMatrixAt(i, dm.matrix);
      col.setHex(b.c).multiplyScalar(0.8 + r() * 0.4);
      inst.setColorAt(i, col);
    });
    g.add(inst);
    return g;
  }
  [-3.2, -1.6, 1.4, 3.0].forEach((z) => {
    const b = bookcase();
    b.position.set(X1, 0, z);
    b.rotation.y = -Math.PI / 2;
    room.add(b);
  });

  // ---------- Tapis ----------
  const rugTex = texture(rugCanvas(), 1, 1);
  rugTex.wrapS = rugTex.wrapT = THREE.ClampToEdgeWrapping;
  const rugMat = new THREE.MeshStandardMaterial({ map: rugTex, roughness: 0.95 });
  const rug1 = new THREE.Mesh(new THREE.CircleGeometry(1.7, 64), rugMat);
  rug1.rotation.x = -Math.PI / 2;
  rug1.position.set(TABLE_POS.x, 0.006, TABLE_POS.z);
  rug1.receiveShadow = true;
  room.add(rug1);
  const rug2 = new THREE.Mesh(new THREE.CircleGeometry(1.4, 64), rugMat);
  rug2.rotation.x = -Math.PI / 2;
  rug2.scale.set(1.5, 1, 1);
  rug2.position.set(0, 0.006, -0.4);
  rug2.receiveShadow = true;
  room.add(rug2);

  // ---------- Table de jeu ----------
  const table = new THREE.Group();
  table.position.set(TABLE_POS.x, 0, TABLE_POS.z);
  const topH = TABLE_POS.y;
  const tableTop = new THREE.Mesh(new THREE.CylinderGeometry(0.72, 0.7, 0.05, 64), woodMat);
  tableTop.position.y = topH - 0.025;
  tableTop.castShadow = true; tableTop.receiveShadow = true;
  table.add(tableTop);
  const edge = new THREE.Mesh(new THREE.TorusGeometry(0.715, 0.022, 12, 80), woodMat);
  edge.rotation.x = Math.PI / 2;
  edge.position.y = topH - 0.005;
  table.add(edge);
  const felt = new THREE.Mesh(new THREE.CircleGeometry(0.64, 64),
    new THREE.MeshStandardMaterial({ map: texture(feltCanvas(), 2, 2), roughness: 0.95 }));
  felt.rotation.x = -Math.PI / 2;
  felt.position.y = topH + 0.002;
  felt.receiveShadow = true;
  table.add(felt);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.64, 0.006, 8, 80), brassMat);
  ring.rotation.x = Math.PI / 2;
  ring.position.y = topH + 0.004;
  table.add(ring);
  const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.12, topH - 0.12, 24), woodMat);
  stem.position.y = (topH - 0.12) / 2 + 0.07;
  stem.castShadow = true;
  table.add(stem);
  for (let i = 0; i < 4; i++) {
    const foot = new THREE.Mesh(new RoundedBoxGeometry(0.55, 0.07, 0.1, 2, 0.02), woodMat);
    foot.rotation.y = i * Math.PI / 2;
    foot.position.set(Math.cos(i * Math.PI / 2) * 0.25, 0.04, -Math.sin(i * Math.PI / 2) * 0.25);
    foot.castShadow = true;
    table.add(foot);
  }
  room.add(table);

  // Lampe suspendue au-dessus de la table
  const lamp = new THREE.Group();
  lamp.position.set(TABLE_POS.x, 0, TABLE_POS.z);
  const cord = new THREE.Mesh(new THREE.CylinderGeometry(0.006, 0.006, H - 2.55, 6), new THREE.MeshStandardMaterial({ color: 0x111111 }));
  cord.position.y = (H + 2.55) / 2;
  lamp.add(cord);
  const shadePts = [];
  for (let i = 0; i <= 12; i++) {
    const a = i / 12;
    shadePts.push(new THREE.Vector2(0.04 + Math.sin(a * Math.PI / 2) * 0.24, 0.16 - a * a * 0.2));
  }
  const shade = new THREE.Mesh(new THREE.LatheGeometry(shadePts, 48),
    new THREE.MeshStandardMaterial({ color: 0x1f4a33, metalness: 0.6, roughness: 0.35, side: THREE.DoubleSide }));
  shade.position.y = 2.42;
  lamp.add(shade);
  const inner = new THREE.Mesh(new THREE.CircleGeometry(0.27, 40), new THREE.MeshBasicMaterial({ color: 0xffe2b0, toneMapped: false }));
  inner.rotation.x = Math.PI / 2;
  inner.position.y = 2.38;
  lamp.add(inner);
  room.add(lamp);
  const spot = new THREE.SpotLight(0xffe0b8, 22, 6, 0.62, 0.65, 1.6);
  spot.position.set(TABLE_POS.x, 2.4, TABLE_POS.z);
  spot.target.position.set(TABLE_POS.x, 0, TABLE_POS.z);
  spot.castShadow = true;
  spot.shadow.mapSize.set(1024, 1024);
  spot.shadow.bias = -0.0004;
  spot.shadow.normalBias = 0.015;
  spot.shadow.camera.near = 0.5;
  spot.shadow.camera.far = 3.5;
  room.add(spot, spot.target);

  // ---------- Lumières d'ambiance ----------
  room.add(new THREE.HemisphereLight(0xffe6c8, 0x2a1a10, 0.55));
  const fill = new THREE.PointLight(0xffc890, 5, 10, 1.8);
  fill.position.set(0, 3.2, -3.5);
  room.add(fill);
  const fill2 = new THREE.PointLight(0xffc890, 3.5, 9, 1.8);
  fill2.position.set(3.5, 3.0, 2.0);
  room.add(fill2);

  scene.add(room);
  return {
    group: room,
    update(dt, t) { updaters.forEach((u) => u(dt, t)); },
  };
}
