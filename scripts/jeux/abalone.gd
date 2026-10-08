extends "res://scripts/jeux/table_jeu.gd"
## Abalone sur la table du salon : plateau hexagonal, 14 billes par joueur.
## Jouer : toucher 1 à 3 de ses billes alignées, puis une flèche dorée (direction).

const IA := preload("res://scripts/jeux/abalone_ia.gd")
const Formes := preload("res://scripts/formes.gd")

const CELL := 0.054
const R_BILLE := 0.021
const EP := 0.03
const TOP := EP
const Y_BILLE := TOP + R_BILLE - 0.007
const CENTRE := Vector3(0, 0, 0.04)
const RAYON_HEX := 0.285
const DUREE_GLISSE := 0.38

const NIVEAUX := [
	{"nom": "Facile", "prof": 1, "hasard": 0.4, "temps": 300},
	{"nom": "Moyen", "prof": 2, "hasard": 0.0, "temps": 600},
	{"nom": "Difficile", "prof": 6, "hasard": 0.0, "temps": 1800},
]

var _b := PackedByteArray()
var _noeuds: Array = []
var _sorties := {1: [], 2: []}
var _sel: Array = []
var _coups_possibles: Array = []
var _fleches: Array = []
var _anneaux: Array[MeshInstance3D] = []
var _fantomes: Array[MeshInstance3D] = []
var _coups := 0
var _en_mouvement := 0
var _fleche_visee := -1

var _geo_bille: SphereMesh
var _mat_noir: StandardMaterial3D
var _mat_blanc: StandardMaterial3D
var _mat_fantome := {}
var _mat_fleche: StandardMaterial3D
var _mat_fleche_vise: StandardMaterial3D
var _mat_fleche_rouge: StandardMaterial3D
var _mat_fleche_rouge_vise: StandardMaterial3D
var _mat_sel := {}


func _init(p_app) -> void:
	super()
	app = p_app
	IA.preparer()


func _ready() -> void:
	_geo_bille = SphereMesh.new()
	_geo_bille.radius = R_BILLE
	_geo_bille.height = R_BILLE * 2.0
	_geo_bille.radial_segments = 24
	_geo_bille.rings = 12
	_mat_noir = StandardMaterial3D.new()
	_mat_noir.albedo_color = Color(0.03, 0.03, 0.035)
	_mat_noir.roughness = 0.1
	_mat_noir.metallic_specular = 0.8
	_mat_blanc = StandardMaterial3D.new()
	_mat_blanc.albedo_color = Color(0.92, 0.9, 0.86)
	_mat_blanc.roughness = 0.14
	_mat_blanc.metallic_specular = 0.7
	for j in [1, 2]:
		var sm := (_mat_noir if j == 1 else _mat_blanc).duplicate() as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = Color(0.95, 0.66, 0.28)
		sm.emission_energy_multiplier = 0.22 if j == 1 else 0.18
		_mat_sel[j] = sm
	for j in [1, 2]:
		var m := (_mat_noir if j == 1 else _mat_blanc).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.45
		_mat_fantome[j] = m
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
	return 0.48


func _partie_entamee() -> bool:
	return _coups > 0


func _maj_statut(sous := "") -> void:
	if sous == "" and _b.size() == 61:
		var n := ["Vous", "Ordinateur"] if _mode == "ia" else ["Noir", "Blanc"]
		sous = "Sorties : %s %d · %s %d (sur 6)" % [n[0], _sorties[1].size(), n[1], _sorties[2].size()]
		if not _tour_ia():
			sous += "  —  vos billes, puis une flèche (rouge = éjection)"
	super(sous)


# ------------------------------------------------------------------ géométrie

func _pos_case(i: int) -> Vector3:
	var c: Vector2i = IA.CASES[i]
	return CENTRE + Vector3(CELL * (c.x + c.y / 2.0), Y_BILLE, CELL * c.y * sqrt(3.0) / 2.0)


func _vec_dir(d: int) -> Vector3:
	var v: Vector2i = IA.DIRS[d]
	return Vector3(CELL * (v.x + v.y / 2.0), 0, CELL * v.y * sqrt(3.0) / 2.0)


