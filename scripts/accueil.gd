extends Node3D
## Accueil : titre, trois panneaux de catégories et leurs objets qui tournent.

const UI := preload("res://scripts/ui.gd")
const Bouton := preload("res://scripts/bouton.gd")
const Formes := preload("res://scripts/formes.gd")

const CATEGORIES := [
	{
		"id": "cartes", "nom": "Cartes", "desc": "Plis, levées et coups de bluff", "accent": Color(0.85, 0.4, 0.36),
		"jeux": [
			{"id": "president", "nom": "Le Président", "sous": "4 joueurs · 52 cartes"},
			{"id": "tarot", "nom": "Le Tarot", "sous": "4 joueurs · 78 cartes"},
		],
	},
	{
		"id": "plateau", "nom": "Jeux de plateau", "desc": "Stratégie face à face", "accent": Color(0.85, 0.7, 0.36),
		"jeux": [
			{"id": "puissance4", "nom": "Puissance 4", "sous": "Alignez quatre jetons"},
			{"id": "reversi", "nom": "Reversi", "sous": "Encerclez et retournez"},
			{"id": "abalone", "nom": "Abalone", "sous": "Poussez les billes dehors"},
			{"id": "awale", "nom": "Awalé", "sous": "Semez, récoltez"},
		],
	},
	{
		"id": "des", "nom": "Dés", "desc": "Le hasard et les nerfs", "accent": Color(0.42, 0.64, 0.85),
		"jeux": [
			{"id": "421", "nom": "Le 421", "sous": "Trois dés, une combinaison"},
			{"id": "10000", "nom": "Le 10 000", "sous": "Cumulez sans tout perdre"},
		],
	},
]

var depart := {"position": Vector3.ZERO, "lacet": 0.0, "tangage": 0.05}
var app
var _vitrines: Array[Node3D] = []
var _t := 0.0


func _init(p_app) -> void:
	app = p_app


func _ready() -> void:
	_titre()
	var rayon := 2.05
	var pas := 0.6
	for i in CATEGORIES.size():
		_categorie(CATEGORIES[i], (i - 1) * pas, rayon)


func _titre() -> void:
	var g := Node3D.new()
	g.position = Vector3(0, 2.95, -2.45)
	add_child(g)
	g.look_at(Vector3(0, 1.6, 0), Vector3.UP, true)
	var t := UI.texte("Salon des Jeux", 0.22, Color(0.93, 0.78, 0.45), UI.police_titre())
	g.add_child(t)
	var s := UI.texte("Choisissez votre table", 0.065, Color(0.94, 0.88, 0.77, 0.85), UI.police_texte())
	s.position = Vector3(0, -0.2, 0)
	g.add_child(s)
	for x in [-0.62, 0.62]:
		var filet := UI.panneau(Vector2(0.42, 0.003), {"radius": 0.0015, "border": 0.0, "fill_top": Color(UI.OR, 0.7), "fill_bottom": Color(UI.OR, 0.7)}, 0.0)
		filet.position = Vector3(x, -0.2, 0)
		g.add_child(filet)


func _categorie(cat: Dictionary, angle: float, rayon: float) -> void:
	var n: int = cat.jeux.size()
	var largeur := 0.96
	var hauteur := 0.62 + n * 0.19
	var g := Node3D.new()
	g.position = Vector3(sin(angle) * rayon, 2.06 - hauteur / 2.0, -cos(angle) * rayon)
	add_child(g)
	g.look_at(Vector3(0, 1.5, 0), Vector3.UP, true)
	var accent: Color = cat.accent

	var fond := UI.panneau(Vector2(largeur, hauteur), {
		"radius": 0.05, "border": 0.004, "inner_line": 0.012,
		"fill_top": Color(0.095, 0.08, 0.086, 0.9), "fill_bottom": Color(0.04, 0.035, 0.045, 0.85),
		"border_color": Color(accent, 0.85),
	}, 0.0)
	g.add_child(fond)
	var haut := hauteur / 2.0
	var icone := UI.texte(_icone(cat.id), 0.06, accent, UI.police_texte())
	icone.position = Vector3(0, haut - 0.12, 0.002)
	g.add_child(icone)
	var nom := UI.texte(cat.nom, 0.085, UI.CREME, UI.police_titre())
	nom.position = Vector3(0, haut - 0.245, 0.002)
	g.add_child(nom)
	var desc := UI.texte(cat.desc, 0.04, Color(0.91, 0.84, 0.7, 0.75), UI.police_texte())
	desc.position = Vector3(0, haut - 0.325, 0.002)
	g.add_child(desc)
	var filet := UI.panneau(Vector2(0.62, 0.0025), {"radius": 0.001, "border": 0.0, "fill_top": Color(accent, 0.55), "fill_bottom": Color(accent, 0.55)}, 0.0)
	filet.position = Vector3(0, haut - 0.38, 0.002)
	g.add_child(filet)

	var y := haut - 0.49
	for jeu in cat.jeux:
		var dispo: bool = app.jeu_disponible(jeu.id)
		var b := Bouton.new(Vector2(0.84, 0.165), jeu.nom, jeu.sous, "Jouer" if dispo else "Bientôt", accent)
		b.actif = dispo
		b.sons = app.sons
		b.placer(Vector3(0, y, 0.01))
		b.definir()
		var id: String = jeu.id
		b.choisi.connect(func(): app.ouvrir_jeu(id))
		g.add_child(b)
		y -= 0.19

	var v := _vitrine(cat.id)
	v.position = Vector3(0, haut + 0.24, 0.05)
	v.set_meta("y0", v.position.y)
	g.add_child(v)
	_vitrines.append(v)


