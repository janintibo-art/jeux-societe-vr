extends "res://scripts/jeux/jeu_des.gd"
## Le 10 000 (mêmes règles que « Les Dés du Comptoir ») :
## 1 = 100 · 5 = 50 · brelan de n = n × 100 (brelan d'as = 1 000), chaque dé
## supplémentaire double · suite 1-2-3-4-5 ou 2-3-4-5-6 = 1 500.
## Après chaque lancer, on met de côté au moins un dé qui marque, puis on relance
## le reste ou on « banque ». Un lancer qui ne marque rien fait perdre le tour.
## Les 5 dés mis de côté : « main pleine », on relance les 5.
## Il faut 500 points d'un coup pour ouvrir. Premier à 10 000 gagne.

const NIVEAUX := [
	{"nom": "Prudent", "risque": 0.7},
	{"nom": "Normal", "risque": 1.0},
	{"nom": "Audacieux", "risque": 1.35},
]
const OUVERTURE := 500
const OBJECTIF := 10000

var _points := {1: 0, 2: 0}
var _ouvert := {1: false, 2: false}
var _selection_active := false
var _tour_pts := 0
var _reserve: Array = []
var _humain_actuel := 1
var _mats := {}


func _init(p_app) -> void:
	super()
	app = p_app


func _ready() -> void:
	for j in [1, 2]:
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color(0.72, 0.1, 0.12), Color(0.12, 0.3, 0.7)][j - 1]
		m.roughness = 0.35
		_mats[j] = m
	_creer_piste(5)
	_construire_interface()
	_creer_actions()


# ------------------------------------------------------------------ redéfinitions

func _niveaux() -> Array:
	return NIVEAUX


func _noms() -> Dictionary:
	return {1: "Joueur 1", 2: "Joueur 2"}


func _materiau_joueur(j: int) -> Material:
	return _mats[j]


func _titre_score() -> String:
	return "Points"


func _texte_score(j: int) -> String:
	return str(_points[j])


func _partie_entamee() -> bool:
	return _points[1] + _points[2] > 0


# ------------------------------------------------------------------ règles

## Points d'une sélection de dés : {points, valide}.
static func points(vals: Array) -> Dictionary:
	if vals.is_empty():
		return {"points": 0, "valide": false}
	if vals.size() == 5:
		var s := vals.duplicate()
		s.sort()
		if s == [1, 2, 3, 4, 5] or s == [2, 3, 4, 5, 6]:
			return {"points": 1500, "valide": true}
	var c := [0, 0, 0, 0, 0, 0, 0]
	for v in vals:
		c[v] += 1
	var pts := 0
	for v in range(1, 7):
		var n: int = c[v]
		if n >= 3:
			pts += (1000 if v == 1 else v * 100) * int(pow(2, n - 3))
			n = 0
		if v == 1:
			pts += n * 100
		elif v == 5:
			pts += n * 50
		elif n > 0:
			return {"points": 0, "valide": false}
	return {"points": pts, "valide": pts > 0}


static func marque(vals: Array) -> bool:
	var c := {}
	for v in vals:
		c[v] = c.get(v, 0) + 1
	if c.has(1) or c.has(5):
		return true
	for v in c:
		if c[v] >= 3:
			return true
	if vals.size() == 5:
		var s := vals.duplicate()
		s.sort()
		if s == [1, 2, 3, 4, 5] or s == [2, 3, 4, 5, 6]:
			return true
	return false


# ------------------------------------------------------------------ déroulement

func _preparer_partie() -> void:
	masquer_actions()
	_points = {1: 0, 2: 0}
	_ouvert = {1: false, 2: false}
	for d in piste.des:
		d.garde = false
		d.cote = false
		piste.halo(d, AUCUN)
	_partie_10000(_partie)


func _partie_10000(id: int) -> void:
	await piste.aligner(piste.des)
	_ecrire_statut("Premier à 10 000 points", 0, "1 = 100 · 5 = 50 · brelan = 100 × valeur (as = 1 000) · suite = 1 500")
	await pause(2.2)
	while id == _partie:
		var j := _joueur
		if _mode == "duo" or j == 1:
			await _tour_humain(j, id)
		else:
			await _tour_ordi(j, id)
		if id != _partie:
			return
		_rafraichir_boutons()
		if _points[j] >= OBJECTIF:
			masquer_actions()
			_annoncer_fin(j, "%s atteint %d points" % [_nom(j), _points[j]])
			_rafraichir_boutons()
			if not (_mode == "ia" and j == 2):
				_confettis.lancer(Vector3(0, 0.1, 0))
			return
		await pause(1.0)
		_joueur = 3 - j


func _selection() -> Array:
	var s: Array = []
	for d in _reserve:
		if d.garde:
			s.append(d)
	return s


func _remettre_en_jeu() -> void:
	for d in piste.des:
		d.garde = false
		d.cote = false
		piste.halo(d, AUCUN)
	await piste.aligner(piste.des)


## Met de côté les dés choisis (devant la piste).
func _mettre_de_cote(liste: Array) -> void:
	var k := 0
	for d in piste.des:
		if d.cote:
			k += 1
	var dernier: Tween = null
	for d in liste:
		d.cote = true
		d.garde = false
		piste.halo(d, GRIS_HALO)
		dernier = piste.deplacer(d, piste.place_cote(k))
		k += 1
	if dernier:
		await dernier.finished


