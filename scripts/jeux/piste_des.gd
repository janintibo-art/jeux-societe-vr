extends Node3D
## Piste de dés : tapis bordé de bois, gobelet en cuir, dés physiques.
## Utilisée par le 421 et le 10 000. Les dés sont de vrais corps rigides :
## ils rebondissent sur le tapis et les rebords, puis on lit la face du dessus.

signal lancer_termine

const Formes := preload("res://scripts/formes.gd")
const UI := preload("res://scripts/ui.gd")

const TAILLE := 0.032
const LARG := 0.62
const PROF := 0.4
const SOL := 0.012
const REBORD := 0.05
## Faces du cube de Formes.de : normale locale → valeur
const FACES := [[Vector3(1, 0, 0), 3], [Vector3(-1, 0, 0), 4], [Vector3(0, 1, 0), 1],
	[Vector3(0, -1, 0), 6], [Vector3(0, 0, 1), 2], [Vector3(0, 0, -1), 5]]
const POS_GOBELET := Vector3(LARG / 2.0 + 0.085, 0, PROF / 2.0 - 0.03)

var des: Array = []
var sons
var en_cours := false

var _gobelet: Node3D
var _lances: Array = []
var _calme := 0.0
var _duree := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_sons) -> void:
	sons = p_sons
	_rng.randomize()


func construire(n: int) -> void:
	_tapis()
	_creer_gobelet()
	for i in n:
		des.append(_creer_de(i, n))


# ------------------------------------------------------------------ construction

