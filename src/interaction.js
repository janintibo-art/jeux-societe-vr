import * as THREE from 'three';
import { XRControllerModelFactory } from 'three/addons/webxr/XRControllerModelFactory.js';
import { XRHandModelFactory } from 'three/addons/webxr/XRHandModelFactory.js';

// Gère le pointage : rayons des manettes (ou des mains) en VR, souris / doigt hors VR.
// Une « cible » est { object, onHover(bool), onSelect() }.
export class Interaction {
  constructor(renderer, camera, rig, dom, sound) {
    this.renderer = renderer;
    this.camera = camera;
    this.sound = sound;
    this.raycaster = new THREE.Raycaster();
    this.entries = [];
    this.objects = [];
    this.map = new Map();
    this.sources = [];
    this.look = { yaw: 0, pitch: 0 };
    this.tmpMat = new THREE.Matrix4();

    const ctrlFactory = new XRControllerModelFactory();
    const handFactory = new XRHandModelFactory();
    const dotMat = new THREE.MeshBasicMaterial({ color: 0xffe7b0, toneMapped: false, depthTest: false, transparent: true });

    for (let i = 0; i < 2; i++) {
      const controller = renderer.xr.getController(i);
      const grip = renderer.xr.getControllerGrip(i);
      grip.add(ctrlFactory.createControllerModel(grip));
      const hand = renderer.xr.getHand(i);
      hand.add(handFactory.createHandModel(hand, 'mesh'));
      rig.add(controller, grip, hand);

      const line = new THREE.Line(
        new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -1)]),
        new THREE.LineBasicMaterial({ color: 0xffe2a8, transparent: true, opacity: 0.75, toneMapped: false })
      );
      line.visible = false;
      controller.add(line);
      const dot = new THREE.Mesh(new THREE.SphereGeometry(0.006, 12, 8), dotMat);
      dot.renderOrder = 999;
      dot.visible = false;
      rig.add(dot);

      const src = { kind: 'xr', controller, line, dot, hovered: null, inputSource: null };
      controller.addEventListener('connected', (e) => { src.inputSource = e.data; });
      controller.addEventListener('disconnected', () => {
        src.inputSource = null;
        line.visible = false;
        dot.visible = false;
        this.setHover(src, null);
      });
      controller.addEventListener('selectstart', () => {
        this.sound?.ensure();
        this.select(src);
      });
      this.sources.push(src);
    }

    // Souris / écran tactile
    this.mouse = { kind: 'mouse', ndc: new THREE.Vector2(), active: false, hovered: null };
    this.sources.push(this.mouse);
    let down = null;
    const toNdc = (e) => {
      const r = dom.getBoundingClientRect();
      this.mouse.ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    };
    dom.addEventListener('pointerdown', (e) => {
      down = { x: e.clientX, y: e.clientY, yaw: this.look.yaw, pitch: this.look.pitch, drag: false };
      dom.setPointerCapture(e.pointerId);
    });
    dom.addEventListener('pointermove', (e) => {
      toNdc(e);
      this.mouse.active = e.pointerType === 'mouse' || !!down;
      if (!down) return;
      const dx = e.clientX - down.x, dy = e.clientY - down.y;
      if (!down.drag && Math.hypot(dx, dy) > 8) down.drag = true;
      if (down.drag) {
        const k = 2.2 / dom.clientHeight;
        this.look.yaw = down.yaw + dx * k;
        this.look.pitch = THREE.MathUtils.clamp(down.pitch + dy * k, -1.2, 1.0);
      }
    });
    dom.addEventListener('pointerup', (e) => {
      const wasDrag = down?.drag;
      down = null;
      if (wasDrag) {
        if (e.pointerType !== 'mouse') this.mouse.active = false;
        return;
      }
      toNdc(e);
      this.sound?.ensure();
      this.mouse.active = true;
      this.update();
      this.select(this.mouse);
      if (e.pointerType !== 'mouse') {
        this.mouse.active = false;
        this.update();
      }
    });
    dom.addEventListener('pointerleave', () => { this.mouse.active = false; });
  }

  setTargets(entries) {
    this.sources.forEach((s) => this.setHover(s, null));
    this.entries = entries;
    this.objects = entries.map((e) => e.object);
    this.map = new Map(entries.map((e) => [e.object, e]));
  }

  entryOf(obj) {
    while (obj) {
      const e = this.map.get(obj);
      if (e) return e;
      obj = obj.parent;
    }
    return null;
  }

  setHover(src, entry) {
    if (src.hovered === entry) return;
    const old = src.hovered;
    src.hovered = entry;
    if (old && !this.sources.some((s) => s.hovered === old)) old.onHover?.(false, src);
    if (entry) {
      entry.onHover?.(true, src);
      const pad = src.inputSource?.gamepad?.hapticActuators?.[0];
      if (pad?.pulse) pad.pulse(0.25, 25);
    }
  }

  select(src) {
    if (src.hovered?.onSelect) {
      src.hovered.onSelect(src);
      const pad = src.inputSource?.gamepad?.hapticActuators?.[0];
      if (pad?.pulse) pad.pulse(0.6, 40);
    }
  }

  update() {
    const presenting = this.renderer.xr.isPresenting;
    for (const s of this.sources) {
      if (s.kind === 'xr') {
        if (!presenting || !s.inputSource) {
          s.line.visible = false;
          s.dot.visible = false;
          this.setHover(s, null);
          continue;
        }
        this.tmpMat.identity().extractRotation(s.controller.matrixWorld);
        this.raycaster.ray.origin.setFromMatrixPosition(s.controller.matrixWorld);
        this.raycaster.ray.direction.set(0, 0, -1).applyMatrix4(this.tmpMat);
      } else {
        if (presenting || !s.active) { this.setHover(s, null); continue; }
        this.raycaster.setFromCamera(s.ndc, this.camera);
      }
      const hits = this.objects.length ? this.raycaster.intersectObjects(this.objects, true) : [];
      let entry = null, hit = null;
      for (const h of hits) {
        const e = this.entryOf(h.object);
        if (e && e.enabled !== false) { entry = e; hit = h; break; }
      }
      if (s.kind === 'xr') {
        s.line.visible = true;
        s.line.scale.z = hit ? hit.distance : 2.5;
        s.line.material.opacity = hit ? 0.95 : 0.35;
        s.dot.visible = !!hit;
        if (hit) {
          s.dot.parent.worldToLocal(s.dot.position.copy(hit.point));
        }
      }
      this.setHover(s, entry);
    }
  }
}
