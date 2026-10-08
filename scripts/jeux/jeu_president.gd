extends "res://scripts/jeux/table_jeu.gd"
## Le Président à 4 (vous + 3 adversaires), règles de « Les Dés du Comptoir » :
## - 52 cartes, 13 chacun. Le 3 de trèfle entame la première manche.
## - On pose 1 à 4 cartes de même valeur ; les suivants posent autant de cartes,
##   strictement plus fortes, ou passent. Ordre : 3 < 4 < … < R < A < 2.
## - Quand tous les autres ont passé, le dernier poseur ramasse et relance.
##   Un 2 ferme le pli tout de suite.
## - Premier à vider sa main : Président, puis Vice-président, Vice-trou, Trou du cul.
## Manches suivantes : le Trou du cul donne ses 2 meilleures cartes au Président,
## qui lui en rend 2 ; le Vice-trou en donne 1 au Vice-président, qui en rend 1.
## Le Trou du cul entame.

const Cartes := preload("res://scripts/jeux/cartes.gd")

const VAL := {"3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "V": 11, "D": 12, "R": 13, "A": 14, "2": 15}
const TITRES := ["Président", "Vice-président", "Vice-trou", "Trou du cul"]
const NOMS_IA := ["Vous", "Léon", "Margot", "Basile"]
const NIVEAUX := [
	{"nom": "Prudent", "risque": 0.75},
	{"nom": "Normal", "risque": 1.0},
	{"nom": "Audacieux", "risque": 1.3},
]
const SIEGES := [Vector3(0, 0, 0.5), Vector3(0.5, 0, -0.12), Vector3(0, 0, -0.52), Vector3(-0.5, 0, -0.12)]
const CENTRE := Vector3(0, 0.004, -0.06)
const DEFAUSSE := Vector3(-0.27, 0.004, -0.33)

var _mains: Array = [[], [], [], []]
var _main_h: Array = []
var _eventails: Array = []
var _plaques: Array = []
var _titres_prec: Array = []
var _rangs: Array = [-1, -1, -1, -1]
var _manches := 0
var _victoires := [0, 0, 0, 0]
var _pile: Array = []
var _defausse: Array = []
var _table := {}
var _selection_mode := ""
var _a_donner := 0
var _porte_main: Node3D


func _init(p_app) -> void:
	super()
	app = p_app


func _ready() -> void:
	_construire_interface()
	_creer_actions(Vector3(0.36, 0.26, 0.3), true)
	_porte_main = Node3D.new()
	_porte_main.position = Vector3(-0.02, 0.27, 0.37)
	add_child(_porte_main)
	_orienter(_porte_main)
	_porte_main.scale = Vector3.ONE * 1.3
	for i in 4:
		var e := Node3D.new()
		var p: Vector3 = SIEGES[i]
		e.position = p + Vector3(0, 0.13, 0)
		var dehors := Vector3(p.x, 0, p.z).normalized()
		e.basis = Basis.looking_at(-dehors, Vector3.UP).rotated(Vector3.UP, 0.0)
		add_child(e)
		_eventails.append(e)
		var plaque := Node3D.new()
		plaque.position = p + Vector3(0, 0.25, 0) if i > 0 else Vector3(0, 0.36, 0.2)
		add_child(plaque)
		_orienter(plaque)
		var fond := UI.panneau(Vector2(0.24, 0.085), {"radius": 0.02, "border": 0.002}, 0.02)
		plaque.add_child(fond)
		var nom := UI.texte(NOMS_IA[i], 0.026, UI.CREME, UI.police_gras())
		nom.position = Vector3(0, 0.016, 0.003)
		plaque.add_child(nom)
		var info := UI.texte("", 0.018, Color(0.91, 0.84, 0.7, 0.85))
		info.position = Vector3(0, -0.017, 0.003)
		plaque.add_child(info)
		plaque.visible = i > 0
		_plaques.append({"porte": plaque, "fond": fond, "nom": nom, "info": info})


# ------------------------------------------------------------------ redéfinitions

func _niveaux() -> Array:
	return NIVEAUX


func _avec_tableau() -> bool:
	return false


func _mode_modifiable() -> bool:
	return false


func _libelle_mode_fixe() -> String:
	return "4 joueurs"


func _materiau_joueur(_j: int) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = UI.OR
	return m


func _maj_statut(_sous := "") -> void:
	pass


func _tour_ia() -> bool:
	return false


func _y_bandeau() -> float:
	return 0.6


func _partie_entamee() -> bool:
	return _manches > 0


# ------------------------------------------------------------------ affichage

func _maj_plaques(tour := -1, message := {}) -> void:
	for i in 4:
		var pl: Dictionary = _plaques[i]
		var t := ""
		if _rangs[i] >= 0:
			t = TITRES[_rangs[i]]
		else:
			t = "%d carte%s" % [_mains[i].size(), "s" if _mains[i].size() > 1 else ""]
			if _titres_prec.size() == 4 and _titres_prec[i] >= 0:
				t += " · " + TITRES[_titres_prec[i]].split("-")[0].split(" ")[0]
		if message.has(i):
			t = message[i]
		(pl.info as Label3D).text = t
		var m: ShaderMaterial = (pl.fond as MeshInstance3D).material_override
		m.set_shader_parameter("glow", 1.0 if i == tour else 0.0)
		m.set_shader_parameter("border_color", UI.OR if i == tour else Color(UI.OR, 0.45))


## Éventail de dos de cartes devant un adversaire.
func _maj_eventail(i: int) -> void:
	var e: Node3D = _eventails[i]
	for c in e.get_children():
		c.queue_free()
	var n: int = _mains[i].size()
	for k in n:
		var dos := Cartes.creer({"r": "A", "c": "pique"})
		dos.get_node("face").visible = false
		var a := (k - (n - 1) / 2.0) * minf(0.1, 0.9 / maxf(n, 1))
		dos.position = Vector3(sin(a) * 0.16, cos(a) * 0.16 - 0.16, -k * 0.0008)
		dos.rotation.z = -a
		dos.scale = Vector3.ONE * 0.8
		e.add_child(dos)


func _trier(main: Array) -> void:
	main.sort_custom(func(a, b): return VAL[a.r] < VAL[b.r] or (VAL[a.r] == VAL[b.r] and COULEUR_ORDRE[a.c] < COULEUR_ORDRE[b.c]))


const COULEUR_ORDRE := {"trefle": 0, "carreau": 1, "coeur": 2, "pique": 3}


## (Re)construit la main du joueur en éventail devant lui.
func _maj_main_h(animer := true) -> void:
	var garder := {}
	for e in _main_h:
		garder[e.carte] = e
	var nouvelle: Array = []
	for c in _mains[0]:
		if garder.has(c):
			nouvelle.append(garder[c])
			garder.erase(c)
		else:
			var e := {"carte": c, "sel": false, "survol": false}
			var noeud := Cartes.creer(c, Cible.new(func(on: bool): _survol_carte(e, on), func(): _choisir_carte(e)))
			e["noeud"] = noeud
			_porte_main.add_child(noeud)
			noeud.position = Vector3(0, -0.15, 0)
			nouvelle.append(e)
	for e in garder.values():
		(e.noeud as Node3D).queue_free()
	_main_h = nouvelle
	_placer_main(animer)


func _placer_main(animer := true) -> void:
	var n := _main_h.size()
	var da := minf(0.11, 1.0 / maxf(n, 1))
	var r := 0.24
	for k in n:
		var e: Dictionary = _main_h[k]
		var a := (k - (n - 1) / 2.0) * da
		var haut := Vector3(sin(a), cos(a), 0)
		var lever := (0.028 if e.sel else 0.0) + (0.012 if e.survol else 0.0)
		var pos := Vector3(sin(a) * r, cos(a) * r - r, k * 0.0012) + haut * lever
		var noeud: Node3D = e.noeud
		Cartes.lueur(noeud, 0.35 if e.sel else 0.0)
		if animer:
			var tw := create_tween()
			tw.tween_property(noeud, "position", pos, 0.18)
			tw.parallel().tween_property(noeud, "rotation", Vector3(0, 0, -a), 0.18)
		else:
			noeud.position = pos
			noeud.rotation = Vector3(0, 0, -a)


func _survol_carte(e: Dictionary, on: bool) -> void:
	e.survol = on and _selection_mode != ""
	_placer_main()


func _choisir_carte(e: Dictionary) -> void:
	if _selection_mode == "":
		app.sons.jouer("refus")
		return
	if _selection_mode == "donner":
		if not e.sel and _nb_sel() >= _a_donner:
			app.sons.jouer("refus")
			return
		e.sel = not e.sel
	elif _selection_mode == "jouer":
		var r: String = e.carte.r
		var deja := _cartes_sel()
		if not _table.is_empty():
			# En suivant : un clic choisit directement le bon nombre de cartes de cette valeur.
			var meme := _main_h.filter(func(x): return x.carte.r == r)
			var tout_pris := true
			for x in meme:
				if not x.sel:
					tout_pris = false
			for x in _main_h:
				x.sel = false
			if not (e.sel and tout_pris and deja.size() > 0 and deja[0].r == r):
				for k in mini(int(_table.n), meme.size()):
					meme[k].sel = true
		else:
			if not deja.is_empty() and deja[0].r != r:
				for x in _main_h:
					x.sel = false
			e.sel = not e.sel
	app.sons.jouer("carte", -8.0)
	_placer_main()
	_maj_actions()


func _nb_sel() -> int:
	return _main_h.filter(func(x): return x.sel).size()


func _cartes_sel() -> Array:
	var res: Array = []
	for x in _main_h:
		if x.sel:
			res.append(x.carte)
	return res


func _selection_valide() -> bool:
	var s := _cartes_sel()
	if s.is_empty():
		return false
	for c in s:
		if c.r != s[0].r:
			return false
	if _table.is_empty():
		return true
	return s.size() == _table.n and VAL[s[0].r] > _table.val


func _maj_actions() -> void:
	if _selection_mode == "jouer":
		var n := _nb_sel()
		var libelle := "Poser" if _table.is_empty() else "Jouer"
		if n > 0:
			libelle += " %d carte%s" % [n, "s" if n > 1 else ""]
		var liste := [["jouer", libelle, _selection_valide()]]
		if not _table.is_empty():
			liste.append(["passer", "Passer", true])
		proposer(liste)
	elif _selection_mode == "donner":
		proposer([["donner", "Donner %d carte%s" % [_a_donner, "s" if _a_donner > 1 else ""], _nb_sel() == _a_donner]])


# ------------------------------------------------------------------ cartes qui volent

func _transf_centre(k: int, total: int) -> Transform3D:
	var yaw := randf_range(-0.35, 0.35)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2.0)
	var dec := Vector3((k - (total - 1) / 2.0) * 0.03, _pile.size() * 0.0007, 0)
	return Transform3D(b, CENTRE + dec)


