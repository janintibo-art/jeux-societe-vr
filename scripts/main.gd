extends Node3D
## Point d'entrée : démarre la VR (OpenXR), installe le joueur (casque, manettes, mains),
## le salon, l'accueil, et gère la navigation entre l'accueil et les jeux.
## Sans casque (test sur ordinateur), une caméra classique se pilote à la souris.

const UI := preload("res://scripts/ui.gd")
const Sons := preload("res://scripts/sons.gd")
const Salon := preload("res://scripts/salon.gd")
const Accueil := preload("res://scripts/accueil.gd")

## Jeux disponibles : identifiant (celui de CATEGORIES dans accueil.gd) → script.
const JEUX := {
	"puissance4": preload("res://scripts/jeux/puissance4.gd"),
	"reversi": preload("res://scripts/jeux/reversi.gd"),
	"awale": preload("res://scripts/jeux/awale.gd"),
	"abalone": preload("res://scripts/jeux/abalone.gd"),
	"421": preload("res://scripts/jeux/jeu_421.gd"),
	"10000": preload("res://scripts/jeux/jeu_10000.gd"),
	"president": preload("res://scripts/jeux/jeu_president.gd"),
}

var sons: Node
var vr := false
var xr: XRInterface

var _origine: XROrigin3D
var _camera: XRCamera3D
var _pointeurs: Array = []
var _mains: Array = []
var _modeles_manettes: Node3D
var _voile: MeshInstance3D
var _voile_cible := 0.0
var _voile_vitesse := 1.6
var _apres_voile: Callable

var _accueil
var _jeux := {}
var _scene
var _materiaux_jetons := {}

var _lacet := 0.0
var _tangage := 0.0
var _souris_appui := Vector2.ZERO
var _souris_glisse := false
var _souris_bas := false
var _souris_pos := Vector2(-1, -1)

var _args := {}
var _images := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"

	sons = Sons.new()
	add_child(sons)

	xr = XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		vr = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr.session_begun.connect(_session_commencee)
		if xr.has_signal("pose_recentered"):
			xr.pose_recentered.connect(_recentrer)

	_installer_joueur()
	add_child(Salon.new(sons))

	_accueil = Accueil.new(self)
	_scene = _accueil
	add_child(_accueil)
	_placer_joueur(_accueil.depart)
	_accueil.entrer()

	if _args.has("jeu") and JEUX.has(_args["jeu"]):
		var j = _creer_jeu(_args["jeu"])
		remove_child(_accueil)
		_scene = j
		add_child(j)
		_placer_joueur(j.depart)
		j.entrer()


func _session_commencee() -> void:
	var taux: Array = xr.get_available_display_refresh_rates()
	for voulu in [90.0, 72.0]:
		if taux.has(voulu):
			xr.display_refresh_rate = voulu
			Engine.physics_ticks_per_second = int(voulu)
			break
	_recentrer()


func _recentrer() -> void:
	if vr:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)


# ------------------------------------------------------------------ joueur

func _installer_joueur() -> void:
	_origine = XROrigin3D.new()
	add_child(_origine)
	_camera = XRCamera3D.new()
	_camera.near = 0.03
	_camera.far = 60.0
	_camera.fov = 70.0
	_camera.position = Vector3(0, 1.6, 0)
	_origine.add_child(_camera)
	_camera.make_current()

	# Voile noir pour les fondus entre scènes
	_voile = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.flip_faces = true
	sphere.radial_segments = 16
	sphere.rings = 8
	_voile.mesh = sphere
	var vm := StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.no_depth_test = true
	vm.render_priority = 127
	vm.albedo_color = Color(0, 0, 0, 1)
	_voile.material_override = vm
	_voile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_camera.add_child(_voile)

	if ClassDB.class_exists("OpenXRRenderModelManager"):
		_modeles_manettes = ClassDB.instantiate("OpenXRRenderModelManager")
		_origine.add_child(_modeles_manettes)

	for cote in ["left_hand", "right_hand"]:
		var c := XRController3D.new()
		c.tracker = cote
		c.pose = "aim"
		_origine.add_child(c)
		var p := {"ctrl": c, "cible": null}
		p["laser"] = _faire_laser(c)
		p["point"] = _faire_point()
		p["manette"] = _faire_manette(c)
		c.button_pressed.connect(_bouton_manette.bind(p))
		_pointeurs.append(p)
		_mains.append(_faire_main())
	_pointeurs.append({"ctrl": null, "cible": null})


func _bouton_manette(nom: String, p: Dictionary) -> void:
	if nom == "trigger_click":
		_choisir(p)


