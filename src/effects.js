import * as THREE from 'three';

const PALETTE = [0xd61f26, 0xf4c20d, 0x2f6fe0, 0x2fbf71, 0xffffff, 0xd8b25a, 0xe05ab8];

export class Confetti {
  constructor(parent, count = 160) {
    this.count = count;
    this.mesh = new THREE.InstancedMesh(
      new THREE.PlaneGeometry(0.014, 0.022),
      new THREE.MeshBasicMaterial({ side: THREE.DoubleSide, toneMapped: false }),
      count
    );
    this.mesh.frustumCulled = false;
    this.mesh.visible = false;
    this.pos = new Float32Array(count * 3);
    this.vel = new Float32Array(count * 3);
    this.rot = new Float32Array(count * 3);
    this.spin = new Float32Array(count * 3);
    this.life = 0;
    this.dummy = new THREE.Object3D();
    const c = new THREE.Color();
    for (let i = 0; i < count; i++) {
      c.setHex(PALETTE[i % PALETTE.length]);
      this.mesh.setColorAt(i, c);
    }
    parent.add(this.mesh);
  }

  burst(origin) {
    for (let i = 0; i < this.count; i++) {
      const k = i * 3;
      this.pos[k] = origin.x + (Math.random() - 0.5) * 0.3;
      this.pos[k + 1] = origin.y + Math.random() * 0.05;
      this.pos[k + 2] = origin.z + (Math.random() - 0.5) * 0.1;
      const a = Math.random() * Math.PI * 2, s = 0.3 + Math.random() * 0.9;
      this.vel[k] = Math.cos(a) * s;
      this.vel[k + 1] = 1.4 + Math.random() * 1.6;
      this.vel[k + 2] = Math.sin(a) * s * 0.6 + 0.35;
      for (let j = 0; j < 3; j++) {
        this.rot[k + j] = Math.random() * 6;
        this.spin[k + j] = (Math.random() - 0.5) * 18;
      }
    }
    this.life = 3.5;
    this.mesh.visible = true;
  }

  update(dt) {
    if (!this.mesh.visible) return;
    this.life -= dt;
    if (this.life <= 0) { this.mesh.visible = false; return; }
    const drag = Math.max(0, 1 - 2.2 * dt);
    const fade = Math.min(1, this.life / 0.6);
    for (let i = 0; i < this.count; i++) {
      const k = i * 3;
      this.vel[k + 1] -= 3.2 * dt;
      this.vel[k] *= drag; this.vel[k + 1] *= drag; this.vel[k + 2] *= drag;
      this.pos[k] += this.vel[k] * dt + Math.sin(this.rot[k] * 0.5) * 0.002;
      this.pos[k + 1] += this.vel[k + 1] * dt;
      this.pos[k + 2] += this.vel[k + 2] * dt;
      for (let j = 0; j < 3; j++) this.rot[k + j] += this.spin[k + j] * dt;
      this.dummy.position.set(this.pos[k], this.pos[k + 1], this.pos[k + 2]);
      this.dummy.rotation.set(this.rot[k], this.rot[k + 1], this.rot[k + 2]);
      this.dummy.scale.setScalar(fade);
      this.dummy.updateMatrix();
      this.mesh.setMatrixAt(i, this.dummy.matrix);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}
