extends "res://scripts/jeux/table_jeu.gd"
## Reversi (Othello) sur la table du salon : contre l'ordinateur (3 niveaux) ou à deux.
## Noir (joueur 1) commence. Les coups possibles sont marqués d'un point doré.

const Formes := preload("res://scripts/formes.gd")
const IA := preload("res://scripts/jeux/reversi_ia.gd")

const N := 8
const CELL := 0.058
const BORD := 0.035
const COTE := N * CELL + 2 * BORD
const EP := 0.03
const Y_SURF := EP + 0.0006
const PION_R := 0.0245
const PION_H := 0.0045
const Y_PION := Y_SURF + PION_H
const CENTRE := Vector3(0, 0, 0.03)
const GRAVITE := 6.5

const NIVEAUX := [
	{"nom": "Facile", "prof": 1, "hasard": 0.35, "temps": 300},
	{"nom": "Moyen", "prof": 2, "hasard": 0.0, "temps": 500},
	{"nom": "Difficile", "prof": 12, "hasard": 0.0, "temps": 1500},
]

var _b := PackedByteArray()
var _pions: Array = []
var _reserves := {1: [], 2: []}
var _marques: Array[MeshInstance3D] = []
var _fantome: Node3D
var _case_visee := -1
var _a_retourner := 0

var _geo_haut: ArrayMesh
var _geo_bas: ArrayMesh
var _mat_noir: StandardMaterial3D
var _mat_blanc: StandardMaterial3D


func _init(p_app) -> void:
	super()
	app = p_app


func _ready() -> void:
	_preparer_materiaux()
	_construire_plateau()
	_construire_interface()


# ------------------------------------------------------------------ redéfinitions

func _niveaux() -> Array:
	return NIVEAUX


func _noms() -> Dictionary:
	return {1: "Noir", 2: "Blanc"}


func _materiau_joueur(j: int) -> Material:
	return _mat_noir if j == 1 else _mat_blanc


func _y_bandeau() -> float:
	return 0.5


func _partie_entamee() -> bool:
	return _b.size() == 64 and _b.count(0) < 60


func _maj_statut(sous := "") -> void:
	if sous == "" and _b.size() == 64:
		sous = "Noir %d  ·  Blanc %d" % [_b.count(1), _b.count(2)]
		if not _tour_ia():
			sous += "   —   visez un point doré"
	super(sous)


# ------------------------------------------------------------------ construction

func _preparer_materiaux() -> void:
	var t := PION_H
	var r := PION_R
	_geo_haut = Formes.tour([Vector2(0, 0), Vector2(r, 0), Vector2(r, t * 0.55), Vector2(r * 0.9, t), Vector2(0, t)], 40)
	_geo_bas = Formes.tour([Vector2(0, -t), Vector2(r * 0.9, -t), Vector2(r, -t * 0.55), Vector2(r, 0), Vector2(0, 0)], 40)
	_mat_noir = StandardMaterial3D.new()
	_mat_noir.albedo_color = Color(0.035, 0.035, 0.04)
	_mat_noir.roughness = 0.22
	_mat_noir.metallic_specular = 0.7
	_mat_blanc = StandardMaterial3D.new()
	_mat_blanc.albedo_color = Color(0.93, 0.91, 0.86)
	_mat_blanc.roughness = 0.3
	_mat_blanc.metallic_specular = 0.6


func _construire_plateau() -> void:
	var socle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(COTE, EP, COTE)
	socle.mesh = bm
	var bois := ShaderMaterial.new()
	bois.shader = preload("res://shaders/bois.gdshader")
	bois.set_shader_parameter("couleur", Color(0.3, 0.15, 0.07))
	bois.set_shader_parameter("echelle", 9.0)
	bois.set_shader_parameter("brillance", 0.25)
	socle.material_override = bois
	socle.position = CENTRE + Vector3(0, EP / 2.0, 0)
	socle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(socle)
	var drap := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(N * CELL, N * CELL)
	drap.mesh = pm
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://shaders/reversi_plateau.gdshader")
	drap.material_override = dm
	drap.position = CENTRE + Vector3(0, EP + 0.0005, 0)
	add_child(drap)
	# Filet de laiton autour du drap
	var laiton := StandardMaterial3D.new()
	laiton.albedo_color = Color(0.78, 0.6, 0.33)
	laiton.metallic = 1.0
	laiton.roughness = 0.3
	var l := N * CELL + 0.008
	for s in [-1.0, 1.0]:
		for axe in 2:
			var f := MeshInstance3D.new()
			var fb := BoxMesh.new()
			fb.size = Vector3(l, 0.003, 0.004) if axe == 0 else Vector3(0.004, 0.003, l)
			f.mesh = fb
			f.material_override = laiton
			var dec: float = s * (N * CELL / 2.0 + 0.004)
			f.position = CENTRE + Vector3(0 if axe == 0 else dec, EP + 0.0015, dec if axe == 0 else 0)
			add_child(f)

	# Zones visables et points des coups possibles
	var marque_mat := StandardMaterial3D.new()
	marque_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marque_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marque_mat.albedo_color = Color(0.95, 0.78, 0.38, 0.75)
	var marque_geo := CylinderMesh.new()
	marque_geo.top_radius = 0.0095
	marque_geo.bottom_radius = 0.0095
	marque_geo.height = 0.0008
	marque_geo.radial_segments = 20
	for i in 64:
		var idx := i
		var cible := Cible.new(func(on: bool): _viser(idx if on else (-1 if _case_visee == idx else _case_visee)),
				func(): _jouer_humain(idx))
		UI.zone(self, Vector3(CELL, 0.02, CELL), _pos_case(i) + Vector3(0, 0.005, 0), cible)
		var mq := MeshInstance3D.new()
		mq.mesh = marque_geo
		mq.material_override = marque_mat
		mq.position = Vector3(_pos_case(i).x, Y_SURF + 0.0006, _pos_case(i).z)
		mq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mq.visible = false
		add_child(mq)
		_marques.append(mq)

	_fantome = Node3D.new()
	var fn := _mat_noir.duplicate() as StandardMaterial3D
	var fb2 := _mat_blanc.duplicate() as StandardMaterial3D
	for m in [fn, fb2]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.55
	var h := MeshInstance3D.new()
	h.mesh = _geo_haut
	h.material_override = fb2
	var b := MeshInstance3D.new()
	b.mesh = _geo_bas
	b.material_override = fn
	_fantome.add_child(h)
	_fantome.add_child(b)
	_fantome.visible = false
	add_child(_fantome)


