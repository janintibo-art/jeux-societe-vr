import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { dieFaceCanvas, texture } from './textures.js';

export const TOKEN_COLORS = { 1: 0xd61f26, 2: 0xf4c20d };

// Jeton de Puissance 4 : bord bombé, centre creusé. Axe de rotation le long de Z.
export function tokenGeometry(r = 0.0325, thick = 0.013) {
  const t = thick / 2;
  const pts = [
    [0, -t * 0.6], [r * 0.6, -t * 0.6], [r * 0.68, -t], [r * 0.93, -t], [r, -t * 0.72],
    [r, t * 0.72], [r * 0.93, t], [r * 0.68, t], [r * 0.6, t * 0.6], [0, t * 0.6],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  const geo = new THREE.LatheGeometry(pts, 48);
  geo.rotateX(Math.PI / 2);
  geo.computeVertexNormals();
  return geo;
}

export function tokenMaterial(color) {
  return new THREE.MeshPhysicalMaterial({
    color, roughness: 0.3, metalness: 0, clearcoat: 0.75, clearcoatRoughness: 0.12,
  });
}

let dieMats = null;
export function makeDie(size = 0.07) {
  if (!dieMats) {
    // Ordre des faces BoxGeometry : +x, -x, +y, -y, +z, -z (faces opposées = 7)
    dieMats = [3, 4, 1, 6, 2, 5].map((n) => new THREE.MeshPhysicalMaterial({
      map: texture(dieFaceCanvas(n)), roughness: 0.25, clearcoat: 0.6,
    }));
  }
  const mesh = new THREE.Mesh(new RoundedBoxGeometry(size, size, size, 4, size * 0.16), dieMats);
  mesh.castShadow = true;
  return mesh;
}
