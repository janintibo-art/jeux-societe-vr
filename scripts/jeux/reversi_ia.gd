extends RefCounted
## IA du Reversi : negamax alpha-bêta, approfondissement progressif limité dans le temps.
## Plateau : 64 octets, index = rangée * 8 + colonne. 0 vide, 1 noir, 2 blanc.
## Évaluation : poids des cases (coins forts, cases voisines des coins dangereuses)
## + mobilité ; en fin de partie, comptage exact des pions.

const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const POIDS := [
	120, -20, 20, 5, 5, 20, -20, 120,
	-20, -40, -5, -5, -5, -5, -40, -20,
	20, -5, 15, 3, 3, 15, -5, 20,
	5, -5, 3, 3, 3, 3, -5, 5,
	5, -5, 3, 3, 3, 3, -5, 5,
	20, -5, 15, 3, 3, 15, -5, 20,
	-20, -40, -5, -5, -5, -5, -40, -20,
	120, -20, 20, 5, 5, 20, -20, 120,
]
const FINAL := 100000

var _limite_ms := 0
var _stop := false
var profondeur_atteinte := 0


## Pions retournés si p joue en i (vide si le coup est illégal).
static func retournes(b: PackedByteArray, i: int, p: int) -> PackedInt32Array:
	var res := PackedInt32Array()
	if b[i] != 0:
		return res
	var c := i % 8
	var r := i / 8
	var o := 3 - p
	for d in DIRS:
		var cc: int = c + d.x
		var rr: int = r + d.y
		var tmp := PackedInt32Array()
		while cc >= 0 and cc < 8 and rr >= 0 and rr < 8 and b[rr * 8 + cc] == o:
			tmp.append(rr * 8 + cc)
			cc += d.x
			rr += d.y
		if not tmp.is_empty() and cc >= 0 and cc < 8 and rr >= 0 and rr < 8 and b[rr * 8 + cc] == p:
			res.append_array(tmp)
	return res


static func legal(b: PackedByteArray, i: int, p: int) -> bool:
	if b[i] != 0:
		return false
	var c := i % 8
	var r := i / 8
	var o := 3 - p
	for d in DIRS:
		var cc: int = c + d.x
		var rr: int = r + d.y
		var n := 0
		while cc >= 0 and cc < 8 and rr >= 0 and rr < 8 and b[rr * 8 + cc] == o:
			cc += d.x
			rr += d.y
			n += 1
		if n > 0 and cc >= 0 and cc < 8 and rr >= 0 and rr < 8 and b[rr * 8 + cc] == p:
			return true
	return false


static func coups(b: PackedByteArray, p: int) -> PackedInt32Array:
	var res := PackedInt32Array()
	for i in 64:
		if b[i] == 0 and legal(b, i, p):
			res.append(i)
	return res


static func compter(b: PackedByteArray, p: int) -> int:
	return b.count(p)


func _evaluer(b: PackedByteArray, p: int) -> int:
	var o := 3 - p
	var s := 0
	for i in 64:
		var v := b[i]
		if v == p:
			s += POIDS[i]
		elif v == o:
			s -= POIDS[i]
	s += 6 * (coups(b, p).size() - coups(b, o).size())
	return s


func _trier(m: PackedInt32Array) -> Array:
	var l: Array = Array(m)
	l.sort_custom(func(a, b2): return POIDS[a] > POIDS[b2])
	return l


func _negamax(b: PackedByteArray, prof: int, alpha: int, beta: int, p: int, passe: bool) -> int:
	if Time.get_ticks_msec() > _limite_ms:
		_stop = true
		return 0
	var mes := coups(b, p)
	if mes.is_empty():
		if passe:
			return (compter(b, p) - compter(b, 3 - p)) * FINAL / 64
		return -_negamax(b, prof, -beta, -alpha, 3 - p, true)
	if prof <= 0:
		return _evaluer(b, p)
	var meilleur := -FINAL * 10
	for i in _trier(mes):
		var r := retournes(b, i, p)
		b[i] = p
		for k in r:
			b[k] = p
		var s := -_negamax(b, prof - 1, -beta, -alpha, 3 - p, false)
		b[i] = 0
		for k in r:
			b[k] = 3 - p
		if _stop:
			return 0
		if s > meilleur:
			meilleur = s
		if meilleur > alpha:
			alpha = meilleur
		if alpha >= beta:
			break
	return meilleur


## Renvoie la case choisie, ou -1 si p ne peut pas jouer.
func choisir(plateau: PackedByteArray, p: int, prof_max: int, hasard: float, temps_ms: int) -> int:
	var b := plateau.duplicate()
	var mes := coups(b, p)
	if mes.is_empty():
		return -1
	# Un coin libre se prend toujours (même au niveau facile).
	for coin in [0, 7, 56, 63]:
		if mes.has(coin) and (hasard < 0.3 or randf() < 0.5):
			return coin
	if randf() < hasard:
		return mes[randi() % mes.size()]
	var vides := b.count(0)
	if vides <= 10 and prof_max >= 6:
		prof_max = vides
	_limite_ms = Time.get_ticks_msec() + temps_ms
	var ordre := _trier(mes)
	# Petit mélange entre coups de même poids pour varier les parties.
	ordre.shuffle()
	ordre.sort_custom(func(a, b2): return POIDS[a] > POIDS[b2])
	var choix: int = ordre[0]
	for prof in range(1, prof_max + 1):
		_stop = false
		var alpha := -FINAL * 10
		var meilleur_coup := -1
		for i in ordre:
			var r := retournes(b, i, p)
			b[i] = p
			for k in r:
				b[k] = p
			var s := -_negamax(b, prof - 1, -FINAL * 10, -alpha, 3 - p, false)
			b[i] = 0
			for k in r:
				b[k] = 3 - p
			if _stop:
				break
			if s > alpha:
				alpha = s
				meilleur_coup = i
		if _stop:
			break
		choix = meilleur_coup
		profondeur_atteinte = prof
		# Le meilleur coup est essayé en premier à la profondeur suivante.
		ordre.erase(choix)
		ordre.push_front(choix)
		if alpha >= FINAL / 2:
			break
	return choix