func _voler(n: Node3D, vers: Transform3D, duree := 0.4) -> Tween:
	var tw := create_tween()
	tw.tween_method(_etape_vol.bind(n, n.transform, vers), 0.0, 1.0, duree)
	return tw


func _etape_vol(u: float, n: Node3D, de: Transform3D, vers: Transform3D) -> void:
	n.transform = de.interpolate_with(vers, smoothstep(0.0, 1.0, u)).translated(Vector3(0, sin(u * PI) * 0.06, 0))


## Pose des cartes au centre (depuis la main du joueur ou un éventail adverse).
func _poser_au_centre(j: int, cartes: Array) -> void:
	var dernier: Tween = null
	for k in cartes.size():
		var c: Dictionary = cartes[k]
		var noeud: Node3D = null
		if j == 0:
			for e in _main_h:
				if e.carte == c:
					noeud = e.noeud
			if noeud:
				var g := noeud.global_transform
				_porte_main.remove_child(noeud)
				add_child(noeud)
				noeud.global_transform = g
				Cartes.lueur(noeud, 0.0)
				Cartes.visable(noeud, false)
		if noeud == null:
			noeud = Cartes.creer(c)
			add_child(noeud)
			var e: Node3D = _eventails[j]
			noeud.transform = Transform3D(e.basis, e.position)
		_pile.append(noeud)
		dernier = _voler(noeud, _transf_centre(k, cartes.size()), 0.42)
		app.sons.jouer_a("carte", global_position + CENTRE)
	if j == 0:
		_main_h = _main_h.filter(func(x): return not cartes.has(x.carte))
		_placer_main()
	else:
		_maj_eventail(j)
	if dernier:
		await dernier.finished


