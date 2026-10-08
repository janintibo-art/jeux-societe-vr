extends RefCounted
## Règles et IA de l'Abalone.
## Plateau hexagonal de 61 cases en coordonnées axiales (q, r), |q|,|r|,|q+r| ≤ 4.
## r = +4 : rangée du joueur 1 (Noir), proche du joueur ; r = -4 : joueur 2 (Blanc).
## Un coup déplace 1 à 3 billes alignées d'une case :
## - en ligne (dans l'axe des billes) : peut pousser des billes adverses en infériorité
##   numérique (sumito : 2 contre 1, 3 contre 1, 3 contre 2) ; une bille poussée hors
##   du plateau est perdue ;
## - de côté : toutes les cases d'arrivée doivent être libres.
## On gagne en sortant 6 billes adverses.

const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const SORTIES_GAGNANTES := 6
const GAIN := 1000000

static var CASES: Array[Vector2i] = []
static var INDEX := {}
static var VOISIN := PackedInt32Array()
static var DIST := PackedInt32Array()

var _limite_ms := 0
var _stop := false
var profondeur_atteinte := 0


static func preparer() -> void:
	if not CASES.is_empty():
		return
	for r in range(-4, 5):
		for q in range(maxi(-4, -4 - r), mini(4, 4 - r) + 1):
			INDEX[Vector2i(q, r)] = CASES.size()
			CASES.append(Vector2i(q, r))
	VOISIN.resize(61 * 6)
	DIST.resize(61)
	for i in 61:
		var c := CASES[i]
		DIST[i] = (absi(c.x) + absi(c.y) + absi(c.x + c.y)) / 2
		for d in 6:
			VOISIN[i * 6 + d] = INDEX.get(c + DIRS[d], -1)


static func depart() -> PackedByteArray:
	preparer()
	var b := PackedByteArray()
	b.resize(61)
	for i in 61:
		var c := CASES[i]
		if c.y >= 3 or (c.y == 2 and c.x >= -2 and c.x <= 0):
			b[i] = 1
		elif c.y <= -3 or (c.y == -2 and c.x >= 0 and c.x <= 2):
			b[i] = 2
	return b


## Tous les coups de p. Un coup : {"billes": [cases], "dir": d, "pousse": [cases adverses], "sortie": bool}.
static func coups(b: PackedByteArray, p: int) -> Array:
	preparer()
	var res: Array = []
	for i in 61:
		if b[i] != p:
			continue
		for d in 6:
			var n := VOISIN[i * 6 + d]
			if n >= 0 and b[n] == 0:
				res.append({"billes": [i], "dir": d, "pousse": [], "sortie": false})
		for a in 3:
			var ligne: Array = [i]
			var k := i
			for _l in 2:
				k = VOISIN[k * 6 + a]
				if k < 0 or b[k] != p:
					break
				ligne.append(k)
				_coups_ligne(b, p, ligne.duplicate(), a, res)
	return res


static func _coups_ligne(b: PackedByteArray, p: int, ligne: Array, a: int, res: Array) -> void:
	var n := ligne.size()
	for d in 6:
		if d == a or d == (a + 3) % 6:
			var tete: int = ligne[n - 1] if d == a else ligne[0]
			var c := VOISIN[tete * 6 + d]
			if c < 0 or b[c] == p:
				continue
			if b[c] == 0:
				res.append({"billes": ligne, "dir": d, "pousse": [], "sortie": false})
				continue
			var pousses: Array = []
			var k := c
			while k >= 0 and b[k] == 3 - p:
				pousses.append(k)
				k = VOISIN[k * 6 + d]
			if pousses.size() >= n:
				continue
			if k >= 0 and b[k] != 0:
				continue
			res.append({"billes": ligne, "dir": d, "pousse": pousses, "sortie": k < 0})
		else:
			var libre := true
			for x in ligne:
				var c2 := VOISIN[x * 6 + d]
				if c2 < 0 or b[c2] != 0:
					libre = false
					break
			if libre:
				res.append({"billes": ligne, "dir": d, "pousse": [], "sortie": false})