func _actions_humain(j: int, lance: bool) -> Array:
	var sel := points(piste.valeurs(_selection()))
	var reste := _reserve.size() - _selection().size()
	var libelle := "Lancer les 5 dés"
	if lance:
		libelle = "Main pleine : relancer" if reste == 0 else "Relancer %d dé%s" % [reste, "s" if reste > 1 else ""]
	var peut_banquer: bool = lance and sel.valide and (_ouvert[j] or _tour_pts + sel.points >= OUVERTURE)
	var sous := "Tour : %d points" % _tour_pts
	if lance:
		if _selection().is_empty():
			sous += "   —   touchez les dés qui marquent"
		elif not sel.valide:
			sous += "   —   sélection invalide"
		else:
			sous += "   +%d sélectionnés" % sel.points
			if not _ouvert[j] and _tour_pts + sel.points < OUVERTURE:
				sous += "   (500 pour ouvrir)"
	_ecrire_statut(("À vous" if _mode == "ia" else "À %s" % _nom(j).to_lower()) + (" — %d pts" % _points[j]), j, sous)
	return [["lancer", libelle, not lance or sel.valide], ["banquer", "Banquer", peut_banquer]]


func _tour_humain(j: int, id: int) -> void:
	_humain_actuel = j
	_tour_pts = 0
	await _remettre_en_jeu()
	_reserve = piste.des.duplicate()
	var lance := false
	while id == _partie:
		_selection_active = lance
		var a := await demander(_actions_humain(j, lance))
		_selection_active = false
		if id != _partie:
			return
		var sel := points(piste.valeurs(_selection()))
		if a == "banquer":
			_tour_pts += sel.points
			_ouvert[j] = true
			_points[j] += _tour_pts
			_ecrire_statut("%s banque %d points" % [_nom(j), _tour_pts], j, "Total : %d" % _points[j])
			await _mettre_de_cote(_selection())
			await pause(1.4)
			return
		if lance:
			_tour_pts += sel.points
			var choisis := _selection()
			var reste: Array = []
			for d in _reserve:
				if not d.garde:
					reste.append(d)
			if reste.is_empty():
				_ecrire_statut("Main pleine !", j, "On relance les 5 dés avec %d points en jeu" % _tour_pts)
				await _remettre_en_jeu()
				_reserve = piste.des.duplicate()
			else:
				await _mettre_de_cote(choisis)
				_reserve = reste
		if id != _partie:
			return
		await piste.lancer(_reserve)
		if id != _partie:
			return
		lance = true
		if not marque(piste.valeurs(_reserve)):
			_ecrire_statut("Rien ne marque !", j, "%s perd les %d points du tour" % [_nom(j), _tour_pts])
			app.sons.jouer("refus")
			await pause(2.0)
			return


func _choix_ia(liste: Array, tout: bool) -> Array:
	var vals: Array = piste.valeurs(liste)
	if liste.size() == 5:
		var s := vals.duplicate()
		s.sort()
		if s == [1, 2, 3, 4, 5] or s == [2, 3, 4, 5, 6]:
			return liste.duplicate()
	var c := {}
	for v in vals:
		c[v] = c.get(v, 0) + 1
	var choix: Array = []
	for k in liste.size():
		var v: int = vals[k]
		if c[v] >= 3 or v == 1 or (v == 5 and tout):
			choix.append(liste[k])
	if choix.is_empty():
		for k in liste.size():
			if vals[k] == 5:
				choix.append(liste[k])
				break
	return choix


func _tour_ordi(j: int, id: int) -> void:
	_tour_pts = 0
	await _remettre_en_jeu()
	_reserve = piste.des.duplicate()
	var risque: float = NIVEAUX[_niveau].risque
	_ecrire_statut("%s joue…" % _nom(j), j, "Total : %d points" % _points[j])
	while id == _partie:
		await pause(0.6)
		await piste.lancer(_reserve)
		if id != _partie:
			return
		if not marque(piste.valeurs(_reserve)):
			_ecrire_statut("%s ne marque rien !" % _nom(j), j, "Il perd les %d points de son tour" % _tour_pts)
			await pause(1.8)
			return
		var tous := _choix_ia(_reserve, true)
		var pts_tous: int = points(piste.valeurs(tous)).points
		var potentiel := _tour_pts + pts_tous
		var reste_n := _reserve.size() - tous.size()
		var peut: bool = _ouvert[j] or potentiel >= OUVERTURE
		for d in tous:
			piste.halo(d, OR_HALO)
		if peut and (_points[j] + potentiel >= OBJECTIF or potentiel >= 700 * risque or (potentiel >= 350 * risque and reste_n <= 2 and reste_n > 0)):
			_ouvert[j] = true
			_points[j] += potentiel
			_ecrire_statut("%s banque %d points" % [_nom(j), potentiel], j, "Total : %d" % _points[j])
			await pause(1.2)
			await _mettre_de_cote(tous)
			await pause(0.8)
			return
		var choix := _choix_ia(_reserve, false)
		var pts: int = points(piste.valeurs(choix)).points
		_tour_pts += pts
		for d in _reserve:
			piste.halo(d, OR_HALO if choix.has(d) else AUCUN)
		_ecrire_statut("%s garde %d points" % [_nom(j), pts], j, "%d en jeu ce tour" % _tour_pts)
		await pause(1.1)
		if id != _partie:
			return
		var reste: Array = []
		for d in _reserve:
			if not choix.has(d):
				reste.append(d)
		if reste.is_empty():
			_ecrire_statut("Main pleine pour %s !" % _nom(j).to_lower(), j)
			await _remettre_en_jeu()
			_reserve = piste.des.duplicate()
		else:
			await _mettre_de_cote(choix)
			_reserve = reste


func _de_choisi(d: Dictionary) -> void:
	if not _selection_active or not _reserve.has(d):
		app.sons.jouer("refus")
		return
	d.garde = not d.garde
	piste.halo(d, OR_HALO if d.garde else AUCUN)
	app.sons.jouer("clic")
	proposer(_actions_humain(_humain_actuel, true))