## Le pli est fermé : les cartes du centre partent face cachée sur la défausse.
func _ramasser_pli() -> void:
	var dernier: Tween = null
	for n in _pile:
		var b := Basis(Vector3.UP, randf_range(-0.2, 0.2)) * Basis(Vector3.RIGHT, PI / 2.0)
		var t := Transform3D(b, DEFAUSSE + Vector3(0, 0.001 + _defausse.size() * 0.0006, 0))
		_defausse.append(n)
		dernier = _voler(n, t, 0.35)
	_pile = []
	if dernier:
		app.sons.jouer("souffle", -12.0)
		await dernier.finished


# ------------------------------------------------------------------ règles et IA

static func _groupes(main: Array) -> Dictionary:
	var g := {}
	for c in main:
		if not g.has(c.r):
			g[c.r] = []
		g[c.r].append(c)
	return g


## Coup de l'ordinateur : {r, n} ou {} pour passer.
func _choix_ia(main: Array, risque: float) -> Dictionary:
	var g := _groupes(main)
	var deux_ok := risque > 1.2
	if _table.is_empty():
		var meilleur := {}
		for r in g:
			if r == "2" and not deux_ok and g.size() > 1:
				continue
			if meilleur.is_empty() or VAL[r] < VAL[meilleur.r] or (VAL[r] == VAL[meilleur.r] and g[r].size() > meilleur.n):
				meilleur = {"r": r, "n": g[r].size()}
		return meilleur
	var choix := {}
	for r in g:
		if g[r].size() >= _table.n and VAL[r] > _table.val:
			if r == "2" and not deux_ok and main.size() > _table.n + 1:
				continue
			if choix.is_empty() or VAL[r] < VAL[choix.r]:
				choix = {"r": r, "n": _table.n}
	return choix


