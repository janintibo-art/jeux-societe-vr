extends "res://scripts/jeux/jeu_des.gd"
## Le 421 (mêmes règles que « Les Dés du Comptoir ») :
## - Charge : 21 fiches au pot. À chaque manche, le meneur lance jusqu'à 3 fois et fixe
##   le nombre de lancers de l'adversaire. Le perdant (plus faible combinaison) reçoit
##   du pot autant de fiches que vaut la meilleure combinaison.
## - Si un joueur sort de la charge sans fiche, il gagne ; sinon vient la décharge :
##   le gagnant de la manche donne ses fiches au perdant. Le premier à 0 fiche gagne.
## - Égalité des plus faibles : « rampeau », un lancer chacun pour départager.
## Valeurs : 421 = 8 fiches · 111 = 7 · paire d'as + n = n · brelan de n = n ·
## suite = 2 · autre = 1 · nénette (2-2-1) = la pire combinaison.

const NIVEAUX := [
	{"nom": "Prudent", "risque": 0.7},
	{"nom": "Normal", "risque": 1.0},
	{"nom": "Audacieux", "risque": 1.3},
]
const POT_DEPART := 21

var _fiches := {1: 0, 2: 0}
var _pot := POT_DEPART
var _phase := "charge"
var _choix_des := false
var _jetons := {0: [], 1: [], 2: []}
var _geo_jeton: CylinderMesh
var _mats := {}


func _init(p_app) -> void:
	super()
	app = p_app


func _ready() -> void:
	for j in [0, 1, 2]:
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color(0.85, 0.82, 0.74), Color(0.72, 0.1, 0.12), Color(0.12, 0.3, 0.7)][j]
		m.roughness = 0.35
		_mats[j] = m
	_geo_jeton = CylinderMesh.new()
	_geo_jeton.top_radius = 0.019
	_geo_jeton.bottom_radius = 0.019
	_geo_jeton.height = 0.006
	_geo_jeton.radial_segments = 24
	_creer_piste(3)
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
	return "Fiches"


func _texte_score(j: int) -> String:
	return str(_fiches[j])


func _partie_entamee() -> bool:
	return _pot < POT_DEPART or _phase != "charge"


# ------------------------------------------------------------------ combinaisons

## Renvoie {rang, nom, fiches} pour 3 valeurs.
static func evaluer(v: Array) -> Dictionary:
	var s := v.duplicate()
	s.sort()
	s.reverse()
	var code := "%d%d%d" % [s[0], s[1], s[2]]
	if code == "421":
		return {"rang": 1000.0, "nom": "421 !", "fiches": 8}
	if code == "111":
		return {"rang": 990.0, "nom": "Brelan d’as", "fiches": 7}
	if code == "221":
		return {"rang": 0.0, "nom": "Nénette (2·2·1)", "fiches": 1}
	if s[1] == 1 and s[2] == 1:
		return {"rang": 600.0 + s[0], "nom": "Paire d’as et %d" % s[0], "fiches": s[0]}
	if s[0] == s[1] and s[1] == s[2]:
		return {"rang": 600.0 + s[0] - 0.5, "nom": "Brelan de %d" % s[0], "fiches": s[0]}
	if s[0] == s[1] + 1 and s[1] == s[2] + 1:
		return {"rang": 500.0 + s[0], "nom": "Suite %d-%d-%d" % [s[2], s[1], s[0]], "fiches": 2}
	return {"rang": 100.0 + s[0] * 10 + s[1] + s[2] / 10.0, "nom": "%d · %d · %d" % [s[0], s[1], s[2]], "fiches": 1}


# ------------------------------------------------------------------ jetons

func _pos_jeton(tas: int, k: int) -> Vector3:
	var base: Vector3 = [Vector3(-0.44, 0, -0.08), Vector3(-0.38, 0, 0.24), Vector3(0.4, 0, -0.3)][tas]
	var pile := k / 12
	var h := k % 12
	return base + Vector3(pile * 0.042, 0.003 + 0.003 + h * 0.0062, 0)


