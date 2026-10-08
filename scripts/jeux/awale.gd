extends "res://scripts/jeux/table_jeu.gd"
## Awalé sur la table du salon : tablier de bois à 12 trous et 2 greniers, 48 graines.
## Le joueur 1 (Sud) a la rangée proche ; ses prises vont dans le grenier de droite.

const IA := preload("res://scripts/jeux/awale_ia.gd")

const D := 0.097
const RANG := 0.062
const R_TROU := 0.046
const PROF := 0.023
const EP := 0.055
const PIEDS := 0.018
const TOP := PIEDS + EP
const LONG := 0.84
const LARG := 0.27
const CENTRE := Vector3(0, 0, 0.07)
const X_GRENIER := 0.353
const MONTEE := 0.3
const PAS := 0.2

const NIVEAUX := [
	{"nom": "Facile", "prof": 2, "hasard": 0.3, "temps": 300},
	{"nom": "Moyen", "prof": 5, "hasard": 0.0, "temps": 600},
	{"nom": "Difficile", "prof": 14, "hasard": 0.0, "temps": 1500},
]

var _b := PackedInt32Array()
var _s := PackedInt32Array([0, 0])
var _graines: Array = []
var _greniers := {1: [], 2: []}
var _comptes: Array[Label3D] = []
var _comptes_greniers: Array[Label3D] = []
var _anneaux: Array[MeshInstance3D] = []
var _mat_anneau: StandardMaterial3D
var _mat_anneau_vise: StandardMaterial3D
var _arrivee: MeshInstance3D
var _trou_vise := -1
var _coups := 0
var _sans_prise := 0
var _en_vol := 0

var _geo_graine: SphereMesh
var _mats_graines: Array[StandardMaterial3D] = []
var _mat_sud: StandardMaterial3D
var _mat_nord: StandardMaterial3D


func _init(p_app) -> void:
	super()
	app = p_app


