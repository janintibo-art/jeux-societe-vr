extends Node3D
## Base commune des jeux de table à deux joueurs (contre l'ordinateur ou à deux) :
## bandeau d'état, tableau des scores, boutons de commande, IA dans un fil séparé,
## animations d'apparition et de disparition des pièces, confettis.
##
## Un jeu dérivé redéfinit : _niveaux(), _noms(), _materiau_joueur(), _aide(),
## _y_bandeau(), _preparer_partie(), _lancer_ia(), _coup_ia(), _anim().

const UI := preload("res://scripts/ui.gd")
const Bouton := preload("res://scripts/bouton.gd")
const Confettis := preload("res://scripts/confettis.gd")
const Cible := preload("res://scripts/cible.gd")

## Position de l'œil du joueur, en coordonnées locales de la table.
const OEIL := Vector3(0, 0.75, 0.78)

var app
var depart := {}

var _mode := "ia"
var _niveau := 1
var _scores := {1: 0, 2: 0}
var _premier := 1
var _partie := 0
var _joueur := 1
var _occupe := false
var _fini := false
var _demarre := false
var _anims: Array = []

var _confettis: Confettis
var _statut: Label3D
var _statut_sous: Label3D
var _statut_pastille: MeshInstance3D
var _scores_txt: Array[Label3D] = []
var _noms_txt: Array[Label3D] = []
var _pastilles_score: Array[MeshInstance3D] = []
var _btn_mode: Bouton
var _btn_niveau: Bouton

var _fil: Thread
var _fil_objet: RefCounted
var _fil_partie := -1
var _fil_debut := 0
var _reflexion := false


func _init() -> void:
	position = Vector3(0, 0.76, 3.6)
	depart = {"position": Vector3(0, 0, 3.6 + 0.78), "lacet": 0.0, "tangage": -0.55}


# ------------------------------------------------------------------ à redéfinir

func _niveaux() -> Array:
	return [{"nom": "Moyen"}]


func _noms() -> Dictionary:
	return {1: "Rouge", 2: "Jaune"}


func _materiau_joueur(_j: int) -> Material:
	return null


func _forme_pastille() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.012
	s.height = 0.024
	return s


## Titre et contenu du tableau des scores (parties gagnées par défaut).
func _titre_score() -> String:
	return "Score"


func _texte_score(j: int) -> String:
	return str(_scores[j])


func _echelle_pastille() -> float:
	return 1.0


func _aide() -> String:
	return ""


func _y_bandeau() -> float:
	return 0.6


## Remet le plateau à zéro (le reste est géré par nouvelle_partie()).
func _preparer_partie() -> void:
	pass


## Renvoie [objet, Callable] : le calcul de l'IA à exécuter dans le fil.
func _lancer_ia() -> Array:
	return []


func _coup_ia(_resultat) -> void:
	pass


## Anime une entrée de _anims propre au jeu. Renvoie true pour la garder.
func _anim(_a: Dictionary, _k: float, _delta: float) -> bool:
	return false


func _mettre_a_jour(_delta: float) -> void:
	pass


# ------------------------------------------------------------------ interface