func _faire_laser(c: XRController3D) -> Node3D:
	var pivot := Node3D.new()
	c.add_child(pivot)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0012
	cyl.bottom_radius = 0.0022
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	mi.mesh = cyl
	mi.rotation.x = -PI / 2.0
	mi.position.z = -0.5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.9, 0.68, 0.55)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	pivot.visible = false
	return pivot


func _faire_point() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.006
	s.height = 0.012
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.93, 0.75)
	m.no_depth_test = true
	m.render_priority = 120
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


## Manette simplifiée, affichée si le casque ne fournit pas les vrais modèles.
func _faire_manette(c: XRController3D) -> Node3D:
	var g := Node3D.new()
	c.add_child(g)
	var corps := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.022
	cap.height = 0.13
	corps.mesh = cap
	corps.rotation.x = PI / 2.0 - 0.5
	corps.position = Vector3(0, -0.03, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.13, 0.14)
	m.roughness = 0.4
	corps.material_override = m
	g.add_child(corps)
	var anneau := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.03
	tor.outer_radius = 0.038
	anneau.mesh = tor
	anneau.material_override = m
	anneau.position = Vector3(0, 0.0, 0.0)
	anneau.rotation.x = 0.3
	g.add_child(anneau)
	g.visible = false
	return g


## Mains suivies : une sphère par articulation.
func _faire_main() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 10
	s.rings = 5
	mm.mesh = s
	mm.instance_count = XRHandTracker.HAND_JOINT_MAX
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.8, 0.7)
	m.roughness = 0.6
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_origine.add_child(mi)
	return mi


func _placer_joueur(d: Dictionary) -> void:
	_origine.position = d.position
	_origine.rotation.y = d.get("lacet", 0.0)
	_lacet = 0.0
	_tangage = d.get("tangage", 0.0)
	_recentrer()


# ------------------------------------------------------------------ navigation

func jeu_disponible(id: String) -> bool:
	return JEUX.has(id)


func _creer_jeu(id: String):
	if not _jeux.has(id):
		_jeux[id] = JEUX[id].new(self)
	return _jeux[id]


func ouvrir_jeu(id: String) -> void:
	if JEUX.has(id):
		_aller_vers(_creer_jeu(id))


func retour_accueil() -> void:
	_aller_vers(_accueil)


func _aller_vers(suivante) -> void:
	if _apres_voile.is_valid() or suivante == _scene:
		return
	_voile_cible = 1.0
	_voile_vitesse = 3.5
	_apres_voile = func():
		_relacher_cibles()
		_scene.sortir()
		remove_child(_scene)
		_scene = suivante
		add_child(_scene)
		_placer_joueur(_scene.depart)
		_scene.entrer()
		_voile_cible = 0.0
		_voile_vitesse = 2.5


func materiau_jeton(joueur: int) -> StandardMaterial3D:
	if not _materiaux_jetons.has(joueur):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.82, 0.09, 0.11) if joueur == 1 else Color(0.97, 0.74, 0.04)
		m.roughness = 0.26
		m.metallic_specular = 0.7
		_materiaux_jetons[joueur] = m
	return _materiaux_jetons[joueur]


# ------------------------------------------------------------------ pointage

func _relacher_cibles() -> void:
	for p in _pointeurs:
		_survoler(p, null)


func _survoler(p: Dictionary, cible) -> void:
	if p.cible == cible:
		return
	var ancienne = p.cible
	p.cible = cible
	if ancienne != null and is_instance_valid(ancienne):
		var encore := false
		for q in _pointeurs:
			if q.cible == ancienne:
				encore = true
		if not encore:
			ancienne.survol(false)
	if cible != null:
		cible.survol(true)
		if p.ctrl:
			(p.ctrl as XRController3D).trigger_haptic_pulse("haptic", 0.0, 0.25, 0.025, 0.0)


func _choisir(p: Dictionary) -> void:
	if p.cible != null and is_instance_valid(p.cible):
		p.cible.choisir()
		if p.ctrl:
			(p.ctrl as XRController3D).trigger_haptic_pulse("haptic", 0.0, 0.6, 0.04, 0.0)


