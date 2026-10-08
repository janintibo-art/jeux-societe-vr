extends Node3D
## Le salon : parquet, boiseries, papier peint, fenêtres, cheminée, fauteuils,
## bibliothèques, tapis, table de jeu et éclairage.

const UI := preload("res://scripts/ui.gd")
const Formes := preload("res://scripts/formes.gd")

const X0 := -6.0
const X1 := 6.0
const Z0 := -6.0
const Z1 := 7.0
const H := 4.2
const TABLE := Vector3(0, 0.76, 3.6)

var sons
var _flammes: CPUParticles3D
var _feu: OmniLight3D
var _braises: MeshInstance3D
var _t := 0.0


func _init(p_sons) -> void:
	sons = p_sons


func _ready() -> void:
	_environnement()
	_sol_plafond()
	_murs()
	_fenetres()
	_appliques()
	_cheminee()
	_fauteuils()
	_bibliotheques()
	_tapis()
	_table()
	_lumieres()


# ------------------------------------------------------------------ matériaux

func _bois(couleur := Color(0.24, 0.12, 0.06), echelle := 7.0, brillance := 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/bois.gdshader")
	m.set_shader_parameter("couleur", couleur)
	m.set_shader_parameter("echelle", echelle)
	m.set_shader_parameter("brillance", brillance)
	return m


func _mat(couleur: Color, rugosite := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	return m


func _boite(taille: Vector3, pos: Vector3, mat: Material, parent: Node3D = self, ombre := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _plan(taille: Vector2, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = taille
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ construction

func _environnement() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.42, 0.32)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _sol_plafond() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	sol.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/parquet.gdshader")
	sol.material_override = m
	sol.position = Vector3((X0 + X1) / 2.0, 0, (Z0 + Z1) / 2.0)
	add_child(sol)

	var plafond := MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(w, d)
	pm2.flip_faces = true
	plafond.mesh = pm2
	plafond.material_override = _mat(Color(0.12, 0.085, 0.065), 0.9)
	plafond.position = Vector3((X0 + X1) / 2.0, H, (Z0 + Z1) / 2.0)
	add_child(plafond)
	var poutre := _bois(Color(0.16, 0.08, 0.04), 4.0, 0.5)
	var x := X0 + 2.0
	while x < X1:
		_boite(Vector3(0.22, 0.26, d), Vector3(x, H - 0.13, (Z0 + Z1) / 2.0), poutre)
		x += 2.0


func _mur(largeur: float, pos: Vector3, rot_y: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	add_child(g)
	var hp := H - 1.05
	var pp := ShaderMaterial.new()
	pp.shader = preload("res://shaders/papier_peint.gdshader")
	pp.set_shader_parameter("taille", Vector2(largeur, hp))
	var papier := _plan(Vector2(largeur, hp), pp, g)
	papier.position = Vector3(0, 1.05 + hp / 2.0, 0)
	var lambris := _bois(Color(0.2, 0.1, 0.05), 5.0, 0.4)
	var bas := _plan(Vector2(largeur, 1.05), lambris, g)
	bas.position = Vector3(0, 0.525, 0)
	var cadre := _bois(Color(0.26, 0.13, 0.065), 6.0, 0.35)
	var px := -largeur / 2.0 + 0.3
	while px < largeur / 2.0 - 1.0:
		_boite(Vector3(0.9, 0.62, 0.02), Vector3(px + 0.45, 0.55, 0.01), cadre, g)
		px += 1.2
	var moulure := _bois(Color(0.17, 0.085, 0.04), 6.0, 0.3)
	_boite(Vector3(largeur, 0.06, 0.05), Vector3(0, 1.05, 0.025), moulure, g)
	_boite(Vector3(largeur, 0.16, 0.035), Vector3(0, 0.08, 0.017), moulure, g)
	_boite(Vector3(largeur, 0.14, 0.08), Vector3(0, H - 0.07, 0.04), moulure, g)
	return g


var _mur_fond: Node3D
var _mur_face: Node3D

func _murs() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	_mur_fond = _mur(w, Vector3(0, 0, Z0), 0.0)
	_mur_face = _mur(w, Vector3(0, 0, Z1), PI)
	_mur(d, Vector3(X0, 0, (Z0 + Z1) / 2.0), PI / 2.0)
	_mur(d, Vector3(X1, 0, (Z0 + Z1) / 2.0), -PI / 2.0)


func _fenetres() -> void:
	var ciel := ShaderMaterial.new()
	ciel.shader = preload("res://shaders/ciel_nuit.gdshader")
	var bois := _bois(Color(0.17, 0.085, 0.04), 6.0, 0.3)
	var velours := _mat(Color(0.36, 0.05, 0.09), 0.85)
	velours.cull_mode = BaseMaterial3D.CULL_DISABLED
	var laiton := _mat(Color(0.78, 0.6, 0.33), 0.32, 1.0)
	for wx in [-3.4, 3.4]:
		var f := Node3D.new()
		f.position = Vector3(wx, 0, 0.01)
		_mur_fond.add_child(f)
		var vitre := _plan(Vector2(1.4, 2.1), ciel, f)
		vitre.position = Vector3(0, 2.25, 0)
		for b in [[Vector3(1.56, 0.1, 0.09), Vector3(0, 3.33, 0.04)], [Vector3(1.56, 0.12, 0.09), Vector3(0, 1.17, 0.04)],
				[Vector3(0.1, 2.26, 0.09), Vector3(-0.75, 2.25, 0.04)], [Vector3(0.1, 2.26, 0.09), Vector3(0.75, 2.25, 0.04)],
				[Vector3(0.04, 2.1, 0.05), Vector3(0, 2.25, 0.03)], [Vector3(1.4, 0.04, 0.05), Vector3(0, 2.6, 0.03)],
				[Vector3(1.4, 0.04, 0.05), Vector3(0, 1.9, 0.03)], [Vector3(1.7, 0.05, 0.25), Vector3(0, 1.12, 0.12)]]:
			_boite(b[0], b[1], bois, f)
		var tringle := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.018
		cyl.bottom_radius = 0.018
		cyl.height = 2.4
		tringle.mesh = cyl
		tringle.material_override = laiton
		tringle.rotation.z = PI / 2.0
		tringle.position = Vector3(0, 3.55, 0.14)
		f.add_child(tringle)
		for s in [-1.0, 1.0]:
			var r := MeshInstance3D.new()
			r.mesh = Formes.rideau(0.55, 3.45, 3.0, 0.035)
			r.material_override = velours
			r.position = Vector3(s * 0.98, 0.1, 0.08)
			f.add_child(r)
		var lune := UI.halo(Color(0.35, 0.42, 0.75), 2.4, 0.25)
		(lune.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		lune.position = Vector3(0, 2.25, 0.12)
		f.add_child(lune)


func _appliques() -> void:
	var laiton := _mat(Color(0.78, 0.6, 0.33), 0.32, 1.0)
	var abat := _mat(Color(0.95, 0.86, 0.7), 0.9)
	abat.emission_enabled = true
	abat.emission = Color(1.0, 0.72, 0.38)
	abat.emission_energy_multiplier = 0.9
	abat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var places := []
	for x in [-5.0, -1.6, 1.6, 5.0]:
		places.append([_mur_fond, x])
	for x in [-4.0, 4.0]:
		places.append([_mur_face, x])
	for p in places:
		var mur: Node3D = p[0]
		var a := Node3D.new()
		a.position = Vector3(p[1], 2.4, 0)
		mur.add_child(a)
		var plaque := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.06
		c.bottom_radius = 0.06
		c.height = 0.02
		plaque.mesh = c
		plaque.material_override = laiton
		plaque.rotation.x = PI / 2.0
		plaque.position.z = 0.01
		a.add_child(plaque)
		_boite(Vector3(0.022, 0.022, 0.2), Vector3(0, 0, 0.1), laiton, a)
		var cone := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.06
		cc.bottom_radius = 0.1
		cc.height = 0.13
		cc.cap_top = false
		cc.cap_bottom = false
		cone.mesh = cc
		cone.material_override = abat
		cone.position = Vector3(0, 0.1, 0.2)
		a.add_child(cone)
		var h := UI.halo(Color(1.0, 0.72, 0.4), 0.75, 0.6)
		h.position = Vector3(0, 0.1, 0.24)
		a.add_child(h)


func _cheminee() -> void:
	var c := Node3D.new()
	c.position = Vector3(X0, 0, 0.6)
	c.rotation.y = PI / 2.0
	add_child(c)
	var pierre := _mat(Color(0.66, 0.6, 0.52), 0.8)
	var bois := _bois(Color(0.17, 0.085, 0.04), 6.0, 0.3)
	_boite(Vector3(0.35, 1.25, 0.4), Vector3(-0.78, 0.625, 0.2), pierre, c, true)
	_boite(Vector3(0.35, 1.25, 0.4), Vector3(0.78, 0.625, 0.2), pierre, c, true)
	_boite(Vector3(1.95, 0.3, 0.42), Vector3(0, 1.1, 0.21), pierre, c)
	_boite(Vector3(2.2, 0.08, 0.5), Vector3(0, 1.29, 0.25), bois, c)
	_boite(Vector3(2.1, 0.06, 0.75), Vector3(0, 0.03, 0.37), pierre, c)
	_boite(Vector3(1.25, 0.95, 0.05), Vector3(0, 0.48, 0.03), _mat(Color(0.06, 0.04, 0.035), 1.0), c)
	var buche := _mat(Color(0.2, 0.12, 0.07), 0.95)
	for i in 3:
		var b := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.06
		cy.bottom_radius = 0.07
		cy.height = 0.7
		cy.radial_segments = 10
		b.mesh = cy
		b.material_override = buche
		b.rotation = Vector3(0, [0.3, -0.3, 0.05][i], PI / 2.0)
		b.position = Vector3([-0.05, 0.05, 0.0][i], 0.12 + i * 0.07, 0.2)
		c.add_child(b)
	_braises = UI.halo(Color(1.0, 0.35, 0.05), 0.9, 1.0)
	(_braises.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_braises.rotation.x = -PI / 2.0
	_braises.position = Vector3(0, 0.1, 0.2)
	c.add_child(_braises)

	# Flammes : particules additives
	_flammes = CPUParticles3D.new()
	_flammes.amount = 36
	_flammes.lifetime = 0.9
	_flammes.preprocess = 1.0
	_flammes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flammes.emission_box_extents = Vector3(0.28, 0.02, 0.06)
	_flammes.direction = Vector3(0, 1, 0)
	_flammes.spread = 8.0
	_flammes.gravity = Vector3(0, 0.6, 0)
	_flammes.initial_velocity_min = 0.25
	_flammes.initial_velocity_max = 0.45
	_flammes.scale_amount_min = 0.7
	_flammes.scale_amount_max = 1.2
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.6))
	courbe.add_point(Vector2(0.3, 1.0))
	courbe.add_point(Vector2(1, 0.1))
	_flammes.scale_amount_curve = courbe
	var rampe := Gradient.new()
	rampe.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	rampe.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	rampe.add_point(0.4, Color(1.0, 0.45, 0.08, 0.8))
	_flammes.color_ramp = rampe
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.28)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.vertex_color_use_as_albedo = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.65)
	gt.fill_to = Vector2(0.5, 0.05)
	fm.albedo_texture = gt
	q.material = fm
	_flammes.mesh = q
	_flammes.position = Vector3(0, 0.22, 0.2)
	c.add_child(_flammes)

	_feu = OmniLight3D.new()
	_feu.light_color = Color(1.0, 0.55, 0.22)
	_feu.light_energy = 2.2
	_feu.omni_range = 7.0
	_feu.omni_attenuation = 1.4
	_feu.position = Vector3(0, 0.6, 0.7)
	c.add_child(_feu)
	if sons:
		sons.ambiance("feu", c)

	# Tableau au-dessus de la cheminée
	var toile := ShaderMaterial.new()
	toile.shader = preload("res://shaders/ciel_nuit.gdshader")
	var t := _plan(Vector2(1.5, 1.0), _mat(Color(0.5, 0.32, 0.25), 0.8), c)
	t.position = Vector3(0, 2.3, 0.04)
	var cadre := _mat(Color(0.69, 0.53, 0.29), 0.35, 0.9)
	for b in [[Vector3(1.66, 0.1, 0.06), Vector3(0, 2.85, 0.04)], [Vector3(1.66, 0.1, 0.06), Vector3(0, 1.75, 0.04)],
			[Vector3(0.1, 1.2, 0.06), Vector3(0.8, 2.3, 0.04)], [Vector3(0.1, 1.2, 0.06), Vector3(-0.8, 2.3, 0.04)]]:
		_boite(b[0], b[1], cadre, c)
	var vue := _plan(Vector2(1.46, 0.96), toile, c)
	vue.position = Vector3(0, 2.3, 0.045)


func _fauteuil() -> Node3D:
	var g := Node3D.new()
	var cuir := _mat(Color(0.33, 0.13, 0.07), 0.5)
	var pieds := _bois(Color(0.17, 0.085, 0.04), 6.0, 0.3)
	_boite(Vector3(0.78, 0.22, 0.74), Vector3(0, 0.3, 0), cuir, g, true)
	_boite(Vector3(0.6, 0.12, 0.6), Vector3(0, 0.46, 0.04), cuir, g, true)
	var dos := _boite(Vector3(0.78, 0.7, 0.18), Vector3(0, 0.72, -0.3), cuir, g, true)
	dos.rotation.x = -0.12
	for s in [-1.0, 1.0]:
		var bras := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.08
		cap.height = 0.74
		bras.mesh = cap
		bras.material_override = cuir
		bras.rotation.x = PI / 2.0
		bras.position = Vector3(s * 0.38, 0.6, 0)
		g.add_child(bras)
		_boite(Vector3(0.14, 0.3, 0.72), Vector3(s * 0.38, 0.45, 0), cuir, g)
	for p in [Vector2(-0.32, -0.28), Vector2(0.32, -0.28), Vector2(-0.32, 0.28), Vector2(0.32, 0.28)]:
		_boite(Vector3(0.05, 0.2, 0.05), Vector3(p.x, 0.1, p.y), pieds, g)
	return g


func _fauteuils() -> void:
	var a := _fauteuil()
	a.position = Vector3(-4.2, 0, -0.5)
	a.rotation.y = -PI / 2.0 - 0.45
	add_child(a)
	var b := _fauteuil()
	b.position = Vector3(-4.2, 0, 1.7)
	b.rotation.y = -PI / 2.0 + 0.45
	add_child(b)


func _bibliotheques() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var couleurs := [Color(0.42, 0.1, 0.12), Color(0.12, 0.18, 0.29), Color(0.14, 0.3, 0.2), Color(0.54, 0.42, 0.16),
		Color(0.29, 0.17, 0.11), Color(0.16, 0.16, 0.18), Color(0.48, 0.29, 0.1), Color(0.35, 0.23, 0.35), Color(0.24, 0.35, 0.42)]
	var bois := _bois(Color(0.17, 0.085, 0.04), 6.0, 0.3)
	var fond := _mat(Color(0.08, 0.055, 0.04), 0.9)
	var livre_mat := StandardMaterial3D.new()
	livre_mat.vertex_color_use_as_albedo = true
	livre_mat.roughness = 0.65
	for z in [-3.2, -1.6, 1.4, 3.0]:
		var g := Node3D.new()
		g.position = Vector3(X1, 0, z)
		g.rotation.y = -PI / 2.0
		add_child(g)
		var bw := 1.5
		var bh := 2.6
		var bd := 0.38
		_boite(Vector3(0.05, bh, bd), Vector3(-bw / 2.0, bh / 2.0, bd / 2.0), bois, g)
		_boite(Vector3(0.05, bh, bd), Vector3(bw / 2.0, bh / 2.0, bd / 2.0), bois, g)
		_boite(Vector3(bw + 0.1, 0.08, bd + 0.04), Vector3(0, bh, bd / 2.0), bois, g)
		var dos := _plan(Vector2(bw, bh), fond, g)
		dos.position = Vector3(0, bh / 2.0, 0.012)
		var livres: Array = []
		var etageres := [0.08, 0.6, 1.12, 1.64, 2.16]
		for si in etageres.size():
			var y: float = etageres[si]
			_boite(Vector3(bw, 0.035, bd), Vector3(0, y, bd / 2.0), bois, g)
			var x := -bw / 2.0 + 0.05
			var limite := bw / 2.0 - (0.36 if si == 4 else 0.08)
			while x < limite:
				if rng.randf() < 0.07:
					x += 0.08 + rng.randf() * 0.12
					continue
				var lw := 0.025 + rng.randf() * 0.03
				var lh := minf(0.22 + rng.randf() * 0.17, 0.46)
				var ld := 0.2 + rng.randf() * 0.08
				livres.append([Vector3(x + lw / 2.0, y + 0.0175 + lh / 2.0, 0.04 + ld / 2.0), Vector3(lw, lh, ld), couleurs[rng.randi() % couleurs.size()] * rng.randf_range(0.8, 1.2)])
				x += lw + 0.002
			if si == 4:
				for k in 4:
					livres.append([Vector3(bw / 2.0 - 0.2, y + 0.0375 + k * 0.04, 0.18), Vector3(0.22, 0.035, 0.16), couleurs[k]])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var bm := BoxMesh.new()
		mm.mesh = bm
		mm.instance_count = livres.size()
		for i in livres.size():
			var l: Array = livres[i]
			var tr := Transform3D(Basis.from_scale(l[1]), l[0])
			mm.set_instance_transform(i, tr)
			var col: Color = l[2]
			col.a = 1.0
			mm.set_instance_color(i, col)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = livre_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mmi)


func _tapis() -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/tapis.gdshader")
	for t in [[Vector3(TABLE.x, 0.006, TABLE.z), Vector2(3.4, 3.4)], [Vector3(0, 0.006, -0.4), Vector2(4.2, 2.8)]]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = t[1]
		mi.mesh = pm
		mi.material_override = m
		mi.position = t[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _table() -> void:
	var g := Node3D.new()
	g.position = Vector3(TABLE.x, 0, TABLE.z)
	add_child(g)
	var bois := _bois(Color(0.19, 0.09, 0.045), 5.0, 0.25)
	var h := TABLE.y
	var plateau := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.72
	cy.bottom_radius = 0.7
	cy.height = 0.05
	cy.radial_segments = 64
	plateau.mesh = cy
	plateau.material_override = bois
	plateau.position.y = h - 0.025
	g.add_child(plateau)
	var bord := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.695
	tor.outer_radius = 0.737
	tor.rings = 80
	tor.ring_segments = 12
	bord.mesh = tor
	bord.material_override = bois
	bord.position.y = h - 0.005
	g.add_child(bord)
	var feutre := MeshInstance3D.new()
	var cf := CylinderMesh.new()
	cf.top_radius = 0.64
	cf.bottom_radius = 0.64
	cf.height = 0.004
	cf.radial_segments = 64
	feutre.mesh = cf
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://shaders/feutre.gdshader")
	feutre.material_override = fm
	feutre.position.y = h + 0.002
	g.add_child(feutre)
	var anneau := MeshInstance3D.new()
	var ta := TorusMesh.new()
	ta.inner_radius = 0.634
	ta.outer_radius = 0.646
	ta.rings = 80
	ta.ring_segments = 6
	anneau.mesh = ta
	anneau.material_override = _mat(Color(0.78, 0.6, 0.33), 0.32, 1.0)
	anneau.position.y = h + 0.004
	g.add_child(anneau)
	var pied := MeshInstance3D.new()
	var cp := CylinderMesh.new()
	cp.top_radius = 0.09
	cp.bottom_radius = 0.12
	cp.height = h - 0.12
	pied.mesh = cp
	pied.material_override = bois
	pied.position.y = (h - 0.12) / 2.0 + 0.07
	g.add_child(pied)
	for i in 4:
		var p := _boite(Vector3(0.55, 0.07, 0.1), Vector3(cos(i * PI / 2.0) * 0.25, 0.04, -sin(i * PI / 2.0) * 0.25), bois, g, true)
		p.rotation.y = i * PI / 2.0
	plateau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Lampe suspendue
	var abat := MeshInstance3D.new()
	var profil := []
	for i in 13:
		var a := i / 12.0
		profil.append(Vector2(0.04 + sin(a * PI / 2.0) * 0.24, 0.16 - a * a * 0.2))
	profil.reverse()
	abat.mesh = Formes.tour(profil, 48)
	var vert := _mat(Color(0.1, 0.27, 0.18), 0.35, 0.6)
	vert.cull_mode = BaseMaterial3D.CULL_DISABLED
	abat.material_override = vert
	abat.position = Vector3(TABLE.x, 2.42, TABLE.z)
	add_child(abat)
	var fil := _boite(Vector3(0.012, H - 2.55, 0.012), Vector3(TABLE.x, (H + 2.55) / 2.0, TABLE.z), _mat(Color(0.05, 0.05, 0.05)))
	fil.name = "fil"
	var ampoule := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 0.26
	disque.bottom_radius = 0.26
	disque.height = 0.002
	ampoule.mesh = disque
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.albedo_color = Color(1.0, 0.9, 0.72)
	ampoule.material_override = am
	ampoule.position = Vector3(TABLE.x, 2.39, TABLE.z)
	add_child(ampoule)

	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.88, 0.72)
	spot.light_energy = 4.5
	spot.spot_range = 4.0
	spot.spot_angle = 38.0
	spot.spot_angle_attenuation = 0.8
	spot.shadow_enabled = true
	spot.shadow_bias = 0.02
	spot.shadow_normal_bias = 1.0
	spot.position = Vector3(TABLE.x, 2.38, TABLE.z)
	spot.rotation.x = -PI / 2.0
	add_child(spot)


func _lumieres() -> void:
	var l1 := OmniLight3D.new()
	l1.light_color = Color(1.0, 0.78, 0.55)
	l1.light_energy = 1.6
	l1.omni_range = 9.0
	l1.position = Vector3(0, 3.2, -3.5)
	add_child(l1)
	var l2 := OmniLight3D.new()
	l2.light_color = Color(1.0, 0.78, 0.55)
	l2.light_energy = 1.1
	l2.omni_range = 8.0
	l2.position = Vector3(3.5, 3.0, 2.0)
	add_child(l2)


func _process(delta: float) -> void:
	_t += delta
	if _feu:
		var n := sin(_t * 7.0) * 0.5 + sin(_t * 13.3) * 0.3 + sin(_t * 3.1) * 0.2
		_feu.light_energy = 2.2 * (0.85 + n * 0.12 + sin(_t * 17.0) * 0.04)
		(_braises.material_override as StandardMaterial3D).albedo_color = Color.WHITE * (0.8 + n * 0.15)
