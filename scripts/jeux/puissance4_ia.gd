extends RefCounted
## IA du Puissance 4 : negamax avec élagage alpha-bêta et approfondissement progressif
## limité dans le temps. Exécutée dans un fil séparé pour ne jamais figer l'image.
## Plateau : 42 octets, index = colonne * 6 + rangée (rangée 0 en bas). 0 vide, 1 rouge, 2 jaune.

const COLS := 7
const ROWS := 6
const ORDRE := [3, 2, 4, 1, 5, 0, 6]
const GAIN := 1000000

static var _fenetres: Array = []

var _limite_ms := 0
var _stop := false


static func _preparer() -> void:
	if not _fenetres.is_empty():
		return
	for c in COLS:
		for r in ROWS:
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var cases := PackedInt32Array()
				for k in 4:
					var cc: int = c + d.x * k
					var rr: int = r + d.y * k
					if cc < 0 or cc >= COLS or rr < 0 or rr >= ROWS:
						break
					cases.append(cc * ROWS + rr)
				if cases.size() == 4:
					_fenetres.append(cases)


static func plus_bas(b: PackedByteArray, c: int) -> int:
	for r in ROWS:
		if b[c * ROWS + r] == 0:
			return r
	return -1


static func gagne_en(b: PackedByteArray, c: int, r: int, p: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var n := 1
		for sens in [1, -1]:
			for k in range(1, 4):
				var cc: int = c + d.x * k * sens
				var rr: int = r + d.y * k * sens
				if cc < 0 or cc >= COLS or rr < 0 or rr >= ROWS or b[cc * ROWS + rr] != p:
					break
				n += 1
		if n >= 4:
			return true
	return false


func _evaluer(b: PackedByteArray, p: int) -> int:
	var o := 3 - p
	var s := 0
	for r in ROWS:
		var v := b[3 * ROWS + r]
		if v == p:
			s += 4
		elif v == o:
			s -= 4
	for w in _fenetres:
		var moi := 0
		var eux := 0
		for i in w:
			var v := b[i]
			if v == p:
				moi += 1
			elif v == o:
				eux += 1
		if moi > 0 and eux > 0:
			continue
		if moi == 3:
			s += 12
		elif moi == 2:
			s += 3
		elif eux == 3:
			s -= 14
		elif eux == 2:
			s -= 3
	return s


func _negamax(b: PackedByteArray, prof: int, alpha: int, beta: int, p: int, restant: int) -> int:
	if restant == 0:
		return 0
	if prof == 0:
		return _evaluer(b, p)
	if Time.get_ticks_msec() > _limite_ms:
		_stop = true
		return 0
	var meilleur := -GAIN * 10
	for c in ORDRE:
		var r := plus_bas(b, c)
		if r < 0:
			continue
		b[c * ROWS + r] = p
		var score: int
		if gagne_en(b, c, r, p):
			score = GAIN + prof
		else:
			score = -_negamax(b, prof - 1, -beta, -alpha, 3 - p, restant - 1)
		b[c * ROWS + r] = 0
		if _stop:
			return 0
		if score > meilleur:
			meilleur = score
		if meilleur > alpha:
			alpha = meilleur
		if alpha >= beta:
			break
	return meilleur


## Renvoie la colonne choisie. hasard : probabilité de jouer au hasard (niveau facile).
func choisir(plateau: PackedByteArray, p: int, prof_max: int, hasard: float, temps_ms: int) -> int:
	_preparer()
	var b := plateau.duplicate()
	var coups: Array[int] = []
	for c in ORDRE:
		if plus_bas(b, c) >= 0:
			coups.append(c)
	var restant := 0
	for v in b:
		if v == 0:
			restant += 1
	# Gagner tout de suite, sinon bloquer une victoire immédiate de l'adversaire.
	for joueur in [p, 3 - p]:
		for c in coups:
			var r := plus_bas(b, c)
			b[c * ROWS + r] = joueur
			var g := gagne_en(b, c, r, joueur)
			b[c * ROWS + r] = 0
			if g:
				return c
	if randf() < hasard:
		return coups[randi() % coups.size()]
	_limite_ms = Time.get_ticks_msec() + temps_ms
	var choix: Array[int] = [coups[0]]
	for prof in range(2, prof_max + 1):
		_stop = false
		var meilleur := -GAIN * 10
		var meilleurs: Array[int] = []
		for c in coups:
			var r := plus_bas(b, c)
			b[c * ROWS + r] = p
			var s := -_negamax(b, prof - 1, -GAIN * 10, GAIN * 10, 3 - p, restant - 1)
			b[c * ROWS + r] = 0
			if _stop:
				break
			if s > meilleur:
				meilleur = s
				meilleurs = [c]
			elif s == meilleur:
				meilleurs.append(c)
		if _stop:
			break
		choix = meilleurs
		if meilleur >= GAIN:
			break
	return choix[randi() % choix.size()]