func _retirer(j: int, r: String, n: int) -> Array:
	var pris: Array = []
	var main: Array = _mains[j]
	for k in range(main.size() - 1, -1, -1):
		if pris.size() < n and main[k].r == r:
			pris.append(main[k])
			main.remove_at(k)
	return pris


# ------------------------------------------------------------------ déroulement

func _preparer_partie() -> void:
	masquer_actions()
	_selection_mode = ""
	_manches = 0
	_titres_prec = []
	_victoires = [0, 0, 0, 0]
	_manche(_partie)


func _nettoyer_table() -> void:
	for n in _pile + _defausse:
		(n as Node).queue_free()
	_pile = []
	_defausse = []
	for e in _main_h:
		(e.noeud as Node).queue_free()
	_main_h = []
	_mains = [[], [], [], []]
	for i in 4:
		_maj_eventail(i)


func _manche(id: int) -> void:
	_nettoyer_table()
	_rangs = [-1, -1, -1, -1]
	_table = {}
	var paquet := Cartes.paquet()
	paquet.shuffle()
	for k in paquet.size():
		_mains[k % 4].append(paquet[k])
	for i in 4:
		_trier(_mains[i])
	_ecrire_statut("Manche %d" % (_manches + 1), 0, "Distribution…")
	_maj_plaques()
	# Distribution animée
	for i in range(1, 4):
		_maj_eventail(i)
	_maj_main_h()
	app.sons.jouer("souffle", -6.0)
	await pause(1.0)
	if id != _partie:
		return

	var tour := 0
	if _titres_prec.size() == 4:
		await _echanges(id)
		if id != _partie:
			return
		tour = _titres_prec.find(3)
	else:
		for i in 4:
			for c in _mains[i]:
				if c.r == "3" and c.c == "trefle":
					tour = i
		_ecrire_statut("%s entame" % NOMS_IA[tour] if tour > 0 else "Vous entamez", 0, "Le 3 de trèfle commence")
		await pause(1.4)
	if id != _partie:
		return

	var finis := 0
	var dernier_poseur := -1
	var passes := 0
	while id == _partie:
		var actifs := []
		for i in 4:
			if _rangs[i] < 0:
				actifs.append(i)
		if actifs.size() <= 1:
			if actifs.size() == 1:
				_rangs[actifs[0]] = 3
			break
		if _rangs[tour] >= 0:
			tour = (tour + 1) % 4
			continue
		_maj_plaques(tour)
		var coup: Dictionary = {}
		if tour == 0:
			coup = await _tour_humain(id)
		else:
			coup = await _tour_ordi(tour, id)
		if id != _partie:
			return
		if coup.is_empty():
			passes += 1
			_maj_plaques(tour, {tour: "Passe"})
			if tour == 0:
				_ecrire_statut("Vous passez", 0)
			await pause(0.6)
		else:
			_table = {"n": coup.cartes.size(), "val": VAL[coup.r]}
			dernier_poseur = tour
			passes = 0
			_ecrire_statut("%s pose %s" % [NOMS_IA[tour] if tour > 0 else "Vous", _decrire(coup.cartes)], 0)
			await _poser_au_centre(tour, coup.cartes)
			if id != _partie:
				return
			if _mains[tour].is_empty():
				_rangs[tour] = finis
				finis += 1
				_ecrire_statut("%s : %s !" % [NOMS_IA[tour] if tour > 0 else "Vous", TITRES[_rangs[tour]]], 0, "Main vide")
				app.sons.jouer("victoire" if tour == 0 and _rangs[tour] == 0 else "clic")
				await pause(1.3)
		if id != _partie:
			return
		var actifs2 := 0
		for i in 4:
			if _rangs[i] < 0:
				actifs2 += 1
		if actifs2 <= 1:
			continue
		# Le pli se ferme-t-il ?
		var ferme := false
		if not _table.is_empty() and dernier_poseur >= 0:
			if _table.val == 15:
				ferme = true
			else:
				var besoin := actifs2 - 1 if _rangs[dernier_poseur] < 0 else actifs2
				ferme = passes >= besoin
		if ferme:
			await pause(0.5)
			await _ramasser_pli()
			if id != _partie:
				return
			_table = {}
			passes = 0
			tour = dernier_poseur
			while _rangs[tour] >= 0:
				tour = (tour + 1) % 4
			dernier_poseur = -1
		else:
			tour = (tour + 1) % 4
	if id != _partie:
		return
	_fin_manche(id)


