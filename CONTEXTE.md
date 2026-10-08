# CONTEXTE — Salon des Jeux VR

À donner en début de discussion avec `consigne chaude.txt`.

## Le projet

Jeu de société multi-jeux en réalité virtuelle pour **Meta Quest 3**.
Un salon immersif (parquet, cheminée, bibliothèques, fenêtres sur la nuit)
avec un panneau d'accueil par catégorie, puis une table de jeu.

- Dossier local : `~/jeux_societe_vr` (tiret bas)
- Dépôt GitHub : `janintibo-art/jeux-societe-vr` (tiret simple)
- Site : https://janintibo-art.github.io/jeux-societe-vr/
- Archive de livraison : `jeux_societe_vr_vN.zip`

## Technique

- **WebXR + three.js 0.170** chargé par CDN (importmap dans `index.html`).
  Aucune compilation, aucun outil à installer : le Quest ouvre la page
  dans son navigateur et passe en VR.
- **GitHub Actions** (`.github/workflows/deploiement.yml`) vérifie la
  syntaxe de chaque fichier `.js` puis publie sur GitHub Pages.
  `gh run watch` suit donc une mise en ligne, pas une compilation.
- Tout le décor est **procédural** (textures dessinées sur canvas) : pas
  d'images ni de modèles 3D à télécharger.
- Hors casque, la page marche aussi sur téléphone : glisser pour regarder,
  toucher pour choisir. Pratique pour vérifier avant de mettre le casque.
- Ouverture directe d'un jeu : ajouter `#puissance4` à l'adresse.

## Fichiers

```
index.html                 page, importmap, bouton « Entrer dans le salon »
src/main.js                rendu, boucle, fondu, navigation entre scènes, registre des jeux
src/environment.js         le salon (murs, cheminée, table, lampe, lumières) + TABLE_POS
src/interaction.js         rayons manettes/mains en VR, souris/doigt hors VR
src/ui.js                  CanvasPlane, Button3D (boutons 3D), polices
src/textures.js            textures procédurales (parquet, tapis, cartes, dés…)
src/pieces.js              jetons, dés
src/effects.js             confettis
src/audio.js               sons synthétisés (aucun fichier audio)
src/lobby.js               accueil, liste CATEGORIES des jeux
src/games/puissance4.js    Puissance 4 (plateau, piles, animations, score)
src/games/puissance4-ia.js IA minimax dans un Web Worker
```

## Ajouter un jeu

1. Créer `src/games/nom.js` avec une classe qui expose : `group`,
   `interactables`, `spawn {position, yaw, pitch}`, `enter()`, `exit()`,
   `update(dt, t)`. S'inspirer de `puissance4.js`.
2. L'ajouter dans `factories` de `src/main.js` (même `id` que dans
   `CATEGORIES` de `src/lobby.js`). Le bouton passe alors de « Bientôt »
   à « Jouer » tout seul.
3. Toute IA un peu lourde va dans un Web Worker : un calcul de plus de
   ~10 ms dans la boucle fait saccader l'image dans le casque.

## État

| Jeu          | Catégorie | État |
|--------------|-----------|------|
| Puissance 4  | Plateau   | v1 jouable : contre l'ordinateur (3 niveaux) ou à deux |
| Reversi      | Plateau   | à faire |
| Abalone      | Plateau   | à faire |
| Awalé        | Plateau   | à faire |
| Le Président | Cartes    | à faire |
| Le Tarot     | Cartes    | à faire |
| Le 421       | Dés       | à faire |
| Le 10 000    | Dés       | à faire |