func _construire_interface() -> void:
	_confettis = Confettis.new()
	add_child(_confettis)

	var bandeau := Node3D.new()
	bandeau.position = Vector3(0, _y_bandeau(), -0.08)
	add_child(bandeau)
	_orienter(bandeau)
	bandeau.add_child(UI.panneau(Vector2(0.7, 0.11), {"radius": 0.03, "border": 0.0025}, 0.0))
	_statut = UI.texte("", 0.042, UI.CREME, UI.police_gras())
	_statut.position = Vector3(0.015, 0.012, 0.003)
	bandeau.add_child(_statut)
	_statut_sous = UI.texte("", 0.022, Color(0.91, 0.84, 0.7, 0.75))
	_statut_sous.position = Vector3(0, -0.03, 0.003)
	bandeau.add_child(_statut_sous)
	_statut_pastille = MeshInstance3D.new()
	_statut_pastille.mesh = _forme_pastille()
	_statut_pastille.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_statut_pastille.scale = Vector3.ONE * _echelle_pastille()
	_statut_pastille.position = Vector3(-0.2, 0.012, 0.01)
	bandeau.add_child(_statut_pastille)

	var tableau := Node3D.new()
	tableau.position = Vector3(-0.6, 0.42, 0.1)
	add_child(tableau)
	_orienter(tableau)
	tableau.add_child(UI.panneau(Vector2(0.3, 0.2), {"radius": 0.03, "border": 0.0025}, 0.0))
	var titre := UI.texte(_titre_score(), 0.03, UI.OR, UI.police_titre())
	titre.position = Vector3(0, 0.066, 0.003)
	tableau.add_child(titre)
	for i in 2:
		var y := 0.01 - i * 0.06
		var pastille := MeshInstance3D.new()
		pastille.mesh = _forme_pastille()
		pastille.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pastille.scale = Vector3.ONE * _echelle_pastille()
		pastille.material_override = _materiau_joueur(1 + i)
		pastille.position = Vector3(-0.11, y, 0.012)
		tableau.add_child(pastille)
		_pastilles_score.append(pastille)
		var nom := UI.texte("", 0.026, UI.CREME, UI.police_gras())
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nom.position = Vector3(-0.085, y, 0.003)
		tableau.add_child(nom)
		_noms_txt.append(nom)
		var sc := UI.texte("0", 0.034, UI.CREME, UI.police_gras())
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sc.position = Vector3(0.125, y, 0.003)
		tableau.add_child(sc)
		_scores_txt.append(sc)

	var cmd := Node3D.new()
	cmd.position = Vector3(0.6, 0.4, 0.1)
	add_child(cmd)
	_orienter(cmd)
	var items := [
		["Nouvelle partie", nouvelle_partie, UI.OR],
		["", _changer_mode, UI.OR],
		["", _changer_niveau, UI.OR],
		["Retour au salon", func(): app.retour_accueil(), Color(0.62, 0.71, 0.78)],
	]
	for i in items.size():
		var b := Bouton.new(Vector2(0.3, 0.072), items[i][0], "", "", items[i][2], true)
		b.sons = app.sons
		b.placer(Vector3(0, 0.135 - i * 0.09, 0))
		b.choisi.connect(items[i][1])
		cmd.add_child(b)
		if i == 1:
			_btn_mode = b
		elif i == 2:
			_btn_niveau = b
	_rafraichir_boutons()


## Tourne la face avant (+Z) d'un élément vers l'œil du joueur.
func _orienter(n: Node3D) -> void:
	n.basis = Basis.looking_at(-(OEIL - n.position).normalized(), Vector3.UP)


func _rafraichir_boutons() -> void:
	_btn_mode.definir("Contre l’ordinateur" if _mode == "ia" else "À deux joueurs")
	_btn_niveau.definir("Niveau : %s" % _niveaux()[_niveau].nom, _mode == "ia")
	var n := _noms()
	var noms := ["Vous", "Ordinateur"] if _mode == "ia" else [n[1], n[2]]
	for i in 2:
		_noms_txt[i].text = noms[i]
		_scores_txt[i].text = _texte_score(i + 1)