func _ready() -> void:
	_mat_sud = StandardMaterial3D.new()
	_mat_sud.albedo_color = Color(0.86, 0.62, 0.26)
	_mat_sud.roughness = 0.35
	_mat_nord = StandardMaterial3D.new()
	_mat_nord.albedo_color = Color(0.3, 0.17, 0.09)
	_mat_nord.roughness = 0.35
	_geo_graine = SphereMesh.new()
	_geo_graine.radius = 0.0085
	_geo_graine.height = 0.017
	_geo_graine.radial_segments = 12
	_geo_graine.rings = 6
	for c in [Color(0.45, 0.31, 0.18), Color(0.6, 0.48, 0.33), Color(0.33, 0.29, 0.26), Color(0.27, 0.17, 0.1)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.3
		m.metallic_specular = 0.6
		_mats_graines.append(m)
	_construire_tablier()
	_construire_interface()


# ------------------------------------------------------------------ redéfinitions

func _niveaux() -> Array:
	return NIVEAUX


func _noms() -> Dictionary:
	return {1: "Sud", 2: "Nord"}


func _materiau_joueur(j: int) -> Material:
	return _mat_sud if j == 1 else _mat_nord


func _y_bandeau() -> float:
	return 0.45


func _partie_entamee() -> bool:
	return _coups > 0


func _maj_statut(sous := "") -> void:
	if sous == "" and _b.size() == 12:
		var n := ["Vous", "Ordinateur"] if _mode == "ia" else ["Sud", "Nord"]
		sous = "Prises : %s %d  ·  %s %d" % [n[0], _s[0], n[1], _s[1]]
		if not _tour_ia():
			sous += "   —   visez un trou de %s" % ("votre rangée" if _mode == "ia" else ("la rangée proche" if _joueur == 1 else "la rangée du fond"))
	super(sous)


# ------------------------------------------------------------------ construction

func _bois(couleur: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/bois.gdshader")
	m.set_shader_parameter("couleur", couleur)
	m.set_shader_parameter("echelle", 11.0)
	m.set_shader_parameter("brillance", 0.3)
	return m


func _pos_trou(i: int) -> Vector3:
	if i < 6:
		return CENTRE + Vector3((i - 2.5) * D, TOP, RANG)
	return CENTRE + Vector3((2.5 - (i - 6)) * D, TOP, -RANG)


func _pos_grenier(j: int) -> Vector3:
	return CENTRE + Vector3(X_GRENIER if j == 1 else -X_GRENIER, TOP, 0)


func _construire_tablier() -> void:
	var csg := CSGCombiner3D.new()
	csg.position = CENTRE
	add_child(csg)
	var boite := CSGBox3D.new()
	boite.size = Vector3(LONG, EP, LARG)
	boite.position = Vector3(0, PIEDS + EP / 2.0, 0)
	boite.material = _bois(Color(0.25, 0.12, 0.05))
	csg.add_child(boite)
	var creux := _bois(Color(0.15, 0.07, 0.03))
	for i in 12:
		var s := CSGSphere3D.new()
		s.radius = R_TROU
		s.radial_segments = 24
		s.rings = 12
		s.operation = CSGShape3D.OPERATION_SUBTRACTION
		s.material = creux
		s.position = _pos_trou(i) - CENTRE + Vector3(0, R_TROU - PROF, 0)
		csg.add_child(s)
	for j in [1, 2]:
		var g := CSGSphere3D.new()
		g.radius = 0.06
		g.radial_segments = 24
		g.rings = 12
		g.scale = Vector3(0.9, 0.5, 1.9)
		g.operation = CSGShape3D.OPERATION_SUBTRACTION
		g.material = creux
		g.position = _pos_grenier(j) - CENTRE + Vector3(0, 0.06 * 0.5 - 0.021, 0)
		csg.add_child(g)
	var pied_mat := _bois(Color(0.2, 0.1, 0.045))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := CSGBox3D.new()
			p.size = Vector3(0.05, PIEDS, 0.05)
			p.position = Vector3(sx * (LONG / 2.0 - 0.06), PIEDS / 2.0, sz * (LARG / 2.0 - 0.04))
			p.material = pied_mat
			csg.add_child(p)

	# Anneaux de visée, compteurs et zones
	_mat_anneau = StandardMaterial3D.new()
	_mat_anneau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_anneau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_anneau.albedo_color = Color(0.95, 0.78, 0.38, 0.45)
	_mat_anneau_vise = _mat_anneau.duplicate()
	_mat_anneau_vise.albedo_color = Color(1.0, 0.85, 0.45, 0.95)
	var tore := TorusMesh.new()
	tore.inner_radius = 0.0395
	tore.outer_radius = 0.045
	tore.rings = 40
	tore.ring_segments = 6
	for i in 12:
		var a := MeshInstance3D.new()
		a.mesh = tore
		a.material_override = _mat_anneau
		a.position = _pos_trou(i) + Vector3(0, 0.0012, 0)
		a.scale = Vector3(1, 0.3, 1)
		a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.visible = false
		add_child(a)
		_anneaux.append(a)
		var porte := Node3D.new()
		var pz: float = (RANG + 0.083) if i < 6 else -(RANG + 0.083)
		porte.position = Vector3(_pos_trou(i).x, TOP + 0.018, CENTRE.z + pz)
		add_child(porte)
		_orienter(porte)
		var l := UI.texte("4", 0.028, Color(0.96, 0.9, 0.78), UI.police_gras())
		porte.add_child(l)
		_comptes.append(l)
		var idx := i
		var cible := Cible.new(func(on: bool): _viser(idx if on else (-1 if _trou_vise == idx else _trou_vise)),
				func(): _jouer_humain(idx))
		UI.zone(self, Vector3(D * 0.92, 0.06, 0.11), _pos_trou(i) + Vector3(0, 0.01, 0), cible)
	for j in [1, 2]:
		var porte2 := Node3D.new()
		porte2.position = _pos_grenier(j) + Vector3(0, 0.075, 0)
		add_child(porte2)
		_orienter(porte2)
		var l2 := UI.texte("0", 0.034, UI.OR, UI.police_gras())
		porte2.add_child(l2)
		_comptes_greniers.append(l2)
	_arrivee = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.006
	sp.height = 0.012
	_arrivee.mesh = sp
	_arrivee.material_override = _mat_anneau_vise
	_arrivee.visible = false
	add_child(_arrivee)


func _nouvelle_graine(pos: Vector3) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	g.mesh = _geo_graine
	g.material_override = _mats_graines[randi() % _mats_graines.size()]
	g.position = pos
	g.basis = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)).scaled(Vector3(1.0, 0.78, 1.3))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(g)
	return g