## Applique le coup sur b. Renvoie le nombre de billes sorties (0 ou 1).
static func appliquer(b: PackedByteArray, p: int, m: Dictionary) -> int:
	var d: int = m.dir
	for x in m.pousse:
		b[x] = 0
	for x in m.billes:
		b[x] = 0
	var sorties := 0
	for x in m.pousse:
		var t := VOISIN[x * 6 + d]
		if t < 0:
			sorties += 1
		else:
			b[t] = 3 - p
	for x in m.billes:
		b[VOISIN[x * 6 + d]] = p
	return sorties


func _evaluer(b: PackedByteArray, p: int) -> int:
	var o := 3 - p
	var s := (b.count(p) - b.count(o)) * 1000
	for i in 61:
		var v := b[i]
		if v == 0:
			continue
		var t := (4 - DIST[i]) * 12
		for d in 6:
			var n := VOISIN[i * 6 + d]
			if n >= 0 and b[n] == v:
				t += 2
			elif n < 0:
				t -= 6
		s += t if v == p else -t
		# Menace d'éjection : bille au bord, alignée avec plus de billes adverses derrière.
		if DIST[i] == 4:
			for d in 6:
				if VOISIN[i * 6 + d] >= 0:
					continue
				var arr := (d + 3) % 6
				var k := i
				var a := 0
				while k >= 0 and b[k] == v and a < 3:
					a += 1
					k = VOISIN[k * 6 + arr]
				var e := 0
				while k >= 0 and b[k] == 3 - v and e < 4:
					e += 1
					k = VOISIN[k * 6 + arr]
				if a <= 2 and e > a and e <= 3:
					s += -250 if v == p else 700
					break
	return s


func _ordonner(mes: Array) -> Array:
	var a: Array = []
	var bb: Array = []
	var c: Array = []
	for m in mes:
		if m.sortie:
			a.append(m)
		elif not m.pousse.is_empty():
			bb.append(m)
		else:
			c.append(m)
	return a + bb + c


func _negamax(b: PackedByteArray, prof: int, alpha: int, beta: int, p: int) -> int:
	var o := 3 - p
	if b.count(o) <= 14 - SORTIES_GAGNANTES:
		return GAIN + prof
	if b.count(p) <= 14 - SORTIES_GAGNANTES:
		return -GAIN - prof
	if prof == 0:
		return _evaluer(b, p)
	if Time.get_ticks_msec() > _limite_ms:
		_stop = true
		return 0
	var meilleur := -GAIN * 10
	for m in _ordonner(coups(b, p)):
		var b2 := b.duplicate()
		appliquer(b2, p, m)
		var v := -_negamax(b2, prof - 1, -beta, -alpha, o)
		if _stop:
			return 0
		if v > meilleur:
			meilleur = v
		if meilleur > alpha:
			alpha = meilleur
		if alpha >= beta:
			break
	return meilleur


## Renvoie le coup choisi (dictionnaire), ou {} s'il n'y en a aucun.
func choisir(plateau: PackedByteArray, p: int, prof_max: int, hasard: float, temps_ms: int) -> Dictionary:
	preparer()
	var mes := coups(plateau, p)
	if mes.is_empty():
		return {}
	if randf() < hasard:
		return mes[randi() % mes.size()]
	_limite_ms = Time.get_ticks_msec() + temps_ms
	mes.shuffle()
	var ordre := _ordonner(mes)
	var choix: Dictionary = ordre[0]
	for prof in range(1, prof_max + 1):
		_stop = false
		var alpha := -GAIN * 10
		var meilleur: Dictionary = {}
		for m in ordre:
			var b2 := plateau.duplicate()
			appliquer(b2, p, m)
			var v := -_negamax(b2, prof - 1, -GAIN * 10, -alpha, 3 - p)
			if _stop:
				break
			if v > alpha:
				alpha = v
				meilleur = m
		if _stop:
			break
		choix = meilleur
		profondeur_atteinte = prof
		ordre.erase(choix)
		ordre.push_front(choix)
		if alpha >= GAIN:
			break
	return choix