func _ecrire_statut(texte: String, joueur := 0, sous := "") -> void:
	_statut.text = texte
	_statut_sous.text = sous
	# Le sous-titre rétrécit s'il est trop long pour le bandeau.
	_statut_sous.pixel_size = 0.022 / 64.0
	var ls := _statut_sous.font.get_string_size(sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * _statut_sous.pixel_size
	if ls > 0.64:
		_statut_sous.pixel_size *= 0.64 / ls
	_statut.position.y = 0.012 if sous != "" else 0.0
	_statut_pastille.visible = joueur != 0
	if joueur != 0:
		_statut_pastille.material_override = _materiau_joueur(joueur)
		var largeur := UI.police_gras().get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * _statut.pixel_size
		_statut_pastille.position = Vector3(-largeur / 2.0 - 0.012, _statut.position.y, 0.012)
		_statut.position.x = 0.015
	else:
		_statut.position.x = 0.0


func _maj_statut(sous := "") -> void:
	if _fini:
		return
	if _mode == "ia":
		if _joueur == 1:
			_ecrire_statut("À vous de jouer", 1, sous if sous != "" else _aide())
		else:
			_ecrire_statut("L’ordinateur réfléchit…", 2, sous)
	else:
		_ecrire_statut("Au tour de %s" % _noms()[_joueur], _joueur, sous)


## Fin de partie : gagnant 0 = égalité.
func _annoncer_fin(gagnant: int, detail := "") -> void:
	_fini = true
	_occupe = false
	var sous := detail if detail != "" else "Appuyez sur « Nouvelle partie » pour rejouer"
	if gagnant == 0:
		_ecrire_statut("Match nul !", 0, sous)
		app.sons.jouer("nul")
		return
	_scores[gagnant] += 1
	_rafraichir_boutons()
	var perdu := _mode == "ia" and gagnant == 2
	if _mode == "ia":
		_ecrire_statut("L’ordinateur gagne" if perdu else "Vous avez gagné !", gagnant, sous)
	else:
		_ecrire_statut("%s gagne !" % _noms()[gagnant], gagnant, sous)
	app.sons.jouer("defaite" if perdu else "victoire")


# ------------------------------------------------------------------ déroulement commun

func nouvelle_partie() -> void:
	_partie += 1
	_reflexion = false
	_fini = false
	_occupe = false
	_joueur = _premier
	_premier = 3 - _premier
	_preparer_partie()
	_rafraichir_boutons()
	_maj_statut()
	if _tour_ia():
		_demander_ia()


func _tour_ia() -> bool:
	return _mode == "ia" and _joueur == 2 and not _fini


func _changer_mode() -> void:
	_mode = "duo" if _mode == "ia" else "ia"
	_scores = {1: 0, 2: 0}
	_premier = 1
	nouvelle_partie()


func _changer_niveau() -> void:
	_niveau = (_niveau + 1) % _niveaux().size()
	_rafraichir_boutons()
	if _fini or not _partie_entamee():
		nouvelle_partie()


func _partie_entamee() -> bool:
	return true


## Fait disparaître des pièces en douceur (puis les libère).
func _faire_sortir(pieces: Array) -> void:
	for i in pieces.size():
		var m: Node3D = pieces[i]
		_anims.append({"type": "sortie", "t": -i * 0.008, "duree": 0.35, "m": m, "y": m.position.y})
	if not pieces.is_empty():
		app.sons.jouer("souffle", -6.0)


func _faire_apparaitre(m: Node3D, retard: float) -> void:
	m.scale = Vector3.ONE * 0.001
	_anims.append({"type": "pousse", "t": -retard, "duree": 0.25, "m": m})


# ------------------------------------------------------------------ IA (fil séparé)

func _demander_ia() -> void:
	if _fil != null:
		return
	var travail := _lancer_ia()
	if travail.is_empty():
		return
	_fil_objet = travail[0]
	_fil_partie = _partie
	_fil_debut = Time.get_ticks_msec()
	_reflexion = true
	_fil = Thread.new()
	_fil.start(travail[1])
	_maj_statut()


func _verifier_ia() -> void:
	if _fil == null or _fil.is_alive():
		return
	if Time.get_ticks_msec() - _fil_debut < 650:
		return
	var resultat = _fil.wait_to_finish()
	_fil = null
	_fil_objet = null
	var valable := _reflexion and _fil_partie == _partie and _tour_ia() and not _occupe
	_reflexion = false
	if not valable:
		if _tour_ia() and not _occupe:
			_demander_ia()
		return
	_coup_ia(resultat)


# ------------------------------------------------------------------ cycle de vie

func entrer() -> void:
	if not _demarre:
		_demarre = true
		nouvelle_partie()
	elif _tour_ia() and not _occupe:
		_demander_ia()


func sortir() -> void:
	pass


func _process(delta: float) -> void:
	_verifier_ia()
	_confettis.mettre_a_jour(delta)
	# Les animations ajoutées pendant la boucle (par _anim) vont directement dans _anims.
	var courantes := _anims
	_anims = []
	var garder := _anims
	for a in courantes:
		a.t += delta
		if a.t < 0.0:
			garder.append(a)
			continue
		var k: float = minf(1.0, a.t / a.duree)
		var m: Node3D = a.m
		match a.type:
			"pousse":
				m.scale = Vector3.ONE * maxf(0.001, smoothstep(0.0, 1.0, k))
				if k < 1.0:
					garder.append(a)
			"sortie":
				m.position.y = a.y - smoothstep(0.0, 1.0, k) * 0.1
				m.scale = Vector3.ONE * maxf(0.001, 1.0 - smoothstep(0.0, 1.0, k))
				if k < 1.0:
					garder.append(a)
				else:
					m.queue_free()
			_:
				if _anim(a, k, delta):
					garder.append(a)
	_mettre_a_jour(delta)
