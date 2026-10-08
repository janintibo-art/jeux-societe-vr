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
scripts/cible.gd           cible visable générique (survol / choix)
scripts/jeux/table_jeu.gd      BASE de tous les jeux de table (voir plus bas)
scripts/jeux/puissance4.gd     Puissance 4
scripts/jeux/puissance4_ia.gd  IA Puissance 4 (fil séparé, temps limité)
scripts/jeux/reversi.gd        Reversi
scripts/jeux/reversi_ia.gd     IA Reversi (poids des cases, mobilité, finale exacte)
scripts/jeux/awale.gd          Awalé (tablier creusé en CSG, semis animé graine par graine)
scripts/jeux/awale_ia.gd       règles abapa + IA Awalé
scripts/jeux/abalone.gd        Abalone (plateau hexagonal, sélection + flèches)
scripts/jeux/abalone_ia.gd     règles (sumito) + IA Abalone (centre, cohésion, menaces)
scripts/jeux/piste_des.gd      piste de dés : tapis, rebords, gobelet, dés physiques (Jolt)
scripts/jeux/jeu_des.gd        BASE des jeux de dés (boutons d'action, déroulement en coroutine)
scripts/jeux/jeu_421.gd        421 (charge / décharge, rampeau, fiches qui volent)
scripts/jeux/jeu_10000.gd      10 000 (sélection des dés, main pleine, ouverture à 500)
scripts/jeux/cartes.gd         cartes 3D : textures avec mipmaps, dos par shader, lueur, zone visable
scripts/jeux/jeu_president.gd  Président à 4 (éventail en main, adversaires Léon, Margot, Basile)
cartes/jeu1/                   les 52 cartes « Illustré n°1 » de « Les Dés du Comptoir » (webp)
shaders/                   parquet, bois, papier peint, feutre, tapis, ciel, dé (avec halo), panneaux,
                           plateau Reversi, plateau Abalone (ardoise + cercles dorés)
```

## Ajouter un jeu

`scripts/jeux/table_jeu.gd` fournit tout le commun : bandeau d'état,
tableau des scores, boutons (nouvelle partie, contre l'ordinateur / à deux,
niveau, retour au salon), IA dans un fil séparé, animations d'apparition et
de disparition, confettis, annonce de fin.

1. Créer `scripts/jeux/nom.gd` avec
   `extends "res://scripts/jeux/table_jeu.gd"`, un `_init(p_app)` qui
   appelle `super()` puis `app = p_app`, et un `_ready()` qui construit le
   plateau puis appelle `_construire_interface()`.
2. Redéfinir : `_niveaux()`, `_noms()`, `_materiau_joueur(j)`, `_aide()`,
   `_y_bandeau()`, `_preparer_partie()`, `_lancer_ia()` (renvoie
   `[objet, Callable]`), `_coup_ia(resultat)`, `_anim(a, k, delta)`.
   Jeux pas à pas (dés, cartes) : `_creer_actions(position, vertical)`,
   `demander([[id, libellé, actif], …])` attend un choix, `proposer(...)`
   met à jour les boutons, `pause(s)`. Options : `_avec_tableau()`,
   `_mode_modifiable()`, `_titre_score()`, `_texte_score(j)`.
   Fin de partie : `_annoncer_fin(gagnant, détail)`.
3. Les cases cliquables : `UI.zone(...)` avec `Cible.new(survol, choix)`.
4. L'ajouter dans `JEUX` de `scripts/main.gd` (même identifiant que dans
   `CATEGORIES` de `scripts/accueil.gd`). Le bouton passe seul à « Jouer ».
5. L'IA a toujours une limite de temps : un calcul long dans la boucle fait
   saccader l'image dans le casque.

## Pièges GDScript déjà rencontrés

- `trait` est un mot réservé (Godot 4.7).
- Les formes creusées (trous de l'Awalé) passent par les nœuds CSG : ils
  fonctionnent à l'exécution, y compris sur le casque.
- Physique : le moteur **Jolt** est obligatoire (`project.godot`). Avec le
  moteur par défaut, les petits dés lancés s'enfoncent dans le tapis et
  tournent sans fin. Garder aussi une petite marge de collision sur les dés.
- Jeux de dés : le déroulement est une coroutine (`await`). Après chaque
  `await`, vérifier `id != _partie` pour abandonner une partie remplacée.

## Inspiration

L'application téléphone « Les Dés du Comptoir » (dépôt
`janintibo-art/des-du-comptoir`) : mêmes règles pour le 421 et le 10 000,
même principe de sélection + flèches (rouges si éjection) pour l'Abalone,
même plateau d'ardoise à cercles dorés, mêmes cartes illustrées (jeu1 ; le
dépôt d'origine contient aussi les tarots « taverne » et « retro »).
- `max()`, `min()`, `abs()` renvoient un Variant : avec `:=`, utiliser
  `maxf`, `minf`, `absf`.
- Appeler une méthode d'un script sur une variable typée `Node`/`Node3D`
  est refusé : laisser la variable sans type, ou typer avec le script.

## État

| Jeu          | Catégorie | État |
|--------------|-----------|------|
| Puissance 4  | Plateau   | jouable : contre l'ordinateur (3 niveaux) ou à deux |
| Reversi      | Plateau   | jouable : contre l'ordinateur (3 niveaux) ou à deux, passe automatique |
| Abalone      | Plateau   | jouable : sélection de 1 à 3 billes puis flèche, aperçu du coup, 3 niveaux ou à deux |
| Awalé        | Plateau   | jouable : règles abapa (nourrir, pas de grand chelem), 3 niveaux ou à deux |
| Le Président | Cartes    | jouable : 4 joueurs, manches enchaînées avec échanges de cartes |
| Le Tarot     | Cartes    | à faire |
| Le 421       | Dés       | jouable : dés physiques, gobelet, fiches, charge et décharge |
| Le 10 000    | Dés       | jouable : sélection des dés, main pleine, ouverture à 500 |