## Place de la k-ième graine dans un trou (petit tas).
func _place(trou: int, k: int) -> Vector3:
	var couche := k / 7
	var idx := k % 7
	var off := Vector2.ZERO
	if idx > 0:
		var a := idx * TAU / 6.0 + couche * 0.6
		off = Vector2(cos(a), sin(a)) * 0.0165
	var y := -PROF + 0.0078 + couche * 0.011 + (0.004 if idx > 0 else 0.0)
	return _pos_trou(trou) + Vector3(off.x, y, off.y)


func _place_grenier(j: int, k: int) -> Vector3:
	var col := k % 3
	var rang := (k / 3) % 8
	var couche := k / 24
	return _pos_grenier(j) + Vector3((col - 1) * 0.0175, -0.021 + 0.009 + couche * 0.012 + (0.003 if col != 1 else 0.0), (rang - 3.5) * 0.0215)


# ------------------------------------------------------------------ déroulement

func _preparer_partie() -> void:
	var anciennes: Array = []
	for t in _graines:
		anciennes.append_array(t)
	for j in [1, 2]:
		anciennes.append_array(_greniers[j])
	var restes: Array = []
	for a in _anims:
		if a.type == "sortie":
			restes.append(a)
	_anims = restes
	_faire_sortir(anciennes)
	_b = PackedInt32Array()
	_b.resize(12)
	_b.fill(4)
	_s = PackedInt32Array([0, 0])
	_coups = 0
	_sans_prise = 0
	_en_vol = 0
	_graines = []
	_greniers = {1: [], 2: []}
	for i in 12:
		var liste: Array = []
		for k in 4:
			var g := _nouvelle_graine(_place(i, k))
			_faire_apparaitre(g, 0.1 + (i * 4 + k) * 0.01)
			liste.append(g)
		_graines.append(liste)
	_maj_comptes()
	_maj_anneaux()


func _maj_comptes() -> void:
	for i in 12:
		_comptes[i].text = str(_graines[i].size())
	for j in [1, 2]:
		_comptes_greniers[j - 1].text = str(_greniers[j].size())


func _debut_tour() -> void:
	_occupe = false
	_maj_statut()
	_maj_anneaux()
	if _tour_ia():
		_demander_ia()


func _jouer_humain(i: int) -> void:
	if _occupe or _fini or _tour_ia():
		return
	if not IA.coups(_b, _joueur).has(i):
		app.sons.jouer("refus")
		return
	_jouer(i)


func _jouer(i: int) -> void:
	var j := _joueur
	var chemin := IA.parcours(_b, i)
	var r := IA.jouer(_b, j, i)
	_s[j - 1] += r.gain
	_coups += 1
	_sans_prise = 0 if r.gain > 0 else _sans_prise + 1
	_occupe = true
	_maj_anneaux()

	# Graines portées : chacune reçoit son trou et sa place d'arrivée.
	var portees: Array = _graines[i]
	_graines[i] = []
	var comptes: Array = []
	for t in 12:
		comptes.append(_graines[t].size())
	var cibles: Array = []
	for s in chemin.size():
		var k: int = chemin[s]
		cibles.append([k, comptes[k]])
		comptes[k] += 1
	var depart_pos: Array = []
	for g in portees:
		depart_pos.append((g as Node3D).position)
	_comptes[i].text = "0"
	_anims.append({
		"type": "semis", "t": 0.0, "duree": MONTEE + chemin.size() * PAS + 0.45, "m": self, "partie": _partie,
		"origine": i, "chemin": chemin, "portees": portees, "cibles": cibles, "depart": depart_pos,
		"lachees": 0, "prises": r.prises, "joueur": j,
	})
	app.sons.jouer_a("souffle", _pos_trou(i) + position, -14.0)


