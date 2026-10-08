extends RefCounted
## Cartes à jouer en 3D : jeu de 52 illustré (images de « Les Dés du Comptoir »),
## dos dessiné par shader, carte cliquable qui se soulève et brille.

const UI := preload("res://scripts/ui.gd")

const COULEURS := ["pique", "coeur", "carreau", "trefle"]
const RANGS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]
const SYMBOLES := {"pique": "♠", "coeur": "♥", "carreau": "♦", "trefle": "♣"}
const NOMS_RANGS := {"A": "As", "V": "Valet", "D": "Dame", "R": "Roi"}
const LARG := 0.064
const HAUT := 0.09

static var _textures := {}
static var _mat_dos: ShaderMaterial
static var _quad: QuadMesh


static func paquet() -> Array:
	var d: Array = []
	for c in COULEURS:
		for r in RANGS:
			d.append({"r": r, "c": c})
	return d


static func libelle(carte: Dictionary) -> String:
	var r: String = carte.r
	return "%s %s" % [NOMS_RANGS.get(r, r), SYMBOLES[carte.c]]


## Texture d'une face, avec mipmaps pour rester nette au loin dans le casque.
static func texture(carte: Dictionary, jeu := "jeu1") -> Texture2D:
	var cle := "%s/%s-%s" % [jeu, carte.c, carte.r]
	if not _textures.has(cle):
		var t: Texture2D = load("res://cartes/%s.webp" % cle)
		var img := t.get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_textures[cle] = ImageTexture.create_from_image(img)
	return _textures[cle]


## Crée une carte : Node3D face vers +Z (face) et -Z (dos), avec une zone visable.
## Méta « carte » = le dictionnaire de la carte.
static func creer(carte: Dictionary, cible: Object = null, jeu := "jeu1") -> Node3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(LARG, HAUT)
		_mat_dos = ShaderMaterial.new()
		_mat_dos.shader = preload("res://shaders/dos_carte.gdshader")
		_mat_dos.set_shader_parameter("taille", Vector2(LARG, HAUT))
	var n := Node3D.new()
	n.set_meta("carte", carte)
	var face := MeshInstance3D.new()
	face.mesh = _quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture(carte, jeu)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.45
	m.metallic_specular = 0.4
	face.material_override = m
	face.position.z = 0.0003
	face.name = "face"
	n.add_child(face)
	var dos := MeshInstance3D.new()
	dos.mesh = _quad
	dos.material_override = _mat_dos
	dos.rotation.y = PI
	dos.position.z = -0.0003
	n.add_child(dos)
	for mi in [face, dos]:
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if cible:
		var z := UI.zone(n, Vector3(LARG, HAUT, 0.004), Vector3.ZERO, cible)
		z.name = "zone"
	return n


## Allume ou éteint la lueur dorée d'une carte.
static func lueur(n: Node3D, force: float) -> void:
	var face: MeshInstance3D = n.get_node("face")
	var m: StandardMaterial3D = face.material_override
	m.emission_enabled = force > 0.0
	m.emission = Color(1.0, 0.75, 0.35)
	m.emission_energy_multiplier = force


## Rend une carte visable ou non (sa zone de pointage).
static func visable(n: Node3D, on: bool) -> void:
	if n.has_node("zone"):
		(n.get_node("zone") as StaticBody3D).collision_layer = UI.COUCHE_CIBLES if on else 0