func _tapis() -> void:
	var feutre := ShaderMaterial.new()
	feutre.shader = preload("res://shaders/feutre.gdshader")
	feutre.set_shader_parameter("couleur", Color(0.2, 0.025, 0.04))
	var fond := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(LARG, SOL, PROF)
	fond.mesh = bm
	fond.material_override = feutre
	fond.position.y = SOL / 2.0
	add_child(fond)
	var bois := ShaderMaterial.new()
	bois.shader = preload("res://shaders/bois.gdshader")
	bois.set_shader_parameter("couleur", Color(0.28, 0.14, 0.06))
	bois.set_shader_parameter("echelle", 9.0)
	bois.set_shader_parameter("brillance", 0.25)
	var e := 0.026
	for r in [[Vector3(LARG + 2 * e, REBORD, e), Vector3(0, REBORD / 2.0, PROF / 2.0 + e / 2.0)],
			[Vector3(LARG + 2 * e, REBORD, e), Vector3(0, REBORD / 2.0, -PROF / 2.0 - e / 2.0)],
			[Vector3(e, REBORD, PROF), Vector3(LARG / 2.0 + e / 2.0, REBORD / 2.0, 0)],
			[Vector3(e, REBORD, PROF), Vector3(-LARG / 2.0 - e / 2.0, REBORD / 2.0, 0)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = r[0]
		m.mesh = b
		m.material_override = bois
		m.position = r[1]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(m)

	# Physique : sol et murs (plus hauts que les rebords, invisibles)
	var corps := StaticBody3D.new()
	corps.collision_layer = 1
	corps.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.3
	corps.physics_material_override = pm
	add_child(corps)
	var formes := [
		[Vector3(LARG + 0.2, 0.1, PROF + 0.2), Vector3(0, SOL - 0.05, 0)],
		[Vector3(LARG + 0.1, 0.6, 0.05), Vector3(0, 0.3, PROF / 2.0 + 0.025)],
		[Vector3(LARG + 0.1, 0.6, 0.05), Vector3(0, 0.3, -PROF / 2.0 - 0.025)],
		[Vector3(0.05, 0.6, PROF + 0.1), Vector3(LARG / 2.0 + 0.025, 0.3, 0)],
		[Vector3(0.05, 0.6, PROF + 0.1), Vector3(-LARG / 2.0 - 0.025, 0.3, 0)],
		[Vector3(LARG + 0.2, 0.05, PROF + 0.2), Vector3(0, 0.62, 0)],
	]
	for f in formes:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = f[0]
		bx.margin = 0.002
		cs.shape = bx
		cs.position = f[1]
		corps.add_child(cs)


func _creer_gobelet() -> void:
	_gobelet = Node3D.new()
	_gobelet.position = POS_GOBELET
	add_child(_gobelet)
	var cuir := StandardMaterial3D.new()
	cuir.albedo_color = Color(0.24, 0.11, 0.06)
	cuir.roughness = 0.55
	cuir.cull_mode = BaseMaterial3D.CULL_DISABLED
	var corps := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.046
	cy.bottom_radius = 0.04
	cy.height = 0.11
	cy.cap_top = false
	cy.radial_segments = 32
	corps.mesh = cy
	corps.material_override = cuir
	corps.position.y = 0.055
	corps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_gobelet.add_child(corps)
	var laiton := StandardMaterial3D.new()
	laiton.albedo_color = Color(0.78, 0.6, 0.33)
	laiton.metallic = 1.0
	laiton.roughness = 0.3
	for y in [0.008, 0.106]:
		var anneau := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = (0.04 if y < 0.05 else 0.045)
		t.outer_radius = t.inner_radius + 0.005
		t.rings = 32
		t.ring_segments = 6
		anneau.mesh = t
		anneau.material_override = laiton
		anneau.position.y = y
		_gobelet.add_child(anneau)


func _creer_de(i: int, n: int) -> Dictionary:
	var corps := RigidBody3D.new()
	corps.mass = 0.03
	corps.continuous_cd = true
	corps.collision_layer = 1 | UI.COUCHE_CIBLES
	corps.collision_mask = 1
	corps.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	corps.freeze = true
	corps.contact_monitor = true
	corps.max_contacts_reported = 2
	corps.can_sleep = true
	corps.linear_damp = 0.3
	corps.angular_damp = 1.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.5
	pm.bounce = 0.35
	corps.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3.ONE * TAILLE
	bx.margin = 0.0008
	cs.shape = bx
	corps.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = Formes.de(TAILLE)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/de.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	corps.add_child(mi)
	add_child(corps)
	corps.position = place_attente(i, n)
	corps.rotation = Vector3(0, _rng.randf() * TAU, 0)
	var d := {"corps": corps, "mat": mat, "i": i, "garde": false, "cote": false, "dernier_son": 0}
	corps.body_entered.connect(func(_b): _choc(d))
	return d


func _choc(d: Dictionary) -> void:
	var corps: RigidBody3D = d.corps
	var v := corps.linear_velocity.length()
	var maintenant := Time.get_ticks_msec()
	if v < 0.15 or maintenant - int(d.dernier_son) < 70 or sons == null:
		return
	d.dernier_son = maintenant
	sons.jouer_a("clac", corps.global_position, linear_to_db(clampf(v / 2.5, 0.08, 0.8)))


# ------------------------------------------------------------------ positions

func place_attente(i: int, n: int) -> Vector3:
	return Vector3((i - (n - 1) / 2.0) * 0.055, SOL + TAILLE / 2.0, PROF / 2.0 - 0.06)


## Emplacement des dés mis de côté, devant la piste.
func place_cote(k: int) -> Vector3:
	return Vector3(-LARG / 2.0 + 0.04 + k * 0.05, TAILLE / 2.0 + 0.003, PROF / 2.0 + 0.075)


# ------------------------------------------------------------------ opérations

func valeur(d: Dictionary) -> int:
	var b: Basis = (d.corps as RigidBody3D).global_basis
	var meilleur := -2.0
	var v := 1
	for f in FACES:
		var y: float = (b * (f[0] as Vector3)).y
		if y > meilleur:
			meilleur = y
			v = f[1]
	return v


func valeurs(liste: Array) -> Array:
	var res: Array = []
	for d in liste:
		res.append(valeur(d))
	return res


func halo(d: Dictionary, couleur: Color) -> void:
	var mat: ShaderMaterial = d.mat
	mat.set_shader_parameter("halo", Color(couleur.r, couleur.g, couleur.b))
	mat.set_shader_parameter("halo_force", 0.0 if couleur.a == 0.0 else 0.6 * couleur.a)


func deplacer(d: Dictionary, vers: Vector3, duree := 0.35) -> Tween:
	var corps: RigidBody3D = d.corps
	corps.freeze = true
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_bouger.bind(corps, corps.position, vers), 0.0, 1.0, duree)
	return tw


func _bouger(u: float, corps: RigidBody3D, de: Vector3, vers: Vector3) -> void:
	corps.position = de.lerp(vers, u) + Vector3(0, sin(u * PI) * 0.05, 0)


## Remet en ligne les dés donnés (dans la piste, côté joueur), sans changer leur valeur.
func aligner(liste: Array) -> void:
	var n := des.size()
	var dernier: Tween = null
	for d in liste:
		d.cote = false
		dernier = deplacer(d, place_attente(d.i, n))
	if dernier:
		await dernier.finished


## Lance les dés donnés avec le gobelet ; rend la main quand ils sont immobiles.
func lancer(liste: Array) -> void:
	if liste.is_empty():
		return
	en_cours = true
	var haut := Vector3(LARG / 2.0 - 0.12, 0.2, PROF / 2.0 - 0.1)
	var tw := create_tween()
	tw.tween_property(_gobelet, "position", haut, 0.25).set_trans(Tween.TRANS_SINE)
	for k in 6:
		tw.tween_property(_gobelet, "rotation", Vector3(_rng.randf_range(-0.35, 0.35), 0, _rng.randf_range(-0.35, 0.35)), 0.07)
	if sons:
		sons.jouer_a("secoue", global_position + haut)
	for d in liste:
		var corps: RigidBody3D = d.corps
		corps.visible = false
	await tw.finished
	# Renversement vers le centre de la piste
	var vers_centre := (Vector3(-0.05, SOL, -0.02) - haut).normalized()
	var y := vers_centre
	var x := y.cross(Vector3.UP).normalized()
	var z := x.cross(y)
	var bascule := Basis(x, y, z).get_rotation_quaternion()
	var tw2 := create_tween()
	tw2.tween_property(_gobelet, "quaternion", bascule, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	var bouche := haut + vers_centre * 0.1
	var horizontal := Vector3(vers_centre.x, 0, vers_centre.z).normalized()
	for k in liste.size():
		var d: Dictionary = liste[k]
		var corps: RigidBody3D = d.corps
		corps.visible = true
		var lateral := Vector3(-horizontal.z, 0, horizontal.x)
		corps.position = bouche + lateral * ((k % 3) - 1) * 0.038 + Vector3(0, (k / 3) * 0.038, 0) - horizontal * (k / 3) * 0.02
		corps.quaternion = _orientation_au_hasard()
		corps.freeze = false
		corps.sleeping = false
		corps.linear_velocity = horizontal * _rng.randf_range(1.1, 1.6) + Vector3(_rng.randf_range(-0.25, 0.25), 0.4, _rng.randf_range(-0.25, 0.25))
		corps.angular_velocity = Vector3(_rng.randf_range(-25, 25), _rng.randf_range(-25, 25), _rng.randf_range(-25, 25))
	var tw3 := create_tween()
	tw3.tween_property(_gobelet, "position", POS_GOBELET, 0.45).set_trans(Tween.TRANS_SINE).set_delay(0.15)
	tw3.parallel().tween_property(_gobelet, "quaternion", Quaternion.IDENTITY, 0.45).set_delay(0.15)
	_lances = liste
	_calme = 0.0
	_duree = 0.0
	await lancer_termine
	en_cours = false


func _physics_process(delta: float) -> void:
	if _lances.is_empty():
		return
	_duree += delta
	var tous_calmes := true
	for d in _lances:
		var corps: RigidBody3D = d.corps
		if corps.position.y < -0.2 or absf(corps.position.x) > LARG or absf(corps.position.z) > PROF:
			# Dé sorti par accident : on le repose dans la piste
			corps.linear_velocity = Vector3.ZERO
			corps.angular_velocity = Vector3.ZERO
			corps.position = Vector3(_rng.randf_range(-0.15, 0.15), 0.1, _rng.randf_range(-0.1, 0.1))
		if not corps.sleeping and (corps.linear_velocity.length() > 0.03 or corps.angular_velocity.length() > 0.35):
			tous_calmes = false
	_calme = _calme + delta if tous_calmes else 0.0
	if _calme > 0.3 or _duree > 5.0:
		var liste := _lances
		_lances = []
		_poser(liste)


## Fige les dés et redresse ceux qui penchent (contre un rebord ou un autre dé).
func _poser(liste: Array) -> void:
	var dernier: Tween = null
	for d in liste:
		var corps: RigidBody3D = d.corps
		corps.freeze = true
		var q := corps.quaternion
		var v := valeur(d)
		var normale := Vector3.UP
		for f in FACES:
			if f[1] == v:
				normale = f[0]
		var haut_monde := (q * normale).normalized()
		var correction := Quaternion(haut_monde, Vector3.UP) if haut_monde.dot(Vector3.UP) < 0.9999 else Quaternion.IDENTITY
		var cible_q := (correction * q).normalized()
		var pos := corps.position
		pos.y = SOL + TAILLE / 2.0
		pos.x = clampf(pos.x, -LARG / 2.0 + TAILLE, LARG / 2.0 - TAILLE)
		pos.z = clampf(pos.z, -PROF / 2.0 + TAILLE, PROF / 2.0 - TAILLE)
		var tw := create_tween()
		tw.tween_property(corps, "quaternion", cible_q, 0.18)
		tw.parallel().tween_property(corps, "position", pos, 0.18)
		dernier = tw
	if dernier:
		await dernier.finished
	lancer_termine.emit()


## Orientation uniformément aléatoire (quaternion unitaire tiré sur la sphère).
func _orientation_au_hasard() -> Quaternion:
	var u1 := _rng.randf()
	var u2 := _rng.randf() * TAU
	var u3 := _rng.randf() * TAU
	var a := sqrt(1.0 - u1)
	var b := sqrt(u1)
	return Quaternion(a * sin(u2), a * cos(u2), b * sin(u3), b * cos(u3)).normalized()
