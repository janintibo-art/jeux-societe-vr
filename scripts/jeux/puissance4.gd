extends Node3D
## Puissance 4 sur la table du salon : contre l'ordinateur (3 niveaux) ou à deux.

const UI := preload("res://scripts/ui.gd")
const Bouton := preload("res://scripts/bouton.gd")
const Formes := preload("res://scripts/formes.gd")
const IA := preload("res://scripts/jeux/puissance4_ia.gd")
const Confettis := preload("res://scripts/confettis.gd")

const COLS := 7
const ROWS := 6
const CELL := 0.075
const TROU := 0.029
const JETON_R := 0.0325
const JETON_E := 0.013
const FENTE := 0.017
const PLAQUE := 0.008
const MARGE := 0.032
const PIEDS := 0.035
const LARGEUR := COLS * CELL + 2 * MARGE
const HAUTEUR := ROWS * CELL + 2 * MARGE
const Y0 := PIEDS + MARGE + CELL / 2.0
const HAUT := PIEDS + HAUTEUR
const Y_LACHER := HAUT + 0.06
const GRAVITE := 6.5

const NIVEAUX := [
	{"nom": "Facile", "prof": 2, "hasard": 0.4, "temps": 300},
	{"nom": "Moyen", "prof": 4, "hasard": 0.05, "temps": 700},
	{"nom": "Difficile", "prof": 9, "hasard": 0.0, "temps": 1500},
]
const NOMS := {1: "Rouge", 2: "Jaune"}

var app
var depart := {}

var _plateau: Node3D
var _jeton_geo: ArrayMesh
var _fantome: MeshInstance3D
var _atterrissage: MeshInstance3D
var _statut: Label3D
var _statut_sous: Label3D
var _statut_pastille: MeshInstance3D
var _scores_txt: Array[Label3D] = []
var _noms_txt: Array[Label3D] = []
var _btn_mode: Bouton
var _btn_niveau: Bouton
var _confettis: Confettis

var _mode := "ia"
var _niveau := 1
var _scores := {1: 0, 2: 0}
var _premier := 1
var _partie := 0
var _grille: Array = []
var _cases: Array = []
var _piles := {1: [], 2: []}
var _coups := 0
var _joueur := 1
var _occupe := false
var _fini := false
var _colonne_visee := -1
var _anims: Array = []
var _ligne_gagnante: Array = []
var _t_victoire := 0.0
var _demarre := false

var _fil: Thread
var _ia: IA
var _fil_partie := -1
var _fil_debut := 0


func _init(p_app) -> void:
	app = p_app
	position = Vector3(0, 0.76, 3.6)
	depart = {"position": Vector3(0, 0, 3.6 + 0.78), "lacet": 0.0, "tangage": -0.55}


func _ready() -> void:
	_jeton_geo = Formes.jeton(JETON_R, JETON_E)
	_construire_plateau()
	_construire_interface()
	_confettis = Confettis.new()
	add_child(_confettis)


# ------------------------------------------------------------------ construction