func _amas(n: int) -> Vector3:
	var a := n * 2.4
	var r := 0.006 * sqrt(float(n % 8))
	return Vector3(cos(a) * r, (n / 8) * 0.008, sin(a) * r)


func _main_pos(a: Dictionary, t: float) -> Vector3:
	var hauteur := Vector3(0, 0.07, 0)
	var chemin: PackedInt32Array = a.chemin
	if t <= MONTEE:
		return _pos_trou(a.origine) + hauteur
	var u := (t - MONTEE) / PAS
	var s := mini(int(u), chemin.size() - 1)
	var f := clampf((u - s) / 0.6, 0.0, 1.0)
	var de := _pos_trou(a.origine) if s == 0 else _pos_trou(chemin[s - 1])
	var vers := _pos_trou(chemin[s])
	return de.lerp(vers, smoothstep(0.0, 1.0, f)) + hauteur


func _anim_semis(a: Dictionary) -> bool:
	var t: float = a.t
	var portees: Array = a.portees
	var n := portees.size()
	var main := _main_pos(a, t)
	for s in n:
		var g: Node3D = portees[s]
		if not is_instance_valid(g):
			continue
		var lacher := MONTEE + s * PAS + PAS * 0.6
		var cible: Array = a.cibles[s]
		if t < MONTEE:
			g.position = (a.depart[s] as Vector3).lerp(main + _amas(s), smoothstep(0.0, 1.0, t / MONTEE))
		elif t < lacher:
			g.position = main + _amas(s)
		else:
			var u := clampf((t - lacher) / 0.15, 0.0, 1.0)
			var haut := _main_pos(a, lacher) + _amas(s)
			g.position = haut.lerp(_place(cible[0], cible[1]), u * u)
			if s >= a.lachees and u >= 1.0:
				a.lachees = s + 1
				(_graines[cible[0]] as Array).append(g)
				_comptes[cible[0]].text = str(_graines[cible[0]].size())
				app.sons.jouer_a("clac", g.global_position, -16.0)
	if t < a.duree:
		return true
	_lancer_prises(a.prises, a.joueur)
	return false


## Envoie les graines des trous pris vers le grenier du joueur.
func _lancer_prises(trous: Array, j: int) -> void:
	var n := 0
	for t in trous:
		var liste: Array = _graines[t]
		_graines[t] = []
		_comptes[t].text = "0"
		for g in liste:
			var place := _place_grenier(j, _greniers[j].size())
			_greniers[j].append(g)
			_anims.append({"type": "prise", "t": -n * 0.06, "duree": 0.45, "m": g, "partie": _partie,
				"de": (g as Node3D).position, "vers": place, "joueur": j})
			n += 1
	_en_vol = n
	if n == 0:
		_apres_coup()
	else:
		app.sons.jouer("clic", -4.0)


func _apres_coup() -> void:
	_maj_comptes()
	if _s[0] > 24 or _s[1] > 24:
		_terminer()
		return
	var suivant := 3 - _joueur
	if IA.coups(_b, suivant).is_empty() or _sans_prise >= 100:
		_ramasser_fin()
		return
	_joueur = suivant
	_debut_tour()