func _creer_pion(proprio: int) -> Node3D:
	var p := Node3D.new()
	var h := MeshInstance3D.new()
	h.mesh = _geo_haut
	h.material_override = _mat_blanc
	var b := MeshInstance3D.new()
	b.mesh = _geo_bas
	b.material_override = _mat_noir
	for m in [h, b]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		p.add_child(m)
	p.rotation = Vector3(PI if proprio == 1 else 0.0, randf() * TAU, 0)
	add_child(p)
	return p


func _pos_case(i: int) -> Vector3:
	var c := i % N
	var r := i / N
	return CENTRE + Vector3((c - 3.5) * CELL, Y_PION, (r - 3.5) * CELL)


func _pos_reserve(j: int, i: int) -> Vector3:
	var cote := -1.0 if j == 1 else 1.0
	var tas := i / 15
	var k := i % 15
	return Vector3(cote * (0.34 + tas * 0.056), 0.003 + PION_H + k * (2.0 * PION_H + 0.0005), 0.1 - tas * 0.03)


# ------------------------------------------------------------------ déroulement

func _preparer_partie() -> void:
	var anciens: Array = []
	for p in _pions:
		if p:
			anciens.append(p)
	for j in [1, 2]:
		for p in _reserves[j]:
			anciens.append(p)
	var restes: Array = []
	for a in _anims:
		if a.type == "sortie":
			restes.append(a)
	_anims = restes
	_faire_sortir(anciens)

	_b = PackedByteArray()
	_b.resize(64)
	_pions = []
	_pions.resize(64)
	_a_retourner = 0
	var depart_pions := {27: 2, 36: 2, 28: 1, 35: 1}
	var n := 0
	for i in depart_pions:
		var j: int = depart_pions[i]
		_b[i] = j
		var p := _creer_pion(j)
		p.position = _pos_case(i)
		_pions[i] = p
		_faire_apparaitre(p, n * 0.05)
		n += 1
	_reserves = {1: [], 2: []}
	for j in [1, 2]:
		for i in 30:
			var p := _creer_pion(j)
			p.position = _pos_reserve(j, i)
			_reserves[j].append(p)
			_faire_apparaitre(p, 0.2 + i * 0.012)
	_maj_marques()
	_maj_fantome()


func _debut_tour() -> void:
	var mes := IA.coups(_b, _joueur)
	if mes.is_empty():
		if IA.coups(_b, 3 - _joueur).is_empty():
			_terminer()
			return
		_occupe = true
		_maj_marques()
		_maj_fantome()
		var qui: String = _noms()[_joueur]
		var texte := "%s passe son tour" % qui
		if _mode == "ia":
			texte = "Vous passez votre tour" if _joueur == 1 else "L’ordinateur passe son tour"
		_ecrire_statut(texte, _joueur, "Aucun coup possible")
		app.sons.jouer("refus")
		_anims.append({"type": "attente", "t": 0.0, "duree": 1.8, "m": self, "partie": _partie})
		return
	_occupe = false
	_maj_statut()
	_maj_marques()
	_maj_fantome()
	if _tour_ia():
		_demander_ia()


func _jouer_humain(i: int) -> void:
	if _occupe or _fini or _tour_ia():
		return
	if not IA.legal(_b, i, _joueur):
		app.sons.jouer("refus")
		return
	_jouer(i)