func _pos_sortie(j: int, k: int) -> Vector3:
	var cote := 1.0 if j == 1 else -1.0
	return Vector3(cote * 0.43, 0.004 + R_BILLE, 0.16 - k * 0.046)


# ------------------------------------------------------------------ construction

func _construire_plateau() -> void:
	var bois := ShaderMaterial.new()
	bois.shader = preload("res://shaders/abalone_plateau.gdshader")
	bois.set_shader_parameter("cell", CELL)
	var creux := StandardMaterial3D.new()
	creux.albedo_color = Color(0.035, 0.037, 0.042)
	creux.roughness = 0.4
	var csg := CSGCombiner3D.new()
	csg.position = CENTRE
	add_child(csg)
	var hexa := CSGCylinder3D.new()
	hexa.radius = RAYON_HEX
	hexa.height = EP
	hexa.sides = 6
	hexa.position = Vector3(0, EP / 2.0, 0)
	hexa.material = bois
	csg.add_child(hexa)
	for i in 61:
		var s := CSGSphere3D.new()
		s.radius = 0.02
		s.radial_segments = 16
		s.rings = 8
		s.operation = CSGShape3D.OPERATION_SUBTRACTION
		s.material = creux
		s.position = _pos_case(i) - CENTRE
		s.position.y = TOP + 0.02 - 0.006
		csg.add_child(s)
	# Filet de laiton autour
	var laiton := StandardMaterial3D.new()
	laiton.albedo_color = Color(0.78, 0.6, 0.33)
	laiton.metallic = 1.0
	laiton.roughness = 0.3
	var bord := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = RAYON_HEX + 0.004
	cy.bottom_radius = RAYON_HEX + 0.004
	cy.height = 0.008
	cy.radial_segments = 6
	cy.cap_top = false
	cy.cap_bottom = false
	bord.mesh = cy
	bord.material_override = laiton
	bord.position = CENTRE + Vector3(0, EP - 0.004, 0)
	bord.rotation.y = PI / 6.0
	add_child(bord)

	# Anneaux de sélection, zones, fantômes et flèches
	var anneau_mat := StandardMaterial3D.new()
	anneau_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	anneau_mat.albedo_color = Color(1.0, 0.82, 0.4)
	var tore := TorusMesh.new()
	tore.inner_radius = 0.021
	tore.outer_radius = 0.025
	tore.rings = 32
	tore.ring_segments = 6
	for i in 61:
		var a := MeshInstance3D.new()
		a.mesh = tore
		a.material_override = anneau_mat
		a.position = Vector3(_pos_case(i).x, TOP + 0.002, _pos_case(i).z)
		a.scale = Vector3(1, 0.4, 1)
		a.visible = false
		a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(a)
		_anneaux.append(a)
		var idx := i
		UI.zone(self, Vector3(0.048, 0.05, 0.048), Vector3(_pos_case(i).x, TOP + 0.012, _pos_case(i).z),
				Cible.new(func(_on: bool): pass, func(): _toucher_case(idx)))
	for k in 5:
		var f := MeshInstance3D.new()
		f.mesh = _geo_bille
		f.visible = false
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		_fantomes.append(f)

	_mat_fleche = StandardMaterial3D.new()
	_mat_fleche.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_fleche.albedo_color = Color(0.9, 0.72, 0.35)
	_mat_fleche_vise = _mat_fleche.duplicate()
	_mat_fleche_vise.albedo_color = Color(1.0, 0.93, 0.65)
	_mat_fleche_rouge = _mat_fleche.duplicate()
	_mat_fleche_rouge.albedo_color = Color(0.85, 0.16, 0.12)
	_mat_fleche_rouge_vise = _mat_fleche.duplicate()
	_mat_fleche_rouge_vise.albedo_color = Color(1.0, 0.4, 0.3)
	var prisme := Formes.fleche(0.036, 0.03, 0.007)
	for d in 6:
		var porte := Node3D.new()
		add_child(porte)
		var mi := MeshInstance3D.new()
		mi.mesh = prisme
		mi.material_override = _mat_fleche
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		porte.add_child(mi)
		var dd := d
		var corps := UI.zone(porte, Vector3(0.042, 0.03, 0.042), Vector3.ZERO,
				Cible.new(func(on: bool): _viser_fleche(dd if on else (-1 if _fleche_visee == dd else _fleche_visee)),
				func(): _choisir_fleche(dd)))
		porte.visible = false
		corps.collision_layer = 0
		_fleches.append({"porte": porte, "mesh": mi, "corps": corps, "coup": {}})


