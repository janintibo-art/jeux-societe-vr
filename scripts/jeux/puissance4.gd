extends "res://scripts/jeux/table_jeu.gd"
## Puissance 4 sur la table du salon : contre l'ordinateur (3 niveaux) ou à deux.

const Formes := preload("res://scripts/formes.gd")
const IA := preload("res://scripts/jeux/puissance4_ia.gd")

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

var _plateau: Node3D
var _jeton_geo: ArrayMesh
var _fantome: MeshInstance3D
var _atterrissage: MeshInstance3D
var _grille: Array = []
var _cases: Array = []
var _piles := {1: [], 2: []}
var _coups := 0
var _colonne_visee := -1
var _ligne_gagnante: Array = []
var _t_victoire := 0.0


func _init(p_app) -> void:
	super()
	app = p_app


func _ready() -> void:
	_jeton_geo = Formes.jeton(JETON_R, JETON_E)
	_construire_plateau()
	_construire_interface()


# ------------------------------------------------------------------ redéfinitions

func _niveaux() -> Array:
	return NIVEAUX


func _noms() -> Dictionary:
	return {1: "Rouge", 2: "Jaune"}


func _materiau_joueur(j: int) -> Material:
	return app.materiau_jeton(j)


func _forme_pastille() -> Mesh:
	return _jeton_geo


func _echelle_pastille() -> float:
	return 0.4


func _aide() -> String:
	return "Visez une colonne et appuyez sur la gâchette"


func _y_bandeau() -> float:
	return HAUT + 0.16


func _partie_entamee() -> bool:
	return _coups > 0


# ------------------------------------------------------------------ construction

func _construire_plateau() -> void:
	_plateau = Node3D.new()
	_plateau.position = Vector3(0, 0, -0.06)
	add_child(_plateau)
	var bleu := StandardMaterial3D.new()
	bleu.albedo_color = Color(0.07, 0.24, 0.75)
	bleu.roughness = 0.22
	bleu.metallic_specular = 0.7
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


func _pos_pile(joueur: int, i: int) -> Vector3:
	var cote := -1.0 if joueur == 1 else 1.0
	var tas := i / 7
	var k := i % 7
	var dec: Vector2 = [Vector2(0, 0), Vector2(0.072, 0.02), Vector2(0.036, -0.045)][tas]
	return Vector3(cote * (0.4 + dec.x), 0.003 + JETON_E / 2.0 + k * (JETON_E + 0.0004), 0.1 + dec.y)


# ------------------------------------------------------------------ déroulement

func _preparer_partie() -> void:
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
	_faire_sortir(anciens)

	_grille = []
	_cases = []
	for c in COLS:
		_grille.append([0, 0, 0, 0, 0, 0])
		_cases.append([null, null, null, null, null, null])
	_coups = 0
	_ligne_gagnante = []
	_piles = {1: [], 2: []}
	for j in [1, 2]:
		for i in 21:
			var m := MeshInstance3D.new()
			m.mesh = _jeton_geo
			m.material_override = app.materiau_jeton(j)
			m.position = _pos_pile(j, i)
			m.rotation = Vector3(-PI / 2.0, 0, randf() * TAU)
			add_child(m)
			_piles[j].append(m)
			_faire_apparaitre(m, i * 0.015)
	_maj_fantome()


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
	_annoncer_fin(gagnant, "" if gagnant != 0 else "Le plateau est plein")
	_maj_fantome()
	if gagnant == 0:
		return
	_ligne_gagnante = []
	for p in ligne:
		_ligne_gagnante.append(_cases[p.x][p.y])
	_t_victoire = 0.0
	if not (_mode == "ia" and gagnant == 2):
		var centre := Vector3.ZERO
		for m in _ligne_gagnante:
			centre += (m as Node3D).position
		_confettis.lancer(centre / _ligne_gagnante.size() + _plateau.position)


# ------------------------------------------------------------------ IA

func _lancer_ia() -> Array:
	var plateau := PackedByteArray()
	plateau.resize(COLS * ROWS)
	for c in COLS:
		for r in ROWS:
			plateau[c * ROWS + r] = _grille[c][r]
	var nv: Dictionary = NIVEAUX[_niveau]
	var ia := IA.new()
	return [ia, ia.choisir.bind(plateau, 2, nv.prof, nv.hasard, nv.temps)]


func _coup_ia(col) -> void:
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


func sortir() -> void:
	_viser(-1)


# ------------------------------------------------------------------ animations

func _anim(a: Dictionary, k: float, delta: float) -> bool:
	var m: Node3D = a.m
	match a.type:
		"vol":
			var e := smoothstep(0.0, 1.0, k)
			m.position = (a.de as Vector3).lerp(a.vers, e) + Vector3(0, sin(PI * k) * 0.12, 0)
			m.quaternion = (a.de_q as Quaternion).slerp(Quaternion.IDENTITY, e)
			if k >= 1.0:
				a.type = "chute"
				a.v = 0.0
				a.rebonds = 0
				m.quaternion = Quaternion.IDENTITY
			return true
		"chute":
			a.v -= GRAVITE * delta
			m.position.y += a.v * delta
			var cible := _rang_y(a.r)
			if m.position.y > cible:
				return true
			m.position.y = cible
			var vitesse: float = -a.v
			if a.rebonds == 0:
				app.sons.jouer_a("clac", m.global_position, linear_to_db(clampf(0.4 + vitesse * 0.4, 0.2, 1.0)))
			if vitesse > 0.35 and a.rebonds < 2:
				a.v = vitesse * 0.28
				a.rebonds += 1
				return true
			_pose(a)
			return false
	return false


func _mettre_a_jour(delta: float) -> void:
	if _fantome.visible:
		_fantome.position.y = Y_LACHER + sin(Time.get_ticks_msec() * 0.004) * 0.006
	if _fini and not _ligne_gagnante.is_empty():
		_t_victoire += delta
		var lueur := maxf(0.0, 0.35 + sin(_t_victoire * 6.0) * 0.3)
		for m in _ligne_gagnante:
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.82, 0.48)
			mat.emission_energy_multiplier = lueur