func _jouer(i: int) -> void:
	var j := _joueur
	var retour := IA.retournes(_b, i, j)
	if retour.is_empty():
		return
	_occupe = true
	_b[i] = j
	for k in retour:
		_b[k] = j
	_maj_marques()
	_maj_fantome()
	var p: Node3D = _reserves[j].pop_back() if not _reserves[j].is_empty() else _creer_pion(j)
	p.scale = Vector3.ONE
	_pions[i] = p
	var cible := _pos_case(i)
	_anims.append({
		"type": "vol", "t": 0.0, "duree": 0.45, "m": p, "partie": _partie, "i": i, "retour": retour,
		"de": p.position, "vers": cible + Vector3(0, 0.05, 0),
	})
	app.sons.jouer_a("souffle", p.global_position, -12.0)


func _lancer_retournements(a: Dictionary) -> void:
	var i: int = a.i
	var retour: PackedInt32Array = a.retour
	var c0 := Vector2(i % N, i / N)
	var liste: Array = Array(retour)
	liste.sort_custom(func(x, y): return c0.distance_to(Vector2(x % N, x / N)) < c0.distance_to(Vector2(y % N, y / N)))
	_a_retourner = liste.size()
	for n in liste.size():
		var k: int = liste[n]
		var d := c0.distance_to(Vector2(k % N, k / N))
		var p: Node3D = _pions[k]
		_anims.append({"type": "retourne", "t": -0.05 - d * 0.09, "duree": 0.34, "m": p, "partie": a.partie,
			"x0": p.rotation.x})


func _apres_coup() -> void:
	_joueur = 3 - _joueur
	_debut_tour()


func _terminer() -> void:
	var n1 := _b.count(1)
	var n2 := _b.count(2)
	var g := 0
	if n1 > n2:
		g = 1
	elif n2 > n1:
		g = 2
	_annoncer_fin(g, "Noir %d  –  %d Blanc" % [n1, n2])
	_maj_marques()
	_maj_fantome()
	if g != 0 and not (_mode == "ia" and g == 2):
		_confettis.lancer(CENTRE + Vector3(0, 0.05, 0))


# ------------------------------------------------------------------ IA

func _lancer_ia() -> Array:
	var nv: Dictionary = NIVEAUX[_niveau]
	var ia := IA.new()
	return [ia, ia.choisir.bind(_b.duplicate(), 2, nv.prof, nv.hasard, nv.temps)]


func _coup_ia(i) -> void:
	if i < 0:
		_debut_tour()
	else:
		_jouer(i)


# ------------------------------------------------------------------ visée et marques

func _viser(i: int) -> void:
	_case_visee = i
	_maj_fantome()


func _humain_peut_jouer() -> bool:
	return not _occupe and not _fini and not _tour_ia() and _b.size() == 64


func _maj_marques() -> void:
	var montrer := _humain_peut_jouer()
	for i in 64:
		_marques[i].visible = montrer and IA.legal(_b, i, _joueur)


func _maj_fantome() -> void:
	var i := _case_visee
	var ok := i >= 0 and _humain_peut_jouer() and IA.legal(_b, i, _joueur)
	_fantome.visible = ok
	if ok:
		_fantome.position = _pos_case(i) + Vector3(0, 0.02, 0)
		_fantome.rotation = Vector3(PI if _joueur == 1 else 0.0, 0, 0)


func sortir() -> void:
	_viser(-1)


# ------------------------------------------------------------------ animations

func _anim(a: Dictionary, k: float, delta: float) -> bool:
	if a.has("partie") and a.partie != _partie:
		return false
	match a.type:
		"vol":
			var m: Node3D = a.m
			var e := smoothstep(0.0, 1.0, k)
			m.position = (a.de as Vector3).lerp(a.vers, e) + Vector3(0, sin(PI * k) * 0.1, 0)
			if k >= 1.0:
				a.type = "chute"
				a.v = 0.0
			return true
		"chute":
			var m2: Node3D = a.m
			a.v -= GRAVITE * delta
			m2.position.y += a.v * delta
			if m2.position.y > Y_PION:
				return true
			m2.position.y = Y_PION
			app.sons.jouer_a("clac", m2.global_position)
			_lancer_retournements(a)
			return false
		"retourne":
			var m3: Node3D = a.m
			var e3 := smoothstep(0.0, 1.0, k)
			m3.rotation.x = a.x0 + PI * e3
			m3.position.y = Y_PION + sin(PI * k) * 0.035
			if k < 1.0:
				return true
			m3.position.y = Y_PION
			m3.rotation.x = fposmod(a.x0 + PI, TAU)
			app.sons.jouer_a("clac", m3.global_position, -9.0)
			_a_retourner -= 1
			if _a_retourner == 0:
				_apres_coup()
			return false
		"attente":
			if k < 1.0:
				return true
			_joueur = 3 - _joueur
			_debut_tour()
			return false
	return false


func _mettre_a_jour(_delta: float) -> void:
	if _fantome.visible:
		_fantome.position.y = _pos_case(_case_visee).y + 0.02 + sin(Time.get_ticks_msec() * 0.004) * 0.004
