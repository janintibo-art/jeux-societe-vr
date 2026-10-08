extends "res://scripts/jeux/table_jeu.gd"
## Base des jeux de dés : piste, deux boutons d'action devant le joueur,
## déroulement d'une partie en coroutine (lancer, attendre, choisir).
## Chaque attente se termine par une vérification de _partie : une nouvelle
## partie abandonne proprement le déroulement précédent.

const Piste := preload("res://scripts/jeux/piste_des.gd")

const OR_HALO := Color(1.0, 0.75, 0.3, 1.0)
const GRIS_HALO := Color(0.6, 0.6, 0.65, 0.5)
const AUCUN := Color(0, 0, 0, 0)

var piste


func _creer_piste(n_des: int) -> void:
	piste = Piste.new(app.sons)
	piste.position = Vector3(0, 0, -0.02)
	add_child(piste)
	piste.construire(n_des)
	for d in piste.des:
		var de: Dictionary = d
		(de.corps as Node).set_meta("cible", Cible.new(func(on: bool): _de_survol(de, on), func(): _de_choisi(de)))


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
