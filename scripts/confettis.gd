extends MultiMeshInstance3D
## Pluie de confettis lors d'une victoire.

const COULEURS := [Color(0.84, 0.12, 0.15), Color(0.96, 0.76, 0.05), Color(0.18, 0.44, 0.88),
	Color(0.18, 0.75, 0.44), Color(1, 1, 1), Color(0.85, 0.7, 0.36), Color(0.88, 0.35, 0.72)]
const NB := 160

var _pos := PackedVector3Array()
var _vit := PackedVector3Array()
var _rot := PackedVector3Array()
var _tour := PackedVector3Array()
var _vie := 0.0


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.022)
	mm.mesh = q
	mm.instance_count = NB
	for i in NB:
		mm.set_instance_color(i, COULEURS[i % COULEURS.size()])
	multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.5
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	_pos.resize(NB)
	_vit.resize(NB)
	_rot.resize(NB)
	_tour.resize(NB)


func lancer(origine: Vector3) -> void:
	for i in NB:
		_pos[i] = origine + Vector3(randf_range(-0.15, 0.15), randf() * 0.05, randf_range(-0.05, 0.05))
		var a := randf() * TAU
		var s := randf_range(0.3, 1.2)
		_vit[i] = Vector3(cos(a) * s, randf_range(1.4, 3.0), sin(a) * s * 0.6 + 0.35)
		_rot[i] = Vector3(randf() * 6.0, randf() * 6.0, randf() * 6.0)
		_tour[i] = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	_vie = 3.5
	visible = true


func mettre_a_jour(delta: float) -> void:
	if not visible:
		return
	_vie -= delta
	if _vie <= 0.0:
		visible = false
		return
	var frein := maxf(0.0, 1.0 - 2.2 * delta)
	var taille := minf(1.0, _vie / 0.6)
	for i in NB:
		var v := _vit[i]
		v.y -= 3.2 * delta
		v *= frein
		_vit[i] = v
		_pos[i] += v * delta
		_rot[i] += _tour[i] * delta
		var b := Basis.from_euler(_rot[i]).scaled(Vector3.ONE * taille)
		multimesh.set_instance_transform(i, Transform3D(b, _pos[i]))