func _construire_plateau() -> void:
	_plateau = Node3D.new()
	_plateau.position = Vector3(0, 0, -0.06)
	add_child(_plateau)
	var bleu := StandardMaterial3D.new()
	bleu.albedo_color = Color(0.07, 0.24, 0.75)
	bleu.roughness = 0.22
	bleu.metallic_specular = 0.7
	bleu.rim_enabled = false
	var plaque_avant := MeshInstance3D.new()
	plaque_avant.mesh = Formes.plaque_trouee(COLS, ROWS, CELL, TROU, MARGE, PIEDS, FENTE / 2.0 + PLAQUE, FENTE / 2.0)
	plaque_avant.material_override = bleu
	_plateau.add_child(plaque_avant)
	var plaque_arriere := MeshInstance3D.new()
	plaque_arriere.mesh = Formes.plaque_trouee(COLS, ROWS, CELL, TROU, MARGE, PIEDS, -FENTE / 2.0, -FENTE / 2.0 - PLAQUE)
	plaque_arriere.material_override = bleu
	_plateau.add_child(plaque_arriere)
	var rail_l := MARGE * 0.6
	_boite(Vector3(rail_l, HAUTEUR, FENTE), Vector3(-LARGEUR / 2.0 + rail_l / 2.0, PIEDS + HAUTEUR / 2.0, 0), bleu)
	_boite(Vector3(rail_l, HAUTEUR, FENTE), Vector3(LARGEUR / 2.0 - rail_l / 2.0, PIEDS + HAUTEUR / 2.0, 0), bleu)
	var barre := Y0 - JETON_R - PIEDS
	_boite(Vector3(LARGEUR, barre, FENTE), Vector3(0, PIEDS + barre / 2.0, 0), bleu)
	var pied_mat := bleu.duplicate() as StandardMaterial3D
	pied_mat.albedo_color = Color(0.05, 0.19, 0.6)
	for s in [-1.0, 1.0]:
		_boite(Vector3(0.035, 0.16, 0.22), Vector3(s * (LARGEUR / 2.0 + 0.016), 0.08, 0), pied_mat)
		_boite(Vector3(0.022, HAUTEUR - 0.02, 0.05), Vector3(s * (LARGEUR / 2.0 + 0.009), PIEDS + HAUTEUR / 2.0, 0), pied_mat)
	for c in _plateau.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Zones de visée : une par colonne
	for c in COLS:
		var col := c
		var cible := Cible.new(func(on: bool): _viser(col if on else (-1 if _colonne_visee == col else _colonne_visee)),
				func(): _jouer_humain(col))
		UI.zone(_plateau, Vector3(CELL, HAUTEUR + 0.14, 0.09), Vector3(_col_x(c), PIEDS + (HAUTEUR + 0.14) / 2.0, 0), cible)

	var fm := app.materiau_jeton(1).duplicate() as StandardMaterial3D
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color.a = 0.55
	_fantome = MeshInstance3D.new()
	_fantome.mesh = _jeton_geo
	_fantome.material_override = fm
	_fantome.visible = false
	_plateau.add_child(_fantome)
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.albedo_color = Color(1, 0, 0, 0.25)
	_atterrissage = MeshInstance3D.new()
	_atterrissage.mesh = _jeton_geo
	_atterrissage.material_override = am
	_atterrissage.visible = false
	_plateau.add_child(_atterrissage)


