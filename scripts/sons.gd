extends Node
## Sons synthétisés au démarrage (aucun fichier audio). jouer(nom) en 2D, jouer_a(nom, position) en 3D.

const FREQ := 22050

var _flux := {}
var _lecteurs: Array[AudioStreamPlayer] = []
var _lecteurs_3d: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 42
	_flux["survol"] = _ton([[1500.0, 0.0]], 0.035, 0.12, "sinus")
	_flux["clic"] = _ton([[900.0, 1300.0]], 0.07, 0.3, "triangle")
	_flux["refus"] = _concat([_ton([[240.0, 0.0]], 0.1, 0.18, "carre"), _ton([[180.0, 0.0]], 0.14, 0.18, "carre")], 0.08)
	_flux["souffle"] = _bruit(0.28, 0.35, 0.25)
	for i in 3:
		_flux["clac%d" % i] = _clac(380.0 + i * 45.0)
	_flux["victoire"] = _concat([
		_ton([[523.25, 0.0]], 0.35, 0.3, "triangle"), _ton([[659.25, 0.0]], 0.35, 0.3, "triangle"),
		_ton([[783.99, 0.0]], 0.35, 0.3, "triangle"), _ton([[1046.5, 0.0]], 0.7, 0.3, "triangle"),
	], 0.11)
	_flux["defaite"] = _concat([
		_ton([[392.0, 0.0]], 0.3, 0.25, "triangle"), _ton([[349.23, 0.0]], 0.3, 0.25, "triangle"),
		_ton([[311.13, 0.0]], 0.3, 0.25, "triangle"), _ton([[261.63, 0.0]], 0.5, 0.25, "triangle"),
	], 0.14)
	_flux["nul"] = _concat([_ton([[440.0, 0.0]], 0.25, 0.25, "triangle"), _ton([[440.0, 0.0]], 0.25, 0.25, "triangle")], 0.2)
	_flux["feu"] = _crepitement(4.0)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_lecteurs.append(p)
	for i in 4:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 1.5
		p3.max_distance = 12.0
		add_child(p3)
		_lecteurs_3d.append(p3)


func jouer(nom: String, volume_db := 0.0) -> void:
	if not _flux.has(nom):
		return
	for p in _lecteurs:
		if not p.playing:
			p.stream = _flux[nom]
			p.volume_db = volume_db
			p.play()
			return


func jouer_a(nom: String, ou: Vector3, volume_db := 0.0) -> void:
	if nom == "clac":
		nom = "clac%d" % _rng.randi_range(0, 2)
	if not _flux.has(nom):
		return
	for p in _lecteurs_3d:
		if not p.playing:
			p.global_position = ou
			p.stream = _flux[nom]
			p.volume_db = volume_db
			p.pitch_scale = _rng.randf_range(0.94, 1.06)
			p.play()
			return


## Lecteur en boucle positionné (le feu de cheminée).
func ambiance(nom: String, parent: Node3D, volume_db := -8.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _flux[nom]
	p.volume_db = volume_db
	p.unit_size = 2.0
	p.max_distance = 14.0
	p.autoplay = true
	parent.add_child(p)
	return p


# ------------------------------------------------------------------ synthèse

func _wav(echantillons: PackedFloat32Array, boucle := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(echantillons.size() * 2)
	for i in echantillons.size():
		data.encode_s16(i * 2, int(clampf(echantillons[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = FREQ
	w.stereo = false
	w.data = data
	if boucle:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = echantillons.size()
	return w


func _onde(forme: String, phase: float) -> float:
	match forme:
		"triangle":
			return 1.0 - 4.0 * abs(fposmod(phase, 1.0) - 0.5)
		"carre":
			return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
		_:
			return sin(phase * TAU)


func _samples_ton(f0: float, f1: float, duree: float, vol: float, forme: String) -> PackedFloat32Array:
	var n := int(duree * FREQ)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := f0 if f1 <= 0.0 else f0 * pow(f1 / f0, t)
		phase += f / FREQ
		var env := minf(1.0, i / (0.008 * FREQ)) * pow(1.0 - t, 2.0)
		out[i] = _onde(forme, phase) * env * vol
	return out


func _ton(segments: Array, duree: float, vol: float, forme: String) -> AudioStreamWAV:
	var s: Array = segments[0]
	return _wav(_samples_ton(s[0], s[1], duree, vol, forme))


func _concat(flux: Array, ecart: float) -> AudioStreamWAV:
	var total := 0
	var parts: Array[PackedFloat32Array] = []
	for w in flux:
		var d: PackedByteArray = w.data
		var f := PackedFloat32Array()
		f.resize(d.size() / 2)
		for i in f.size():
			f[i] = d.decode_s16(i * 2) / 32000.0
		parts.append(f)
	var pas := int(ecart * FREQ)
	total = pas * (parts.size() - 1) + parts[parts.size() - 1].size()
	for i in parts.size():
		total = max(total, pas * i + parts[i].size())
	var out := PackedFloat32Array()
	out.resize(total)
	for i in parts.size():
		var p := parts[i]
		for j in p.size():
			out[pas * i + j] += p[j]
	return _wav(out)


func _bruit(duree: float, vol: float, coupure: float) -> AudioStreamWAV:
	var n := int(duree * FREQ)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var env := sin(t * PI)
		y += (_rng.randf_range(-1.0, 1.0) - y) * coupure
		out[i] = y * env * vol
	return _wav(out)


func _clac(freq: float) -> AudioStreamWAV:
	var n := int(0.09 * FREQ)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var bruit := _rng.randf_range(-1.0, 1.0) * pow(1.0 - t, 8.0) * 0.6
		phase += freq * (1.0 - t * 0.4) / FREQ
		var corps := sin(phase * TAU) * pow(1.0 - t, 4.0) * 0.45
		out[i] = bruit + corps
	return _wav(out)


func _crepitement(duree: float) -> AudioStreamWAV:
	var n := int(duree * FREQ)
	var out := PackedFloat32Array()
	out.resize(n)
	var grondement := 0.0
	for i in n:
		grondement += (_rng.randf_range(-1.0, 1.0) - grondement) * 0.02
		out[i] = grondement * 0.5
	var nb := int(duree * 14.0)
	for k in nb:
		var debut := _rng.randi_range(0, n - 400)
		var longueur := _rng.randi_range(40, 300)
		var force := _rng.randf_range(0.15, 0.6)
		for j in longueur:
			var t := float(j) / longueur
			out[debut + j] += _rng.randf_range(-1.0, 1.0) * force * pow(1.0 - t, 3.0)
	return _wav(out, true)
