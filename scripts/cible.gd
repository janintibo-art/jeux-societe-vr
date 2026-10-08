extends RefCounted
## Cible visable générique : relie le survol et le choix à deux fonctions.

var _survol: Callable
var _choix: Callable


func _init(s: Callable, c: Callable) -> void:
	_survol = s
	_choix = c


func survol(on: bool) -> void:
	_survol.call(on)


func choisir() -> void:
	_choix.call()
