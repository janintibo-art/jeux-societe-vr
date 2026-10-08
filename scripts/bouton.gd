extends Node3D
## Bouton 3D : panneau arrondi + texte + zone visable. Signal « choisi » à l'activation.

signal choisi

const UI := preload("res://scripts/ui.gd")

var taille := Vector2(0.8, 0.15)
var accent := UI.OR
var actif := true
var selectionne := false
var sons = null

var _fond: MeshInstance3D
var _titre: Label3D
var _sous: Label3D
var _badge_fond: MeshInstance3D
var _badge: Label3D
var _survol := false
var _echelle := 1.0
var _appui := 0.0
var _secousse := 0.0
var _x0 := 0.0
var _centre := false


func _init(p_taille: Vector2, titre: String, sous_titre := "", badge := "", p_accent := UI.OR, centre := false) -> void:
	taille = p_taille
	accent = p_accent
	_centre = centre
	_fond = UI.panneau(taille, {"radius": taille.y * 0.3, "border": taille.y * 0.035}, 0.03, 1)
	add_child(_fond)
	var h := taille.y
	var bord_g := -taille.x / 2.0 + h * 0.35
	var place_badge := h * 1.7 if badge != "" else 0.0
	var largeur_texte := taille.x - h * 0.7 - place_badge
	_titre = UI.texte(titre, h * (0.3 if sous_titre != "" else 0.34), UI.CREME, UI.police_gras())
	_titre.position = Vector3(0 if centre else bord_g, h * 0.12 if sous_titre != "" else 0.0, 0.003)
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centre else HORIZONTAL_ALIGNMENT_LEFT
	_ajuster(_titre, largeur_texte)
	add_child(_titre)
	if sous_titre != "":
		_sous = UI.texte(sous_titre, h * 0.19, Color(0.91, 0.84, 0.7, 0.75))
		_sous.position = Vector3(0 if centre else bord_g, -h * 0.2, 0.003)
		_sous.horizontal_alignment = _titre.horizontal_alignment
		_ajuster(_sous, largeur_texte)
		add_child(_sous)
	if badge != "":
		var bt := Vector2(h * 1.4, h * 0.36)
		_badge_fond = UI.panneau(bt, {"radius": bt.y * 0.5, "border": 0.0015}, 0.0, 2)
		_badge_fond.position = Vector3(taille.x / 2.0 - h * 0.25 - bt.x / 2.0, 0, 0.002)
		add_child(_badge_fond)
		_badge = UI.texte(badge, h * 0.17, UI.CREME, UI.police_gras())
		_badge.position = _badge_fond.position + Vector3(0, 0, 0.002)
		add_child(_badge)
	UI.zone(self, Vector3(taille.x, taille.y, 0.03), Vector3.ZERO, self)
	_dessiner()


## Réduit la taille du texte s'il dépasse la largeur disponible.
func _ajuster(l: Label3D, largeur: float) -> void:
	var police: Font = l.font
	var w := police.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
	if w > largeur and w > 0.0:
		l.pixel_size *= largeur / w


func placer(p: Vector3) -> void:
	position = p
	_x0 = p.x


func definir(titre = null, p_actif = null, p_selectionne = null) -> void:
	if titre != null:
		_titre.text = titre
	if p_actif != null:
		actif = p_actif
	if p_selectionne != null:
		selectionne = p_selectionne
	_dessiner()


func survol(on: bool) -> void:
	_survol = on
	_dessiner()
	if on and actif and sons:
		sons.jouer("survol")


func choisir() -> void:
	if not actif:
		_secousse = 0.35
		if sons:
			sons.jouer("refus")
		return
	_appui = 1.0
	if sons:
		sons.jouer("clic")
	choisi.emit()


func _dessiner() -> void:
	var m: ShaderMaterial = _fond.material_override
	var allume := _survol and actif
	if selectionne:
		m.set_shader_parameter("fill_top", Color(accent, 0.55))
		m.set_shader_parameter("fill_bottom", Color(accent * 0.6, 0.45))
	elif allume:
		m.set_shader_parameter("fill_top", Color(0.25, 0.2, 0.14, 0.97))
		m.set_shader_parameter("fill_bottom", Color(0.14, 0.11, 0.08, 0.97))
	else:
		m.set_shader_parameter("fill_top", Color(0.12, 0.11, 0.13, 0.94))
		m.set_shader_parameter("fill_bottom", Color(0.06, 0.055, 0.065, 0.94))
	var bord := accent if allume else Color(accent, 0.55)
	if not actif:
		bord = Color(1, 1, 1, 0.14)
	m.set_shader_parameter("border_color", bord)
	m.set_shader_parameter("glow_color", accent)
	m.set_shader_parameter("glow", 1.0 if allume else 0.0)
	_titre.modulate = UI.CREME if actif else Color(UI.CREME, 0.45)
	if _sous:
		_sous.modulate = Color(0.91, 0.84, 0.7, 0.75 if actif else 0.35)
	if _badge_fond:
		var bm: ShaderMaterial = _badge_fond.material_override
		if actif:
			bm.set_shader_parameter("fill_top", Color(accent, 1.0 if allume else 0.88))
			bm.set_shader_parameter("fill_bottom", Color(accent * 0.85, 1.0 if allume else 0.88))
			bm.set_shader_parameter("border_color", accent)
			_badge.modulate = Color(0.1, 0.08, 0.05)
		else:
			bm.set_shader_parameter("fill_top", Color(1, 1, 1, 0.08))
			bm.set_shader_parameter("fill_bottom", Color(1, 1, 1, 0.08))
			bm.set_shader_parameter("border_color", Color(1, 1, 1, 0.18))
			_badge.modulate = Color(UI.CREME, 0.6)


func _process(delta: float) -> void:
	var cible := 1.045 if (_survol and actif) else 1.0
	_echelle = lerpf(_echelle, cible, min(1.0, delta * 14.0))
	var s := _echelle
	if _appui > 0.0:
		_appui = max(0.0, _appui - delta * 4.0)
		s -= _appui * 0.03
	scale = Vector3(s, s, 1.0)
	if _secousse > 0.0:
		_secousse = max(0.0, _secousse - delta)
		position.x = _x0 + sin(_secousse * 70.0) * 0.006 * (_secousse / 0.35)
	else:
		position.x = _x0
