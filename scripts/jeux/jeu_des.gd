extends "res://scripts/jeux/table_jeu.gd"
## Base des jeux de dés : piste, deux boutons d'action devant le joueur,
## déroulement d'une partie en coroutine (lancer, attendre, choisir).
## Chaque attente se termine par une vérification de _partie : une nouvelle
## partie abandonne proprement le déroulement précédent.

const Piste := preload("res://scripts/jeux/piste_des.gd")

signal action(id: String)

const OR_HALO := Color(1.0, 0.75, 0.3, 1.0)
const GRIS_HALO := Color(0.6, 0.6, 0.65, 0.5)
const AUCUN := Color(0, 0, 0, 0)

var piste
var _boutons: Array = []
var _ids: Array = []


func _creer_piste(n_des: int) -> void:
	piste = Piste.new(app.sons)
	piste.position = Vector3(0, 0, -0.02)
	add_child(piste)
	piste.construire(n_des)
	for d in piste.des:
		var de: Dictionary = d
		(de.corps as Node).set_meta("cible", Cible.new(func(on: bool): _de_survol(de, on), func(): _de_choisi(de)))


func _creer_actions() -> void:
	var porte := Node3D.new()
	porte.position = Vector3(0, 0.12, 0.33)
	add_child(porte)
	_orienter(porte)
	for i in 2:
		var b := Bouton.new(Vector2(0.25, 0.075), "", "", "", UI.OR, true)
		b.sons = app.sons
		b.placer(Vector3(-0.135 + i * 0.27, 0, 0))
		var k := i
		b.choisi.connect(func(): _sur_action(k))
		porte.add_child(b)
		b.montrer(false)
		_boutons.append(b)


## Affiche les actions proposées : liste de [id, libellé, actif]. Ne bloque pas.
func proposer(liste: Array) -> void:
	_ids = []
	for i in _boutons.size():
		var b = _boutons[i]
		if i < liste.size():
			var it: Array = liste[i]
			_ids.append(it[0])
			b.definir(it[1], it[2])
			b.montrer(true)
		else:
			b.montrer(false)


func masquer_actions() -> void:
	_ids = []
	for b in _boutons:
		b.montrer(false)


## Affiche les actions et attend le choix du joueur.
func demander(liste: Array) -> String:
	proposer(liste)
	var choix: String = await action
	masquer_actions()
	return choix


func _sur_action(i: int) -> void:
	if i < _ids.size():
		action.emit(_ids[i])


func pause(secondes: float) -> void:
	await get_tree().create_timer(secondes).timeout


# ------------------------------------------------------------------ à redéfinir

func _de_survol(_d: Dictionary, _on: bool) -> void:
	pass


func _de_choisi(_d: Dictionary) -> void:
	pass


# ------------------------------------------------------------------ redéfinitions de la base

## Les jeux de dés écrivent eux-mêmes leur bandeau.
func _maj_statut(_sous := "") -> void:
	pass


func _tour_ia() -> bool:
	return false


func _y_bandeau() -> float:
	return 0.42


func _nom(j: int) -> String:
	if _mode == "ia":
		return "Vous" if j == 1 else "L’ordinateur"
	return "Joueur %d" % j


func sortir() -> void:
	pass