func _icone(id: String) -> String:
	match id:
		"cartes":
			return "♠  ♥  ♦  ♣"
		"plateau":
			return "●  ○  ●  ○"
		_:
			return "⚂  ⚄"


func _vitrine(id: String) -> Node3D:
	var g := Node3D.new()
	match id:
		"cartes":
			var cartes := [["A", "♥"], ["R", "♠"], ["D", "♦"]]
			for i in 3:
				var pivot := Node3D.new()
				pivot.rotation.z = (1 - i) * 0.32
				pivot.position = Vector3((i - 1) * 0.02, -0.07, i * 0.004)
				g.add_child(pivot)
				var face := UI.panneau(Vector2(0.1, 0.145), {
					"radius": 0.008, "border": 0.0015, "fill_top": Color(0.98, 0.96, 0.91, 1.0),
					"fill_bottom": Color(0.95, 0.92, 0.86, 1.0), "border_color": Color(0.8, 0.76, 0.67, 1.0),
				}, 0.0)
				face.position.y = 0.0725
				pivot.add_child(face)
				var rouge: bool = cartes[i][1] == "♥" or cartes[i][1] == "♦"
				var coul := Color(0.75, 0.08, 0.1) if rouge else Color(0.08, 0.08, 0.1)
				var signe := UI.texte(cartes[i][1], 0.07, coul, UI.police_texte())
				signe.position = Vector3(0, 0.07, 0.001)
				pivot.add_child(signe)
				var rang := UI.texte(cartes[i][0], 0.025, coul, UI.police_gras())
				rang.position = Vector3(-0.034, 0.125, 0.001)
				pivot.add_child(rang)
				var dos := UI.panneau(Vector2(0.1, 0.145), {
					"radius": 0.008, "border": 0.006, "fill_top": Color(0.48, 0.08, 0.14, 1.0),
					"fill_bottom": Color(0.4, 0.06, 0.11, 1.0), "border_color": Color(0.97, 0.95, 0.9, 1.0),
				}, 0.0)
				dos.position.y = 0.0725
				dos.rotation.y = PI
				pivot.add_child(dos)
		"plateau":
			var geo := Formes.jeton(0.045, 0.018)
			for i in 2:
				var j := MeshInstance3D.new()
				j.mesh = geo
				j.material_override = app.materiau_jeton(1 + i)
				j.position = Vector3(-0.035 + i * 0.07, i * 0.01, -i * 0.02)
				j.rotation.y = 0.3 - i * 0.6
				g.add_child(j)
		_:
			var dm := ShaderMaterial.new()
			dm.shader = preload("res://shaders/de.gdshader")
			var geo2 := Formes.de(0.065)
			for i in 2:
				var d := MeshInstance3D.new()
				d.mesh = geo2
				d.material_override = dm
				d.position = Vector3(-0.045 + i * 0.09, i * 0.02, 0)
				d.rotation = Vector3(0.5, 0.6, 0.2) if i == 0 else Vector3(-0.3, 1.2, 0.5)
				g.add_child(d)
	return g


func entrer() -> void:
	visible = true


func sortir() -> void:
	visible = false


func _process(delta: float) -> void:
	_t += delta
	for i in _vitrines.size():
		var v := _vitrines[i]
		v.rotation.y += delta * 0.6
		v.position.y = float(v.get_meta("y0")) + sin(_t * 1.4 + i * 2.0) * 0.02