func _decrire(cartes: Array) -> String:
	var r: String = cartes[0].r
	var nom: String = Cartes.NOMS_RANGS.get(r, r)
	if cartes.size() == 1:
		return Cartes.libelle(cartes[0])
	return ["", "", "une paire de ", "un brelan de ", "un carré de "][cartes.size()] + (nom if r.length() > 1 or r in ["A", "V", "D", "R"] else r)


func _tour_humain(id: int) -> Dictionary:
	for e in _main_h:
		e.sel = false
	_placer_main()
	if _table.is_empty():
		_ecrire_statut("À vous d’entamer", 0, "Choisissez 1 à 4 cartes de même valeur, puis « Poser »")
	else:
		_ecrire_statut("À vous", 0, "%d carte%s plus forte%s, ou passez" % [_table.n, "s" if _table.n > 1 else "", "s" if _table.n > 1 else ""])
	_selection_mode = "jouer"
	_maj_actions()
	var a: String = await action
	_selection_mode = ""
	masquer_actions()
	if id != _partie:
		return {}
	if a == "passer":
		return {}
	var s := _cartes_sel()
	for c in s:
		_mains[0].erase(c)
	return {"r": s[0].r, "cartes": s}


func _tour_ordi(j: int, id: int) -> Dictionary:
	_ecrire_statut("%s réfléchit…" % NOMS_IA[j], 0)
	await pause(0.8)
	if id != _partie:
		return {}
	var c := _choix_ia(_mains[j], NIVEAUX[_niveau].risque)
	if c.is_empty():
		return {}
	return {"r": c.r, "cartes": _retirer(j, c.r, c.n)}


