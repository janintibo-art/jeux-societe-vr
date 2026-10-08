# CONTEXTE — Salon des Jeux VR (Godot)

À donner en début de discussion avec `consigne chaude.txt`.

## Le projet

Jeu de société multi-jeux en réalité virtuelle pour **Meta Quest 3**, en
application native (APK). Un salon immersif (parquet, cheminée avec feu
animé et crépitement, bibliothèques, fenêtres sur la nuit) avec un panneau
d'accueil par catégorie, puis une table de jeu.

- Dossier local : `~/jeux_societe_vr` (tiret bas)
- Dépôt GitHub : `janintibo-art/jeux-societe-vr` (tiret simple)
- Archive de livraison : `jeux_societe_vr_vN.zip`
- APK : publiée à chaque compilation dans la version GitHub `derniere`
  (`salon_des_jeux.apk`)
- Identifiant Android : `fr.janintibo.salondesjeux`

Historique : la v1 était en WebXR (navigateur). Passage à Godot en v2.

## Technique

- **Godot 4.7.2**, rendu « Compatibility » (recommandé pour les casques
  Android), **OpenXR** + plugin **Godot OpenXR Vendors 5.1.0** (Meta).
- Tout est construit **par le code** (GDScript) : `main.tscn` ne contient
  qu'un nœud. Matières dessinées par shaders, formes 3D générées, sons
  synthétisés. Aucun modèle, image ou fichier audio.
- **GitHub Actions** (`.github/workflows/apk.yml`) : télécharge Godot, les
  modèles d'export et le plugin (mis en cache), importe le projet (échoue
  si un script a une erreur), compile l'APK avec Gradle, la signe et la
  publie dans la version `derniere`. Compter 5 à 8 minutes.
- Le plugin Meta n'est **pas** dans le dépôt : la compilation le télécharge.
- **Signature** : `salon.keystore` (alias `salon`, mot de passe dans
  `apk.yml`). Ne jamais le perdre ni le changer : sinon le casque refuse la
  mise à jour et il faut désinstaller le jeu avant de réinstaller.
- Contrôles : rayon depuis la manette (gâchette) ou la main (pincement).
  Mains suivies affichées en sphères. Vibration au survol.
- Sans casque (ordinateur), une caméra souris prend le relais : sert aux
  tests automatiques (`--jeu=puissance4 --clics=x:y@s --capture=fichier@s`).

## Fichiers

```
project.godot              réglages (OpenXR, suivi des mains, rendu)
export_presets.cfg         préréglage d'export « Meta Quest »
openxr_action_map.tres     actions des manettes et des mains
salon.keystore             clé de signature de l'APK
main.tscn                  scène de départ (un seul nœud)
scripts/main.gd            VR, joueur, pointeurs, fondus, liste JEUX
scripts/salon.gd           la pièce, la table, les lumières (TABLE)
scripts/accueil.gd         accueil, liste CATEGORIES des jeux
scripts/bouton.gd          bouton 3D (survol, clic, badge)
scripts/ui.gd              panneaux, textes, polices, zones visables
scripts/formes.gd          maillages : jetons, plaque trouée, dés, rideaux
scripts/sons.gd            sons synthétisés
scripts/confettis.gd       confettis de victoire
scripts/jeux/puissance4.gd     Puissance 4
scripts/jeux/puissance4_ia.gd  IA (fil séparé, temps limité)
shaders/                   parquet, bois, papier peint, feutre, tapis, ciel, dé, panneaux
```

## Ajouter un jeu

1. Créer `scripts/jeux/nom.gd` (`extends Node3D`) avec : `_init(app)`,
   `depart` (`position`, `lacet`, `tangage`), `entrer()`, `sortir()`.
   S'inspirer de `puissance4.gd`. Les éléments cliquables passent par
   `UI.zone(...)` avec un objet qui a `survol(bool)` et `choisir()`.
2. L'ajouter dans `JEUX` de `scripts/main.gd` (même identifiant que dans
   `CATEGORIES` de `scripts/accueil.gd`). Le bouton passe seul de
   « Bientôt » à « Jouer ».
3. Toute IA va dans un `Thread`, avec une limite de temps : un calcul long
   dans la boucle fait saccader l'image dans le casque.

## Pièges GDScript déjà rencontrés

- `trait` est un mot réservé (Godot 4.7).
- `max()`, `min()`, `abs()` renvoient un Variant : avec `:=`, utiliser
  `maxf`, `minf`, `absf`.
- Appeler une méthode d'un script sur une variable typée `Node`/`Node3D`
  est refusé : laisser la variable sans type, ou typer avec le script.

## État

| Jeu          | Catégorie | État |
|--------------|-----------|------|
| Puissance 4  | Plateau   | jouable : contre l'ordinateur (3 niveaux) ou à deux |
| Reversi      | Plateau   | à faire |
| Abalone      | Plateau   | à faire |
| Awalé        | Plateau   | à faire |
| Le Président | Cartes    | à faire |
| Le Tarot     | Cartes    | à faire |
| Le 421       | Dés       | à faire |
| Le 10 000    | Dés       | à faire |
