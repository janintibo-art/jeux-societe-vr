import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { setAnisotropy } from './textures.js';
import { buildEnvironment } from './environment.js';
import { Interaction } from './interaction.js';
import { Sound } from './audio.js';
import { Lobby } from './lobby.js';
import { Puissance4 } from './games/puissance4.js';

const loading = document.getElementById('loading');

async function loadFonts() {
  if (!document.fonts) return;
  const wanted = ['700 64px Cinzel', '400 32px Nunito', '700 32px Nunito', '800 32px Nunito', 'italic 400 32px Nunito'];
  const timeout = new Promise((res) => setTimeout(res, 4000));
  await Promise.race([Promise.all(wanted.map((f) => document.fonts.load(f))).catch(() => {}), timeout]);
}

async function start() {
  await loadFonts();

  // ---------- Rendu ----------
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.xr.enabled = true;
  renderer.xr.setReferenceSpaceType('local-floor');
  renderer.xr.setFoveation(0.5);
  document.body.appendChild(renderer.domElement);
  setAnisotropy(renderer.capabilities.getMaxAnisotropy());

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0b0807);
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.22;

  const rig = new THREE.Group();
  scene.add(rig);
  const camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.03, 60);
  camera.rotation.order = 'YXZ';
  camera.position.set(0, 1.6, 0);
  rig.add(camera);

  const env = buildEnvironment(scene);
  const sound = new Sound();
  const interaction = new Interaction(renderer, camera, rig, renderer.domElement, sound);

  // ---------- Fondu entre les scènes ----------
  const fade = new THREE.Mesh(
    new THREE.SphereGeometry(0.35, 16, 12),
    new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 1, side: THREE.BackSide, depthTest: false, depthWrite: false })
  );
  fade.renderOrder = 10000;
  fade.frustumCulled = false;
  scene.add(fade);
  let fadeTarget = 0, fadeSpeed = 1.6, onFaded = null;

  // ---------- Scènes ----------
  const factories = { puissance4: (app) => new Puissance4(app) };
  const instances = {};
  let current = null;

  const app = {
    scene, renderer, camera, rig, sound, interaction,
    games: factories,
    goTo(next) {
      if (onFaded || next === current) return;
      fadeTarget = 1;
      fadeSpeed = 3.5;
      onFaded = () => {
        if (current) current.exit();
        current = next;
        rig.position.copy(next.spawn.position);
        rig.rotation.y = next.spawn.yaw;
        interaction.look.yaw = 0;
        interaction.look.pitch = next.spawn.pitch;
        interaction.setTargets(next.interactables);
        next.enter();
        fadeTarget = 0;
        fadeSpeed = 2.5;
      };
    },
    openGame(id) {
      if (!factories[id]) return;
      if (!instances[id]) instances[id] = factories[id](app);
      app.goTo(instances[id]);
    },
    goLobby() { app.goTo(lobby); },
  };

  const lobby = new Lobby(app);
  current = lobby;
  interaction.setTargets(lobby.interactables);
  interaction.look.pitch = lobby.spawn.pitch;
  lobby.enter();

  // ---------- Bouton VR ----------
  setupVR(renderer, sound);

  window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  });

  // Ouverture directe d'un jeu : index.html#puissance4
  const hash = location.hash.slice(1);
  if (factories[hash]) {
    instances[hash] = factories[hash](app);
    current.exit();
    current = instances[hash];
    rig.position.copy(current.spawn.position);
    interaction.look.pitch = current.spawn.pitch;
    interaction.setTargets(current.interactables);
    current.enter();
  }

  loading.classList.add('hidden');
  app.instances = instances;
  window.__app = app;

  // ---------- Boucle ----------
  const clock = new THREE.Clock();
  const camPos = new THREE.Vector3();
  renderer.setAnimationLoop(() => {
    const dt = Math.min(clock.getDelta(), 0.05);
    const t = clock.elapsedTime;

    if (!renderer.xr.isPresenting) {
      camera.position.set(0, 1.6, 0);
      camera.rotation.set(interaction.look.pitch, interaction.look.yaw, 0);
    }
    interaction.update();
    env.update(dt, t);
    current.update(dt, t);

    const m = fade.material;
    if (m.opacity !== fadeTarget) {
      m.opacity = fadeTarget > m.opacity ? Math.min(fadeTarget, m.opacity + dt * fadeSpeed) : Math.max(fadeTarget, m.opacity - dt * fadeSpeed);
    } else if (onFaded && fadeTarget === 1) {
      const f = onFaded;
      onFaded = null;
      f();
    }
    fade.visible = m.opacity > 0.001;
    const cam = renderer.xr.isPresenting ? renderer.xr.getCamera() : camera;
    cam.getWorldPosition(camPos);
    fade.position.copy(camPos);

    renderer.render(scene, camera);
  });
}

function setupVR(renderer, sound) {
  const btn = document.getElementById('vr');
  const note = document.getElementById('vr-note');
  if (!navigator.xr) {
    btn.textContent = 'Mode écran';
    btn.disabled = true;
    note.textContent = 'Ouvrez cette page dans le navigateur du Meta Quest 3 pour jouer en réalité virtuelle.';
    return;
  }
  navigator.xr.isSessionSupported('immersive-vr').then((ok) => {
    if (!ok) {
      btn.textContent = 'Mode écran';
      btn.disabled = true;
      note.textContent = 'Aucun casque détecté : ouvrez cette page dans le navigateur du Meta Quest 3.';
      return;
    }
    let session = null;
    btn.disabled = false;
    btn.textContent = 'Entrer dans le salon';
    note.textContent = 'Visez avec la manette ou la main, appuyez sur la gâchette ou pincez pour choisir.';
    btn.onclick = async () => {
      sound.ensure();
      if (session) { session.end(); return; }
      try {
        session = await navigator.xr.requestSession('immersive-vr', {
          optionalFeatures: ['local-floor', 'bounded-floor', 'hand-tracking', 'layers'],
        });
      } catch (e) {
        note.textContent = 'Impossible de démarrer la VR : ' + e.message;
        return;
      }
      session.addEventListener('end', () => {
        session = null;
        btn.textContent = 'Entrer dans le salon';
      });
      await renderer.xr.setSession(session);
      btn.textContent = 'Quitter la VR';
    };
  });
}

start().catch((e) => {
  loading.textContent = 'Erreur au chargement : ' + e.message;
  console.error(e);
});