func _nouvelle_bille(j: int, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _geo_bille
	m.material_override = _mat_noir if j == 1 else _mat_blanc
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(m)
	return m


# ------------------------------------------------------------------ déroulement

func _preparer_partie() -> void:
	var anciennes: Array = []
	for n in _noeuds:
		if n:
			anciennes.append(n)
	for j in [1, 2]:
		anciennes.append_array(_sorties[j])
	var restes: Array = []
	for a in _anims:
		if a.type == "sortie":
			restes.append(a)
	_anims = restes
	_faire_sortir(anciennes)
	_b = IA.depart()
	_noeuds = []
	_noeuds.resize(61)
	_sorties = {1: [], 2: []}
	_sel = []
	_coups = 0
	_en_mouvement = 0
	var n := 0
	for i in 61:
		if _b[i] != 0:
			var m := _nouvelle_bille(_b[i], _pos_case(i))
			_noeuds[i] = m
			_faire_apparaitre(m, 0.05 + n * 0.012)
			n += 1
	_maj_selection()


func _debut_tour() -> void:
	_occupe = false
	_sel = []
	_maj_statut()
	_maj_selection()
	if _tour_ia():
		_demander_ia()


func _humain_peut_jouer() -> bool:
	return not _occupe and not _fini and not _tour_ia() and _b.size() == 61


## Sélection : toucher ses billes (1 à 3, alignées et contiguës).
func _toucher_case(i: int) -> void:
	if not _humain_peut_jouer():
		return
	if _b[i] != _joueur:
		if not _sel.is_empty():
			_sel = []
			_maj_selection()
		return
	if _sel.has(i):
		_sel.erase(i)
		if not _ligne_valide(_sel):
			_sel = []
	else:
		var essai: Array = _sel + [i]
		# Combler un trou d'une case si une de nos billes s'y trouve
		if _sel.size() == 1:
			var a: int = _sel[0]
			for d in 6:
				var mid := IA.VOISIN[a * 6 + d]
				if mid >= 0 and IA.VOISIN[mid * 6 + d] == i and _b[mid] == _joueur:
					essai = [a, mid, i]
		_sel = essai if _ligne_valide(essai) else [i]
	app.sons.jouer("survol")
	_maj_selection()


func _ligne_valide(l: Array) -> bool:
	if l.size() <= 1:
		return true
	if l.size() > 3:
		return false
	for d in 3:
		for depart in l:
			var ok := true
			var k: int = depart
			var vus := 1
			while vus < l.size():
				k = IA.VOISIN[k * 6 + d]
				if k < 0 or not l.has(k):
					ok = false
					break
				vus += 1
			if ok:
				return true
	return false


func _meme_ensemble(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


func _maj_selection() -> void:
	for i in 61:
		_anneaux[i].visible = _sel.has(i)
		var n: MeshInstance3D = _noeuds[i] if _noeuds.size() == 61 else null
		if n:
			var j := _b[i]
			n.material_override = _mat_sel[j] if _sel.has(i) else (_mat_noir if j == 1 else _mat_blanc)
	_coups_possibles = []
	if _humain_peut_jouer() and not _sel.is_empty():
		for m in IA.coups(_b, _joueur):
			if _meme_ensemble(m.billes, _sel):
				_coups_possibles.append(m)
	for d in 6:
		var f: Dictionary = _fleches[d]
		f.coup = {}
		for m in _coups_possibles:
			if m.dir == d:
				f.coup = m
		var actif: bool = not f.coup.is_empty()
		(f.porte as Node3D).visible = actif
		(f.corps as StaticBody3D).collision_layer = UI.COUCHE_CIBLES if actif else 0
		if actif:
			var centre := Vector3.ZERO
			for x in _sel:
				centre += _pos_case(x)
			centre /= _sel.size()
			var v := _vec_dir(d)
			var avance := 0.0
			if _sel.size() > 1 and not _ligne_de_cote(f.coup):
				avance = (_sel.size() - 1) * 0.5
			(f.porte as Node3D).position = Vector3(centre.x, TOP + 0.055, centre.z) + v * (1.1 + avance)
			(f.mesh as Node3D).rotation.y = atan2(v.x, v.z)
	_fleche_visee = -1
	_colorer_fleches()
	_maj_fantomes()


func _ligne_de_cote(m: Dictionary) -> bool:
	if m.billes.size() < 2:
		return false
	var a: int = m.billes[0]
	var b: int = m.billes[1]
	var d: int = m.dir
	return IA.VOISIN[a * 6 + d] != b and IA.VOISIN[b * 6 + d] != a


func _viser_fleche(d: int) -> void:
	_fleche_visee = d
	_colorer_fleches()
	_maj_fantomes()


## Or pour un déplacement, rouge quand le coup éjecte une bille adverse.
func _colorer_fleches() -> void:
	for k in 6:
		var f: Dictionary = _fleches[k]
		var rouge: bool = not f.coup.is_empty() and f.coup.sortie
		var vise := k == _fleche_visee
		var mat := _mat_fleche
		if rouge:
			mat = _mat_fleche_rouge_vise if vise else _mat_fleche_rouge
		elif vise:
			mat = _mat_fleche_vise
		(f.mesh as MeshInstance3D).material_override = mat


func _maj_fantomes() -> void:
	for f in _fantomes:
		f.visible = false
	if _fleche_visee < 0:
		return
	var m: Dictionary = _fleches[_fleche_visee].coup
	if m.is_empty():
		return
	var v := _vec_dir(m.dir)
	var n := 0
	for x in m.billes:
		_fantomes[n].material_override = _mat_fantome[_joueur]
		_fantomes[n].position = _pos_case(x) + v
		_fantomes[n].visible = true
		n += 1
	for x in m.pousse:
		_fantomes[n].material_override = _mat_fantome[3 - _joueur]
		_fantomes[n].position = _pos_case(x) + v + (Vector3(0, -0.03, 0) if IA.VOISIN[x * 6 + m.dir] < 0 else Vector3.ZERO)
		_fantomes[n].visible = true
		n += 1


func _choisir_fleche(d: int) -> void:
	if not _humain_peut_jouer():
		return
	var m: Dictionary = _fleches[d].coup
	if m.is_empty():
		return
	app.sons.jouer("clic")
	_jouer(m)


func _jouer(m: Dictionary) -> void:
	_occupe = true
	_sel = []
	_fleche_visee = -1
	_maj_selection()
	var p := _joueur
	var d: int = m.dir
	var v := _vec_dir(d)
	var nouveaux := _noeuds.duplicate()
	for x in m.pousse:
		nouveaux[x] = null
	for x in m.billes:
		nouveaux[x] = null
	_en_mouvement = 0
	for x in m.pousse:
		var t := IA.VOISIN[x * 6 + d]
		var n: Node3D = _noeuds[x]
		if t < 0:
			var place := _pos_sortie(p, _sorties[p].size())
			_sorties[p].append(n)
			_anims.append({"type": "ejecte", "t": 0.0, "duree": DUREE_GLISSE + 0.55, "m": n, "partie": _partie,
				"de": n.position, "bord": n.position + v * 1.2, "vers": place})
		else:
			nouveaux[t] = n
			_anims.append({"type": "glisse", "t": 0.0, "duree": DUREE_GLISSE, "m": n, "partie": _partie,
				"de": n.position, "vers": _pos_case(t)})
		_en_mouvement += 1
	for x in m.billes:
		var t2 := IA.VOISIN[x * 6 + d]
		var n2: Node3D = _noeuds[x]
		nouveaux[t2] = n2
		_anims.append({"type": "glisse", "t": 0.0, "duree": DUREE_GLISSE, "m": n2, "partie": _partie,
			"de": n2.position, "vers": _pos_case(t2)})
		_en_mouvement += 1
	_noeuds = nouveaux
	IA.appliquer(_b, p, m)
	_coups += 1
	if not m.pousse.is_empty():
		app.sons.jouer_a("clac", _pos_case(m.pousse[0]) + position)
	else:
		app.sons.jouer_a("souffle", _pos_case(m.billes[0]) + position, -14.0)


func _apres_coup() -> void:
	_maj_statut()
	if _b.count(3 - _joueur) <= 14 - IA.SORTIES_GAGNANTES:
		_terminer()
		return
	if _coups >= 300:
		_terminer()
		return
	_joueur = 3 - _joueur
	if IA.coups(_b, _joueur).is_empty():
		_terminer()
		return
	_debut_tour()


func _terminer() -> void:
	var s1: int = _sorties[1].size()
	var s2: int = _sorties[2].size()
	var g := 0
	if s1 > s2:
		g = 1
	elif s2 > s1:
		g = 2
	var n := ["Vous", "Ordinateur"] if _mode == "ia" else ["Noir", "Blanc"]
	_annoncer_fin(g, "Billes sorties : %s %d  –  %d %s" % [n[0], s1, s2, n[1]])
	_maj_selection()
	if g != 0 and not (_mode == "ia" and g == 2):
		_confettis.lancer(CENTRE + Vector3(0, 0.06, 0))


# ------------------------------------------------------------------ IA

func _lancer_ia() -> Array:
	var nv: Dictionary = NIVEAUX[_niveau]
	var ia := IA.new()
	return [ia, ia.choisir.bind(_b.duplicate(), 2, nv.prof, nv.hasard, nv.temps)]


func _coup_ia(m) -> void:
	if (m as Dictionary).is_empty():
		_terminer()
		return
	# Montre d'abord les billes que l'ordinateur va déplacer.
	_occupe = true
	for x in m.billes:
		_anneaux[x].visible = true
	_anims.append({"type": "annonce", "t": 0.0, "duree": 0.7, "m": self, "partie": _partie, "coup": m})


func sortir() -> void:
	_viser_fleche(-1)


# ------------------------------------------------------------------ animations

func _anim(a: Dictionary, k: float, _delta: float) -> bool:
	if a.has("partie") and a.partie != _partie:
		return false
	match a.type:
		"annonce":
			if k < 1.0:
				return true
			for i in 61:
				_anneaux[i].visible = false
			_jouer(a.coup)
			return false
		"glisse":
			var m: Node3D = a.m
			var e := smoothstep(0.0, 1.0, k)
			var avant := m.position
			m.position = (a.de as Vector3).lerp(a.vers, e)
			_rouler(m, m.position - avant)
			if k < 1.0:
				return true
			_fin_mouvement()
			return false
		"ejecte":
			var m2: Node3D = a.m
			var t: float = a.t
			var avant2 := m2.position
			if t < DUREE_GLISSE:
				var e2 := smoothstep(0.0, 1.0, t / DUREE_GLISSE)
				m2.position = (a.de as Vector3).lerp(a.bord, e2)
			else:
				var u := clampf((t - DUREE_GLISSE) / 0.55, 0.0, 1.0)
				m2.position = (a.bord as Vector3).lerp(a.vers, smoothstep(0.0, 1.0, u)) + Vector3(0, sin(PI * u) * 0.08, 0)
			_rouler(m2, m2.position - avant2)
			if k < 1.0:
				return true
			app.sons.jouer_a("clac", m2.global_position, -6.0)
			_fin_mouvement()
			return false
	return false


func _rouler(m: Node3D, deplacement: Vector3) -> void:
	var dist := Vector2(deplacement.x, deplacement.z).length()
	if dist < 0.00001:
		return
	var axe := Vector3(deplacement.z, 0, -deplacement.x).normalized()
	m.rotate(axe, dist / R_BILLE)


func _fin_mouvement() -> void:
	_en_mouvement -= 1
	if _en_mouvement == 0:
		_apres_coup()


func _mettre_a_jour(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.004
	for f in _fleches:
		if (f.porte as Node3D).visible:
			(f.mesh as Node3D).position.y = sin(t) * 0.004
