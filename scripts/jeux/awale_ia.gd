extends RefCounted
## Règles et IA de l'Awalé (variante « abapa », la plus jouée).
## Trous 0 à 5 : rangée du joueur 1 (Sud), de gauche à droite vue de Sud.
## Trous 6 à 11 : rangée du joueur 2 (Nord). Le semis tourne dans l'ordre 0 → 11 → 0.
## - On sème une graine par trou en sautant le trou de départ (s'il y a 12 graines ou plus).
## - Si la dernière graine tombe chez l'adversaire et y fait 2 ou 3, on prend, et on
##   continue en arrière tant que les trous adverses font 2 ou 3.
## - Une prise qui viderait tout le camp adverse (« grand chelem ») est annulée.
## - Si l'adversaire n'a plus de graines, il faut le nourrir si possible.
## - Fin : plus de 24 graines prises, ou plus aucun coup possible (chacun prend
##   alors les graines de son camp), ou partie qui tourne en rond.

const VICTOIRE := 1000000

var _limite_ms := 0
var _stop := false
var profondeur_atteinte := 0


static func camp(p: int) -> Array:
	return range(0, 6) if p == 1 else range(6, 12)


static func dans_camp(i: int, p: int) -> bool:
	return (i < 6) == (p == 1)


static func graines_camp(b: PackedInt32Array, p: int) -> int:
	var s := 0
	for i in camp(p):
		s += b[i]
	return s


## Trous qui recevront une graine, dans l'ordre (sans modifier le plateau).
static func parcours(b: PackedInt32Array, i: int) -> PackedInt32Array:
	var res := PackedInt32Array()
	var n := b[i]
	var k := i
	while n > 0:
		k = (k + 1) % 12
		if k == i:
			continue
		res.append(k)
		n -= 1
	return res


## Joue le coup sur b (modifié). Renvoie {"dernier", "prises": [trous], "gain"}.
static func jouer(b: PackedInt32Array, p: int, i: int) -> Dictionary:
	var chemin := parcours(b, i)
	b[i] = 0
	for k in chemin:
		b[k] += 1
	var dernier: int = chemin[chemin.size() - 1]
	var prises: Array = []
	var k := dernier
	while dans_camp(k, 3 - p) and (b[k] == 2 or b[k] == 3):
		prises.append(k)
		k -= 1
		if k < 0 or not dans_camp(k, 3 - p):
			break
	var gain := 0
	if not prises.is_empty():
		var reste := graines_camp(b, 3 - p)
		for t in prises:
			reste -= b[t]
		if reste == 0:
			prises = []  # grand chelem : pas de prise
		else:
			for t in prises:
				gain += b[t]
				b[t] = 0
	return {"dernier": dernier, "prises": prises, "gain": gain}


## Coups légaux de p (en respectant l'obligation de nourrir).
static func coups(b: PackedInt32Array, p: int) -> Array:
	var res: Array = []
	var affame := graines_camp(b, 3 - p) == 0
	for i in camp(p):
		if b[i] == 0:
			continue
		if affame:
			var nourrit := false
			for k in parcours(b, i):
				if dans_camp(k, 3 - p):
					nourrit = true
					break
			if not nourrit:
				continue
		res.append(i)
	return res


func _evaluer(b: PackedInt32Array, s: PackedInt32Array, p: int) -> int:
	var o := 3 - p
	var v := (s[p - 1] - s[o - 1]) * 100
	# Garder des graines chez soi donne de la marge ; les trous à 1 ou 2 chez l'adversaire sont des cibles.
	v += (graines_camp(b, p) - graines_camp(b, o)) * 3
	for i in camp(o):
		if b[i] == 1 or b[i] == 2:
			v += 4
	for i in camp(p):
		if b[i] == 1 or b[i] == 2:
			v -= 4
	return v


func _negamax(b: PackedInt32Array, s: PackedInt32Array, prof: int, alpha: int, beta: int, p: int) -> int:
	var o := 3 - p
	if s[p - 1] > 24:
		return VICTOIRE + prof
	if s[o - 1] > 24:
		return -VICTOIRE - prof
	var mes := coups(b, p)
	if mes.is_empty():
		var fin_p := s[p - 1] + graines_camp(b, p)
		var fin_o := s[o - 1] + graines_camp(b, o)
		return signi(fin_p - fin_o) * VICTOIRE
	if prof == 0:
		return _evaluer(b, s, p)
	if Time.get_ticks_msec() > _limite_ms:
		_stop = true
		return 0
	var meilleur := -VICTOIRE * 10
	for i in mes:
		var b2 := b.duplicate()
		var s2 := s.duplicate()
		var r := jouer(b2, p, i)
		s2[p - 1] += r.gain
		var v := -_negamax(b2, s2, prof - 1, -beta, -alpha, o)
		if _stop:
			return 0
		if v > meilleur:
			meilleur = v
		if meilleur > alpha:
			alpha = meilleur
		if alpha >= beta:
			break
	return meilleur


## Renvoie le trou choisi (ou -1 s'il n'y a aucun coup).
func choisir(plateau: PackedInt32Array, scores: PackedInt32Array, p: int, prof_max: int, hasard: float, temps_ms: int) -> int:
	var mes := coups(plateau, p)
	if mes.is_empty():
		return -1
	if randf() < hasard:
		return mes[randi() % mes.size()]
	_limite_ms = Time.get_ticks_msec() + temps_ms
	var ordre: Array = mes.duplicate()
	ordre.shuffle()
	var choix: int = ordre[0]
	for prof in range(1, prof_max + 1):
		_stop = false
		var alpha := -VICTOIRE * 10
		var meilleur_coup := -1
		for i in ordre:
			var b2 := plateau.duplicate()
			var s2 := scores.duplicate()
			var r := jouer(b2, p, i)
			s2[p - 1] += r.gain
			var v := -_negamax(b2, s2, prof - 1, -VICTOIRE * 10, -alpha, 3 - p)
			if _stop:
				break
			if v > alpha:
				alpha = v
				meilleur_coup = i
		if _stop:
			break
		choix = meilleur_coup
		profondeur_atteinte = prof
		ordre.erase(choix)
		ordre.push_front(choix)
		if alpha >= VICTOIRE:
			break
	return choix
