extends RefCounted
## Outils d'interface 3D : polices, panneaux arrondis, textes, zones cliquables.

const SHADER_PANNEAU := preload("res://shaders/panneau.gdshader")
const OR := Color(0.85, 0.7, 0.36)
const CREME := Color(0.96, 0.92, 0.85)
const COUCHE_CIBLES := 2

static var _police_titre: Font
static var _police_texte: Font
static var _police_gras: Font


static func police_titre() -> Font:
	if _police_titre == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Noto Serif", "Cinzel", "Georgia", "serif"])
		f.font_weight = 700
		f.multichannel_signed_distance_field = true
		_police_titre = f
	return _police_titre


static func police_texte() -> Font:
	if _police_texte == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Roboto", "Noto Sans", "sans-serif"])
		f.font_weight = 400
		f.multichannel_signed_distance_field = true
		_police_texte = f
	return _police_texte


static func police_gras() -> Font:
	if _police_gras == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Roboto", "Noto Sans", "sans-serif"])
		f.font_weight = 700
		f.multichannel_signed_distance_field = true
		_police_gras = f
	return _police_gras


## Panneau arrondi (quad + shader). marge : place réservée au halo de survol.
static func panneau(taille: Vector2, params := {}, marge := 0.03, priorite := 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = taille + Vector2(marge, marge) * 2.0
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SHADER_PANNEAU
	m.set_shader_parameter("quad_size", q.size)
	m.set_shader_parameter("rect_size", taille)
	for k in params:
		m.set_shader_parameter(k, params[k])
	m.render_priority = priorite
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Texte 3D net (champ de distance signée), taille en mètres pour une ligne.
static func texte(contenu: String, hauteur: float, couleur := CREME, police: Font = null, largeur_max := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = contenu
	l.font = police if police != null else police_texte()
	l.font_size = 64
	l.pixel_size = hauteur / 64.0
	l.modulate = couleur
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = false
	l.render_priority = 3
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if largeur_max > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = largeur_max / l.pixel_size
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


## Zone visable par les rayons : corps statique sur la couche des cibles.
## cible : objet qui répond à survol(bool) et choisir().
static func zone(parent: Node3D, taille: Vector3, position: Vector3, cible: Object) -> StaticBody3D:
	var corps := StaticBody3D.new()
	corps.collision_layer = COUCHE_CIBLES
	corps.collision_mask = 0
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.add_child(forme)
	corps.position = position
	corps.set_meta("cible", cible)
	parent.add_child(corps)
	return corps


## Halo lumineux (billboard additif) pour les ampoules, braises, etc.
static func halo(couleur: Color, taille: float, intensite := 1.0) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(couleur, 1.0))
	g.set_color(1, Color(couleur, 0.0))
	g.add_point(0.3, Color(couleur, 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	m.albedo_color = Color(intensite, intensite, intensite, 1.0)
	m.no_depth_test = false
	m.disable_receive_shadows = true
	var q := QuadMesh.new()
	q.size = Vector2(taille, taille)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