func _ajouter_jeton(tas: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _geo_jeton
	m.material_override = _mats[tas]
	m.position = _pos_jeton(tas, _jetons[tas].size())
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(m)
	_jetons[tas].append(m)
	return m


## Fait voler n jetons d'un tas à un autre.
func _transferer(de: int, vers: int, n: int) -> void:
	for k in n:
		if _jetons[de].is_empty():
			break
		var m: MeshInstance3D = _jetons[de].pop_back()
		var cible := _pos_jeton(vers, _jetons[vers].size())
		_jetons[vers].append(m)
		var tw := create_tween()
		tw.tween_method(_voler.bind(m, m.position, cible), 0.0, 1.0, 0.4).set_delay(k * 0.07)
		tw.tween_callback(app.sons.jouer_a.bind("clac", global_position + cible, -14.0))
	await pause(0.45 + n * 0.07)


func _voler(u: float, m: Node3D, de: Vector3, vers: Vector3) -> void:
	m.position = de.lerp(vers, u) + Vector3(0, sin(u * PI) * 0.12, 0)


# ------------------------------------------------------------------ déroulement

func _preparer_partie() -> void:
	masquer_actions()
	for tas in [0, 1, 2]:
		_faire_sortir(_jetons[tas])
		_jetons[tas] = []
	_fiches = {1: 0, 2: 0}
	_pot = POT_DEPART
	_phase = "charge"
	for k in POT_DEPART:
		_faire_apparaitre(_ajouter_jeton(0), k * 0.02)
	for d in piste.des:
		d.garde = false
		piste.halo(d, AUCUN)
	_partie_421(_partie)


func _partie_421(id: int) -> void:
	var meneur := _joueur
	_ecrire_statut("Charge : 21 fiches au pot", 0, "Moins vous ramassez de fiches, mieux c’est !")
	await pause(1.6)
	while id == _partie:
		var ordre := [meneur, 3 - meneur]
		var r1: Dictionary = await _jouer_tour(ordre[0], 3, -1.0, id)
		if id != _partie:
			return
		_ecrire_statut("%s : %s" % [_nom(ordre[0]), r1.combo.nom], ordre[0],
			"%s a %d lancer%s pour faire mieux" % [_nom(ordre[1]), r1.lancers, "s" if r1.lancers > 1 else ""])
		await pause(1.8)
		if id != _partie:
			return
		var r2: Dictionary = await _jouer_tour(ordre[1], r1.lancers, r1.combo.rang, id)
		if id != _partie:
			return
		var res := {ordre[0]: r1.combo, ordre[1]: r2.combo}
		# Rampeau en cas d'égalité
		while res[1].rang == res[2].rang and id == _partie:
			_ecrire_statut("Égalité : rampeau !", 0, "Un lancer chacun pour départager")
			await pause(1.5)
			for j in ordre:
				if id != _partie:
					return
				var r: Dictionary = await _jouer_tour(j, 1, -1.0, id, true)
				res[j] = r.combo
		if id != _partie:
			return
		var perdant := 1 if res[1].rang < res[2].rang else 2
		var gagnant := 3 - perdant
		var n: int = res[gagnant].fiches
		var phrase := ""
		if _phase == "charge":
			n = mini(n, _pot)
			_pot -= n
			_fiches[perdant] += n
			phrase = "%s ramasse %d fiche%s du pot" % [_nom(perdant), n, "s" if n > 1 else ""]
			_ecrire_statut(phrase, perdant, "%s : %s" % [_nom(gagnant), res[gagnant].nom])
			await _transferer(0, perdant, n)
		else:
			n = mini(n, _fiches[gagnant])
			_fiches[gagnant] -= n
			_fiches[perdant] += n
			phrase = "%s donne %d fiche%s à %s" % [_nom(gagnant), n, "s" if n > 1 else "", "vous" if perdant == 1 and _mode == "ia" else _nom(perdant)]
			_ecrire_statut(phrase, gagnant, "avec %s" % res[gagnant].nom)
			await _transferer(gagnant, perdant, n)
		if id != _partie:
			return
		_rafraichir_boutons()
		await pause(1.4)
		if id != _partie:
			return
		meneur = perdant
		if _phase == "charge" and _pot == 0:
			for j in [1, 2]:
				if _fiches[j] == 0:
					_fin_421(j, "%s sort de la charge sans une fiche" % _nom(j))
					return
			_phase = "decharge"
			_ecrire_statut("La charge est terminée", 0, "Place à la décharge : videz vos fiches chez l’adversaire")
			await pause(2.2)
		elif _phase == "decharge" and _fiches[gagnant] == 0:
			_fin_421(gagnant, "%s s’est débarrassé de toutes ses fiches" % _nom(gagnant))
			return


func _fin_421(gagnant: int, detail: String) -> void:
	masquer_actions()
	_annoncer_fin(gagnant, detail)
	_rafraichir_boutons()
	if not (_mode == "ia" and gagnant == 2):
		_confettis.lancer(Vector3(0, 0.1, 0))


## Un tour de jeu. Renvoie {combo, lancers}.
func _jouer_tour(j: int, max_lancers: int, a_battre: float, id: int, rampeau := false) -> Dictionary:
	for d in piste.des:
		d.garde = false
		piste.halo(d, AUCUN)
	await piste.aligner(piste.des)
	if id != _partie:
		return {}
	var humain := _mode == "duo" or j == 1
	var lancers := 0
	var combo := {}
	while lancers < max_lancers:
		if humain:
			var titre := "À vous" if _mode == "ia" else "À %s" % _nom(j).to_lower()
			_ecrire_statut(titre if lancers == 0 else "%s : %s" % [_nom(j), combo.nom], j,
				"Touchez un dé pour le garder, puis relancez" if lancers > 0 else "%d lancer%s au plus" % [max_lancers, "s" if max_lancers > 1 else ""])
			_choix_des = lancers > 0
			var options := [["lancer", "Lancer (%d/%d)" % [lancers + 1, max_lancers], true]]
			if not rampeau:
				options.append(["rester", "Je reste", lancers > 0])
			var a := await demander(options)
			_choix_des = false
			if id != _partie:
				return {}
			if a == "rester":
				break
		else:
			_ecrire_statut("%s lance les dés…" % _nom(j), j)
			await pause(0.6)
			if id != _partie:
				return {}
		var a_lancer: Array = []
		for d in piste.des:
			if not d.garde:
				a_lancer.append(d)
		await piste.lancer(a_lancer)
		if id != _partie:
			return {}
		lancers += 1
		combo = evaluer(piste.valeurs(piste.des))
		if combo.rang >= 1000.0 or rampeau:
			_ecrire_statut("%s : %s" % [_nom(j), combo.nom], j)
			await pause(1.0)
			break
		if not humain:
			_ecrire_statut("%s : %s" % [_nom(j), combo.nom], j)
			await pause(1.0)
			if id != _partie:
				return {}
			var seuil: float = 604.5 + (NIVEAUX[_niveau].risque - 1.0) * 160.0
			var bat: bool = combo.rang > a_battre if a_battre >= 0.0 else combo.rang >= seuil
			if bat or lancers >= max_lancers:
				break
			_garder_ia()
			var g := 0
			for d in piste.des:
				if d.garde:
					g += 1
			_ecrire_statut("%s garde %d dé%s et relance" % [_nom(j), g, "s" if g > 1 else ""] if g > 0 else "%s relance tout" % _nom(j), j)
			await pause(0.9)
			if id != _partie:
				return {}
	for d in piste.des:
		piste.halo(d, AUCUN)
	return {"combo": combo, "lancers": maxi(lancers, 1)}


## L'ordinateur vise le 421, sinon garde ses as, sinon une paire.
func _garder_ia() -> void:
	for d in piste.des:
		d.garde = false
		piste.halo(d, AUCUN)
	var vals: Array = piste.valeurs(piste.des)
	var pris := {}
	var gardes: Array = []
	for k in 3:
		var v: int = vals[k]
		if v in [4, 2, 1] and not pris.has(v):
			pris[v] = true
			gardes.append(k)
	if gardes.size() < 2:
		gardes = []
		for k in 3:
			if vals[k] == 1:
				gardes.append(k)
		if gardes.is_empty():
			for v in [6, 5, 4, 3]:
				if vals.count(v) >= 2:
					for k in 3:
						if vals[k] == v and gardes.size() < 2:
							gardes.append(k)
					break
	for k in gardes:
		piste.des[k].garde = true
		piste.halo(piste.des[k], OR_HALO)


func _de_choisi(d: Dictionary) -> void:
	if not _choix_des:
		app.sons.jouer("refus")
		return
	d.garde = not d.garde
	piste.halo(d, OR_HALO if d.garde else AUCUN)
	app.sons.jouer("clic")