func _rayon(depuis: Vector3, direction: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(depuis, depuis + direction * 6.0, UI.COUCHE_CIBLES)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(q)


func _maj_pointeurs() -> void:
	for p in _pointeurs:
		var touche := {}
		if p.ctrl == null:
			if vr or _souris_pos.x < 0.0:
				_survoler(p, null)
				continue
			var o := _camera.project_ray_origin(_souris_pos)
			var d := _camera.project_ray_normal(_souris_pos)
			touche = _rayon(o, d)
		else:
			var c: XRController3D = p.ctrl
			var suivi := vr and c.get_has_tracking_data()
			p.laser.visible = suivi
			if not suivi:
				p.point.visible = false
				_survoler(p, null)
				continue
			var t := c.global_transform
			touche = _rayon(t.origin, -t.basis.z)
			var longueur := 2.5
			if not touche.is_empty():
				longueur = t.origin.distance_to(touche.position)
			p.laser.scale = Vector3(1, 1, longueur)
			p.point.visible = not touche.is_empty()
			if not touche.is_empty():
				p.point.global_position = touche.position
		var cible = null
		if not touche.is_empty() and touche.collider and touche.collider.has_meta("cible"):
			cible = touche.collider.get_meta("cible")
		_survoler(p, cible)


func _maj_mains() -> void:
	var mains_actives := false
	for i in 2:
		var mi: MultiMeshInstance3D = _mains[i]
		var nom := "/user/hand_tracker/left" if i == 0 else "/user/hand_tracker/right"
		var t := XRServer.get_tracker(nom) as XRHandTracker
		var ok := vr and t != null and t.has_tracking_data and t.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
		mi.visible = ok
		if not ok:
			continue
		mains_actives = true
		for j in XRHandTracker.HAND_JOINT_MAX:
			var tr := t.get_hand_joint_transform(j)
			var r := maxf(t.get_hand_joint_radius(j), 0.005)
			mi.multimesh.set_instance_transform(j, Transform3D(Basis.from_scale(Vector3.ONE * r), tr.origin))
	var modeles := _modeles_manettes != null and _modeles_manettes.get_child_count() > 0
	for p in _pointeurs:
		if p.ctrl:
			p.manette.visible = vr and not modeles and not mains_actives and (p.ctrl as XRController3D).get_has_tracking_data()


# ------------------------------------------------------------------ souris (hors casque)

func _unhandled_input(e: InputEvent) -> void:
	if vr:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_souris_bas = true
			_souris_glisse = false
			_souris_appui = e.position
		else:
			_souris_bas = false
			if not _souris_glisse:
				_souris_pos = e.position
				_maj_pointeurs()
				_choisir(_pointeurs[2])
	elif e is InputEventMouseMotion:
		_souris_pos = e.position
		if _souris_bas:
			if not _souris_glisse and e.position.distance_to(_souris_appui) > 8.0:
				_souris_glisse = true
			if _souris_glisse:
				var k := 2.2 / float(get_viewport().get_visible_rect().size.y)
				_lacet += e.relative.x * k
				_tangage = clampf(_tangage + e.relative.y * k, -1.2, 1.0)


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	if not vr:
		_camera.position = Vector3(0, 1.6, 0)
		_camera.rotation = Vector3(_tangage, _lacet, 0)
	_maj_pointeurs()
	_maj_mains()

	var vm := _voile.material_override as StandardMaterial3D
	var a := vm.albedo_color.a
	if a != _voile_cible:
		a = move_toward(a, _voile_cible, delta * _voile_vitesse)
		vm.albedo_color.a = a
	elif _voile_cible == 1.0 and _apres_voile.is_valid():
		var f := _apres_voile
		_apres_voile = Callable()
		f.call()
	_voile.visible = a > 0.001

	_tests(delta)


# ------------------------------------------------------------------ tests automatiques (ordinateur)
# Exemple : godot --path . -- --jeu=puissance4 --clics=640:470@2 --capture=/tmp/img.png@5

func _tests(_delta: float) -> void:
	if _args.is_empty():
		return
	_images += 1
	var t := Time.get_ticks_msec() / 1000.0
	if _args.has("clics"):
		var restants: Array = []
		for c in String(_args["clics"]).split(";", false):
			var parts := c.split("@")
			var quand := float(parts[1]) if parts.size() > 1 else 1.0
			if t >= quand:
				var xy := parts[0].split(":")
				var pos := Vector2(float(xy[0]), float(xy[1]))
				_souris_pos = pos
				_maj_pointeurs()
				_choisir(_pointeurs[2])
			else:
				restants.append(c)
		_args["clics"] = ";".join(restants)
	if _args.has("survol"):
		var xy2 := String(_args["survol"]).split(":")
		_souris_pos = Vector2(float(xy2[0]), float(xy2[1]))
	if _args.has("capture"):
		var parts2 := String(_args["capture"]).split("@")
		var quand2 := float(parts2[1]) if parts2.size() > 1 else 3.0
		if t >= quand2 and _images > 40:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(parts2[0])
			print("CAPTURE ", parts2[0], " images=", _images)
			get_tree().quit()
			_args.erase("capture")