## Fin de partie sans coup possible : chacun prend les graines de son camp.
func _ramasser_fin() -> void:
	for j in [1, 2]:
		_s[j - 1] += IA.graines_camp(_b, j)
		for t in IA.camp(j):
			_b[t] = 0
	_fini_en_attente = true
	var trous1: Array = IA.camp(1)
	var trous2: Array = IA.camp(2)
	var total := 0
	for t in trous1:
		total += _graines[t].size()
	for t in trous2:
		total += _graines[t].size()
	if total == 0:
		_fini_en_attente = false
		_terminer()
		return
	_lancer_prises_fin(trous1, 1)
	_lancer_prises_fin(trous2, 2)


var _fini_en_attente := false


func _lancer_prises_fin(trous: Array, j: int) -> void:
	for t in trous:
		var liste: Array = _graines[t]
		_graines[t] = []
		_comptes[t].text = "0"
		for g in liste:
			var place := _place_grenier(j, _greniers[j].size())
			_greniers[j].append(g)
			_anims.append({"type": "prise", "t": -_en_vol * 0.04, "duree": 0.45, "m": g, "partie": _partie,
				"de": (g as Node3D).position, "vers": place, "joueur": j})
			_en_vol += 1


func _terminer() -> void:
	var g := 0
	if _s[0] > _s[1]:
		g = 1
	elif _s[1] > _s[0]:
		g = 2
	var n := ["Vous", "Ordinateur"] if _mode == "ia" else ["Sud", "Nord"]
	_annoncer_fin(g, "%s %d  –  %d %s" % [n[0], _s[0], _s[1], n[1]])
	_maj_comptes()
	_maj_anneaux()
	if g != 0 and not (_mode == "ia" and g == 2):
		_confettis.lancer(_pos_grenier(g) + Vector3(0, 0.05, 0))


# ------------------------------------------------------------------ IA

func _lancer_ia() -> Array:
	var nv: Dictionary = NIVEAUX[_niveau]
	var ia := IA.new()
	return [ia, ia.choisir.bind(_b.duplicate(), _s.duplicate(), 2, nv.prof, nv.hasard, nv.temps)]


func _coup_ia(i) -> void:
	if i < 0:
		_apres_coup()
	else:
		_jouer(i)


# ------------------------------------------------------------------ visée

func _viser(i: int) -> void:
	_trou_vise = i
	_maj_anneaux()


func _maj_anneaux() -> void:
	var peut := not _occupe and not _fini and not _tour_ia() and _b.size() == 12
	var legaux: Array = IA.coups(_b, _joueur) if peut else []
	for i in 12:
		var ok := legaux.has(i)
		_anneaux[i].visible = ok
		_anneaux[i].material_override = _mat_anneau_vise if (ok and i == _trou_vise) else _mat_anneau
	_arrivee.visible = false
	if peut and legaux.has(_trou_vise):
		var chemin := IA.parcours(_b, _trou_vise)
		var fin: int = chemin[chemin.size() - 1]
		_arrivee.position = _pos_trou(fin) + Vector3(0, 0.035, 0)
		_arrivee.visible = true


func sortir() -> void:
	_viser(-1)


# ------------------------------------------------------------------ animations

func _anim(a: Dictionary, k: float, _delta: float) -> bool:
	if a.has("partie") and a.partie != _partie:
		return false
	match a.type:
		"semis":
			return _anim_semis(a)
		"prise":
			var g: Node3D = a.m
			var e := smoothstep(0.0, 1.0, k)
			g.position = (a.de as Vector3).lerp(a.vers, e) + Vector3(0, sin(PI * k) * 0.06, 0)
			if k < 1.0:
				return true
			app.sons.jouer_a("clac", g.global_position, -18.0)
			_comptes_greniers[a.joueur - 1].text = str(_greniers[a.joueur].size())
			_en_vol -= 1
			if _en_vol == 0:
				if _fini_en_attente:
					_fini_en_attente = false
					_terminer()
				else:
					_apres_coup()
			return false
	return false


func _mettre_a_jour(_delta: float) -> void:
	if _arrivee.visible:
		_arrivee.position.y = _pos_trou(0).y + 0.035 + sin(Time.get_ticks_msec() * 0.005) * 0.004