func _boite(taille: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	_plateau.add_child(mi)
	return mi


func _construire_interface() -> void:
	var oeil := global_transform.origin + Vector3(0, 0.75, 0.78)
	if not is_inside_tree():
		oeil = position + Vector3(0, 0.75, 0.78)

	# Bandeau d'état au-dessus du plateau
	var bandeau := Node3D.new()
	bandeau.position = Vector3(0, HAUT + 0.16, -0.08)
	add_child(bandeau)
	_orienter(bandeau, oeil)
	bandeau.add_child(UI.panneau(Vector2(0.7, 0.11), {"radius": 0.03, "border": 0.0025}, 0.0))
	_statut = UI.texte("", 0.042, UI.CREME, UI.police_gras())
	_statut.position = Vector3(0.015, 0.012, 0.003)
	bandeau.add_child(_statut)
	_statut_sous = UI.texte("", 0.022, Color(0.91, 0.84, 0.7, 0.75))
	_statut_sous.position = Vector3(0, -0.03, 0.003)
	bandeau.add_child(_statut_sous)
	_statut_pastille = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.012
	sp.height = 0.024
	_statut_pastille.mesh = sp
	_statut_pastille.position = Vector3(-0.2, 0.012, 0.01)
	bandeau.add_child(_statut_pastille)

	# Scores à gauche
	var tableau := Node3D.new()
	tableau.position = Vector3(-0.6, 0.42, 0.1)
	add_child(tableau)
	_orienter(tableau, oeil)
	tableau.add_child(UI.panneau(Vector2(0.3, 0.2), {"radius": 0.03, "border": 0.0025}, 0.0))
	var titre := UI.texte("Score", 0.03, UI.OR, UI.police_titre())
	titre.position = Vector3(0, 0.066, 0.003)
	tableau.add_child(titre)
	for i in 2:
		var y := 0.01 - i * 0.06
		var pastille := MeshInstance3D.new()
		pastille.mesh = _jeton_geo
		pastille.material_override = app.materiau_jeton(1 + i)
		pastille.scale = Vector3.ONE * 0.45
		pastille.position = Vector3(-0.11, y, 0.005)
		tableau.add_child(pastille)
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

	# Commandes à droite
	var cmd := Node3D.new()
	cmd.position = Vector3(0.6, 0.4, 0.1)
	add_child(cmd)
	_orienter(cmd, oeil)
	var items := [
		["Nouvelle partie", _nouvelle_partie, UI.OR],
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


func _orienter(n: Node3D, oeil: Vector3) -> void:
	# Oriente la face avant (+Z) du nœud vers l'œil, en coordonnées locales du jeu.
	var cible := oeil - position
	var b := Basis.looking_at(-(cible - n.position).normalized(), Vector3.UP)
	n.basis = b


func _rafraichir_boutons() -> void:
	_btn_mode.definir("Contre l’ordinateur" if _mode == "ia" else "À deux joueurs")
	_btn_niveau.definir("Niveau : %s" % NIVEAUX[_niveau].nom, _mode == "ia")
	var noms := ["Vous", "Ordinateur"] if _mode == "ia" else ["Rouge", "Jaune"]
	for i in 2:
		_noms_txt[i].text = noms[i]
		_scores_txt[i].text = str(_scores[i + 1])


func _ecrire_statut(texte: String, joueur := 0, sous := "") -> void:
	_statut.text = texte
	_statut_sous.text = sous
	_statut.position.y = 0.012 if sous != "" else 0.0
	_statut_pastille.visible = joueur != 0
	if joueur != 0:
		_statut_pastille.material_override = app.materiau_jeton(joueur)
		var largeur := UI.police_gras().get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * _statut.pixel_size
		_statut_pastille.position = Vector3(-largeur / 2.0 - 0.012, _statut.position.y, 0.01)
		_statut.position.x = 0.015
	else:
		_statut.position.x = 0.0


func _maj_statut() -> void:
	if _fini:
		return
	if _mode == "ia":
		if _joueur == 1:
			_ecrire_statut("À vous de jouer", 1, "Visez une colonne et appuyez sur la gâchette")
		else:
			_ecrire_statut("L’ordinateur réfléchit…", 2)
	else:
		_ecrire_statut("Au tour de %s" % NOMS[_joueur], _joueur)


# ------------------------------------------------------------------ outils

func _col_x(c: int) -> float:
	return (c - (COLS - 1) / 2.0) * CELL


func _rang_y(r: int) -> float:
	return Y0 + r * CELL


func _plus_bas(c: int) -> int:
	for r in ROWS:
		if _grille[c][r] == 0:
			return r
	return -1


func _tour_ia() -> bool:
	return _mode == "ia" and _joueur == 2 and not _fini


# ------------------------------------------------------------------ piles

func _pos_pile(joueur: int, i: int) -> Vector3:
	var cote := -1.0 if joueur == 1 else 1.0
	var tas := i / 7
	var k := i % 7
	var dec: Vector2 = [Vector2(0, 0), Vector2(0.072, 0.02), Vector2(0.036, -0.045)][tas]
	return Vector3(cote * (0.4 + dec.x), 0.003 + JETON_E / 2.0 + k * (JETON_E + 0.0004), 0.1 + dec.y)


func _construire_piles() -> void:
	_piles = {1: [], 2: []}
	for j in [1, 2]:
		for i in 21:
			var m := MeshInstance3D.new()
			m.mesh = _jeton_geo
			m.material_override = app.materiau_jeton(j)
			m.position = _pos_pile(j, i)
			m.rotation = Vector3(-PI / 2.0, 0, randf() * TAU)
			m.scale = Vector3.ONE * 0.001
			add_child(m)
			_piles[j].append(m)
			_anims.append({"type": "pousse", "t": -i * 0.015, "duree": 0.25, "m": m})


# ------------------------------------------------------------------ déroulement

func _nouvelle_partie() -> void:
	_partie += 1
	var anciens: Array = []
	for col in _cases:
		for m in col:
			if m:
				anciens.append(m)
	for j in [1, 2]:
		for m in _piles[j]:
			anciens.append(m)
	var restes: Array = []
	for a in _anims:
		if a.type == "sortie":
			restes.append(a)
	_anims = restes
	for i in anciens.size():
		var m: Node3D = anciens[i]
		_anims.append({"type": "sortie", "t": -i * 0.008, "duree": 0.35, "m": m, "y": m.position.y})
	if not anciens.is_empty():
		app.sons.jouer("souffle", -6.0)

	_grille = []
	_cases = []
	for c in COLS:
		_grille.append([0, 0, 0, 0, 0, 0])
		_cases.append([null, null, null, null, null, null])
	_coups = 0
	_ligne_gagnante = []
	_fini = false
	_occupe = false
	_joueur = _premier
	_premier = 3 - _premier
	_construire_piles()
	_rafraichir_boutons()
	_maj_statut()
	_maj_fantome()
	if _tour_ia():
		_demander_ia()


func _changer_mode() -> void:
	_mode = "duo" if _mode == "ia" else "ia"
	_scores = {1: 0, 2: 0}
	_premier = 1
	_nouvelle_partie()


func _changer_niveau() -> void:
	_niveau = (_niveau + 1) % NIVEAUX.size()
	_rafraichir_boutons()
	if _coups == 0 or _fini:
		_nouvelle_partie()


func _jouer_humain(c: int) -> void:
	if _occupe or _fini or _tour_ia():
		return
	if _plus_bas(c) < 0:
		app.sons.jouer("refus")
		return
	_jouer(c)


func _jouer(c: int) -> void:
	var r := _plus_bas(c)
	if r < 0:
		return
	var j := _joueur
	_grille[c][r] = j
	_coups += 1
	_occupe = true
	_maj_fantome()
	var m: MeshInstance3D = null
	if not _piles[j].is_empty():
		m = _piles[j].pop_back()
	else:
		m = MeshInstance3D.new()
		m.mesh = _jeton_geo
		add_child(m)
		m.position = _pos_pile(j, 0)
	m.material_override = app.materiau_jeton(j).duplicate()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	m.scale = Vector3.ONE
	var t_global := m.global_transform
	remove_child(m)
	_plateau.add_child(m)
	m.global_transform = t_global
	_cases[c][r] = m
	_anims.append({
		"type": "vol", "t": 0.0, "duree": 0.42, "m": m, "c": c, "r": r, "j": j, "partie": _partie,
		"de": m.position, "de_q": m.quaternion, "vers": Vector3(_col_x(c), Y_LACHER, 0),
	})
	app.sons.jouer_a("souffle", m.global_position, -10.0)


func _pose(a: Dictionary) -> void:
	if a.partie != _partie:
		return
	var ligne := _cherche_ligne(a.c, a.r, a.j)
	if not ligne.is_empty():
		_terminer(a.j, ligne)
		return
	if _coups >= COLS * ROWS:
		_terminer(0, [])
		return
	_joueur = 3 - _joueur
	_occupe = false
	_maj_statut()
	_maj_fantome()
	if _tour_ia():
		_demander_ia()


func _cherche_ligne(c: int, r: int, p: int) -> Array:
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var ligne: Array = [Vector2i(c, r)]
		for sens in [1, -1]:
			var k := 1
			while true:
				var cc: int = c + d.x * k * sens
				var rr: int = r + d.y * k * sens
				if cc < 0 or cc >= COLS or rr < 0 or rr >= ROWS or _grille[cc][rr] != p:
					break
				ligne.append(Vector2i(cc, rr))
				k += 1
		if ligne.size() >= 4:
			return ligne
	return []


func _terminer(gagnant: int, ligne: Array) -> void:
	_fini = true
	_occupe = false
	_maj_fantome()
	if gagnant == 0:
		_ecrire_statut("Match nul !", 0, "Le plateau est plein")
		app.sons.jouer("nul")
		return
	_scores[gagnant] += 1
	_rafraichir_boutons()
	_ligne_gagnante = []
	for p in ligne:
		_ligne_gagnante.append(_cases[p.x][p.y])
	_t_victoire = 0.0
	var perdu := _mode == "ia" and gagnant == 2
	var sous := "Appuyez sur « Nouvelle partie » pour rejouer"
	if _mode == "ia":
		_ecrire_statut("L’ordinateur gagne" if perdu else "Vous avez gagné !", gagnant, sous)
	else:
		_ecrire_statut("%s gagne !" % NOMS[gagnant], gagnant, sous)
	if perdu:
		app.sons.jouer("defaite")
	else:
		app.sons.jouer("victoire")
		var centre := Vector3.ZERO
		for m in _ligne_gagnante:
			centre += (m as Node3D).position
		centre = centre / _ligne_gagnante.size() + _plateau.position
		_confettis.lancer(centre)


# ------------------------------------------------------------------ IA (fil séparé)

func _demander_ia() -> void:
	if _fil != null:
		return
	var plateau := PackedByteArray()
	plateau.resize(COLS * ROWS)
	for c in COLS:
		for r in ROWS:
			plateau[c * ROWS + r] = _grille[c][r]
	var nv: Dictionary = NIVEAUX[_niveau]
	_fil_partie = _partie
	_fil_debut = Time.get_ticks_msec()
	_fil = Thread.new()
	_ia = IA.new()
	_fil.start(_ia.choisir.bind(plateau, 2, nv.prof, nv.hasard, nv.temps))
	_maj_statut()


func _verifier_ia() -> void:
	if _fil == null or _fil.is_alive():
		return
	if Time.get_ticks_msec() - _fil_debut < 650:
		return
	var col: int = _fil.wait_to_finish()
	_fil = null
	if _fil_partie != _partie or _fini or not _tour_ia() or _occupe:
		if _tour_ia() and not _occupe:
			_demander_ia()
		return
	_jouer(col)


# ------------------------------------------------------------------ visée

func _viser(c: int) -> void:
	_colonne_visee = c
	_maj_fantome()


func _maj_fantome() -> void:
	var c := _colonne_visee
	var ok := c >= 0 and not _occupe and not _fini and not _tour_ia() and not _grille.is_empty() and _plus_bas(c) >= 0
	_fantome.visible = ok
	_atterrissage.visible = ok
	if not ok:
		return
	var coul: Color = app.materiau_jeton(_joueur).albedo_color
	(_fantome.material_override as StandardMaterial3D).albedo_color = Color(coul, 0.55)
	(_atterrissage.material_override as StandardMaterial3D).albedo_color = Color(coul, 0.25)
	_fantome.position = Vector3(_col_x(c), Y_LACHER, 0)
	_atterrissage.position = Vector3(_col_x(c), _rang_y(_plus_bas(c)), 0)


# ------------------------------------------------------------------ cycle de vie

func entrer() -> void:
	if not _demarre:
		_demarre = true
		_nouvelle_partie()
	elif _tour_ia() and not _occupe:
		_demander_ia()


func sortir() -> void:
	_viser(-1)


func _process(delta: float) -> void:
	_verifier_ia()
	_confettis.mettre_a_jour(delta)
	if _fantome.visible:
		_fantome.position.y = Y_LACHER + sin(Time.get_ticks_msec() * 0.004) * 0.006

	var garder: Array = []
	for a in _anims:
		a.t += delta
		if a.t < 0.0:
			garder.append(a)
			continue
		var k: float = min(1.0, a.t / a.duree)
		var m: Node3D = a.m
		match a.type:
			"pousse":
				m.scale = Vector3.ONE * max(0.001, smoothstep(0.0, 1.0, k))
				if k < 1.0:
					garder.append(a)
			"sortie":
				m.position.y = a.y - smoothstep(0.0, 1.0, k) * 0.1
				m.scale = Vector3.ONE * max(0.001, 1.0 - smoothstep(0.0, 1.0, k))
				if k < 1.0:
					garder.append(a)
				else:
					m.queue_free()
			"vol":
				var e := smoothstep(0.0, 1.0, k)
				m.position = (a.de as Vector3).lerp(a.vers, e) + Vector3(0, sin(PI * k) * 0.12, 0)
				m.quaternion = (a.de_q as Quaternion).slerp(Quaternion.IDENTITY, e)
				if k < 1.0:
					garder.append(a)
				else:
					a.type = "chute"
					a.v = 0.0
					a.rebonds = 0
					m.quaternion = Quaternion.IDENTITY
					garder.append(a)
			"chute":
				a.v -= GRAVITE * delta
				m.position.y += a.v * delta
				var cible := _rang_y(a.r)
				if m.position.y <= cible:
					m.position.y = cible
					var vitesse: float = -a.v
					if a.rebonds == 0:
						app.sons.jouer_a("clac", m.global_position, linear_to_db(clampf(0.4 + vitesse * 0.4, 0.2, 1.0)))
					if vitesse > 0.35 and a.rebonds < 2:
						a.v = vitesse * 0.28
						a.rebonds += 1
						garder.append(a)
					else:
						_pose(a)
				else:
					garder.append(a)
	_anims = garder

	if _fini and not _ligne_gagnante.is_empty():
		_t_victoire += delta
		var lueur := maxf(0.0, 0.35 + sin(_t_victoire * 6.0) * 0.3)
		for m in _ligne_gagnante:
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.82, 0.48)
			mat.emission_energy_multiplier = lueur


class Cible:
	extends RefCounted
	var _survol: Callable
	var _choix: Callable

	func _init(s: Callable, c: Callable) -> void:
		_survol = s
		_choix = c

	func survol(on: bool) -> void:
		_survol.call(on)

	func choisir() -> void:
		_choix.call()