## Échanges entre manches selon les titres de la manche précédente.
func _echanges(id: int) -> void:
	var pres: int = _titres_prec.find(0)
	var vice: int = _titres_prec.find(1)
	var vtrou: int = _titres_prec.find(2)
	var trou: int = _titres_prec.find(3)
	for paire in [[trou, pres, 2], [vtrou, vice, 1]]:
		var donneur: int = paire[0]
		var receveur: int = paire[1]
		var n: int = paire[2]
		# Le perdant donne ses meilleures cartes
		var meilleures: Array = _mains[donneur].slice(_mains[donneur].size() - n)
		for c in meilleures:
			_mains[donneur].erase(c)
			_mains[receveur].append(c)
		# Le gagnant rend des cartes de son choix (l'ordinateur : ses plus faibles)
		var rendues: Array = []
		if receveur == 0:
			_trier(_mains[0])
			_maj_main_h()
			_ecrire_statut("Vous recevez %s" % ", ".join(PackedStringArray(meilleures.map(func(c): return Cartes.libelle(c)))), 0,
				"Choisissez %d carte%s à rendre à %s" % [n, "s" if n > 1 else "", NOMS_IA[donneur]])
			_a_donner = n
			_selection_mode = "donner"
			for e in _main_h:
				e.sel = false
			_maj_actions()
			await action
			_selection_mode = ""
			masquer_actions()
			if id != _partie:
				return
			rendues = _cartes_sel()
		else:
			_trier(_mains[receveur])
			rendues = _mains[receveur].slice(0, n)
		for c in rendues:
			_mains[receveur].erase(c)
			_mains[donneur].append(c)
		for i in [donneur, receveur]:
			_trier(_mains[i])
		if donneur == 0 or receveur == 0:
			_maj_main_h()
			if donneur == 0:
				_ecrire_statut("Vous donnez %s" % ", ".join(PackedStringArray(meilleures.map(func(c): return Cartes.libelle(c)))), 0,
					"et recevez %s" % ", ".join(PackedStringArray(rendues.map(func(c): return Cartes.libelle(c)))))
				await pause(2.2)
		else:
			_ecrire_statut("%s donne %d carte%s à %s" % [NOMS_IA[donneur], n, "s" if n > 1 else "", NOMS_IA[receveur]], 0)
			await pause(1.0)
		for i in range(1, 4):
			_maj_eventail(i)
		if id != _partie:
			return
	_maj_plaques()


func _fin_manche(id: int) -> void:
	_manches += 1
	_titres_prec = _rangs.duplicate()
	var pres: int = _rangs.find(0)
	_victoires[pres] += 1
	_maj_plaques()
	var lignes: Array = []
	for r in 4:
		var i: int = _rangs.find(r)
		lignes.append("%s : %s" % [TITRES[r], NOMS_IA[i]])
	var titre := "Vous êtes %s !" % TITRES[_rangs[0]]
	_ecrire_statut(titre, 0, " · ".join(PackedStringArray(lignes)))
	if _rangs[0] == 0:
		app.sons.jouer("victoire")
		_confettis.lancer(Vector3(0, 0.15, 0.1))
	elif _rangs[0] == 3:
		app.sons.jouer("defaite")
	var a := await demander([["suivante", "Manche suivante", true]])
	if id != _partie or a != "suivante":
		return
	_manche(id)
