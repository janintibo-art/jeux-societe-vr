extends RefCounted
## Fabrique de maillages procéduraux (aucun modèle 3D externe).


## Ajoute un triangle en corrigeant l'ordre des sommets pour que la face visible
## soit du côté des normales (Godot : face avant = sens horaire).
static func tri(st: SurfaceTool, v: Array, n: Array, uv: Array = [], col := Color.WHITE) -> void:
	var fn: Vector3 = n[0] + n[1] + n[2]
	var cr: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
	var order := [0, 1, 2]
	if cr.dot(fn) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_normal(n[i])
		st.set_color(col)
		st.set_uv(uv[i] if uv.size() > 0 else Vector2.ZERO)
		st.add_vertex(v[i])


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col := Color.WHITE, uvs: Array = []) -> void:
	var u: Array = uvs if uvs.size() == 4 else [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	tri(st, [a, b, c], [n, n, n], [u[0], u[1], u[2]], col)
	tri(st, [a, c, d], [n, n, n], [u[0], u[2], u[3]], col)


## Solide de révolution. profil : points (rayon, hauteur) du bas vers le haut.
## axe_z : l'axe de révolution devient Z au lieu de Y (jeton debout face à nous).
static func tour(profil: Array, seg := 48, axe_z := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pn: Array = []
	for i in profil.size():
		var a: Vector2 = profil[max(i - 1, 0)]
		var b: Vector2 = profil[min(i + 1, profil.size() - 1)]
		var d := b - a
		var n2 := Vector2(d.y, -d.x).normalized()
		if n2 == Vector2.ZERO:
			n2 = Vector2(0, 1)
		pn.append(n2)
	var pos := func(p: Vector2, ang: float) -> Vector3:
		var x := p.x * cos(ang)
		var z := p.x * sin(ang)
		return Vector3(x, z, p.y) if axe_z else Vector3(x, p.y, z)
	var nor := func(n2: Vector2, ang: float) -> Vector3:
		var x := n2.x * cos(ang)
		var z := n2.x * sin(ang)
		return Vector3(x, z, n2.y) if axe_z else Vector3(x, n2.y, z)
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		for i in profil.size() - 1:
			var p0: Vector2 = profil[i]
			var p1: Vector2 = profil[i + 1]
			var v := [pos.call(p0, a0), pos.call(p0, a1), pos.call(p1, a1), pos.call(p1, a0)]
			var n := [nor.call(pn[i], a0), nor.call(pn[i], a1), nor.call(pn[i + 1], a1), nor.call(pn[i + 1], a0)]
			if p0.x < 0.0001:
				tri(st, [v[0], v[2], v[3]], [n[0], n[2], n[3]])
			elif p1.x < 0.0001:
				tri(st, [v[0], v[1], v[2]], [n[0], n[1], n[2]])
			else:
				tri(st, [v[0], v[1], v[2]], [n[0], n[1], n[2]])
				tri(st, [v[0], v[2], v[3]], [n[0], n[2], n[3]])
	return st.commit()


## Jeton de Puissance 4 : bord bombé, centre creusé, axe le long de Z.
static func jeton(r := 0.0325, ep := 0.013) -> ArrayMesh:
	var t := ep / 2.0
	var p := [
		Vector2(0, -t * 0.6), Vector2(r * 0.6, -t * 0.6), Vector2(r * 0.68, -t), Vector2(r * 0.93, -t),
		Vector2(r, -t * 0.7), Vector2(r, t * 0.7), Vector2(r * 0.93, t), Vector2(r * 0.68, t),
		Vector2(r * 0.6, t * 0.6), Vector2(0, t * 0.6),
	]
	return tour(p, 40, true)


## Plaque percée de trous ronds (grille), dans le plan XY, épaisseur le long de Z.
## La plaque va de x = -largeur/2 à +largeur/2 et de y = y_bas à y_bas + hauteur.
static func plaque_trouee(cols: int, rows: int, cell: float, r_trou: float, marge: float,
		y_bas: float, z_avant: float, z_arriere: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var largeur := cols * cell + 2.0 * marge
	var hauteur := rows * cell + 2.0 * marge
	var x0 := -largeur / 2.0
	var gx0 := -cols * cell / 2.0
	var gy0 := y_bas + marge
	var seg := 28
	for c in cols:
		for r in rows:
			var cx := gx0 + (c + 0.5) * cell
			var cy := gy0 + (r + 0.5) * cell
			var s := cell / 2.0
			for i in seg:
				var a0 := TAU * i / seg
				var a1 := TAU * (i + 1) / seg
				var d0 := Vector2(cos(a0), sin(a0))
				var d1 := Vector2(cos(a1), sin(a1))
				var c0 := Vector2(cx, cy) + d0 * r_trou
				var c1 := Vector2(cx, cy) + d1 * r_trou
				var s0 := Vector2(cx, cy) + d0 * (s / maxf(absf(d0.x), absf(d0.y)))
				var s1 := Vector2(cx, cy) + d1 * (s / maxf(absf(d1.x), absf(d1.y)))
				# Coins du carré : on insère le coin pour garder une case bien carrée
				var coins: Array = []
				for k in 4:
					var ang := PI / 4.0 + k * PI / 2.0
					var ad := fposmod(ang - a0, TAU)
					if ad > 0.0 and ad < (a1 - a0):
						coins.append(Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * s * sqrt(2.0))
				for face in [[z_avant, Vector3(0, 0, 1)], [z_arriere, Vector3(0, 0, -1)]]:
					var z: float = face[0]
					var n: Vector3 = face[1]
					if coins.is_empty():
						quad(st, Vector3(c0.x, c0.y, z), Vector3(s0.x, s0.y, z), Vector3(s1.x, s1.y, z), Vector3(c1.x, c1.y, z), n)
					else:
						var k2: Vector2 = coins[0]
						tri(st, [Vector3(c0.x, c0.y, z), Vector3(s0.x, s0.y, z), Vector3(k2.x, k2.y, z)], [n, n, n])
						tri(st, [Vector3(c0.x, c0.y, z), Vector3(k2.x, k2.y, z), Vector3(c1.x, c1.y, z)], [n, n, n])
						tri(st, [Vector3(c1.x, c1.y, z), Vector3(k2.x, k2.y, z), Vector3(s1.x, s1.y, z)], [n, n, n])
				# Paroi du trou (normale vers l'intérieur du trou)
				var n0 := Vector3(-d0.x, -d0.y, 0)
				var n1 := Vector3(-d1.x, -d1.y, 0)
				tri(st, [Vector3(c0.x, c0.y, z_avant), Vector3(c1.x, c1.y, z_avant), Vector3(c1.x, c1.y, z_arriere)], [n0, n1, n1])
				tri(st, [Vector3(c0.x, c0.y, z_avant), Vector3(c1.x, c1.y, z_arriere), Vector3(c0.x, c0.y, z_arriere)], [n0, n1, n0])
	# Cadre autour de la grille
	var gx1 := -gx0
	var gy1 := gy0 + rows * cell
	var x1 := -x0
	var y1 := y_bas + hauteur
	var bandes := [
		[Vector2(x0, y_bas), Vector2(x1, gy0)],
		[Vector2(x0, gy1), Vector2(x1, y1)],
		[Vector2(x0, gy0), Vector2(gx0, gy1)],
		[Vector2(gx1, gy0), Vector2(x1, gy1)],
	]
	for b in bandes:
		var lo: Vector2 = b[0]
		var hi: Vector2 = b[1]
		for face in [[z_avant, Vector3(0, 0, 1)], [z_arriere, Vector3(0, 0, -1)]]:
			var z: float = face[0]
			quad(st, Vector3(lo.x, lo.y, z), Vector3(hi.x, lo.y, z), Vector3(hi.x, hi.y, z), Vector3(lo.x, hi.y, z), face[1])
	# Tranches extérieures
	var cotes := [
		[Vector3(x0, y_bas, 0), Vector3(x1, y_bas, 0), Vector3(0, -1, 0)],
		[Vector3(x0, y1, 0), Vector3(x1, y1, 0), Vector3(0, 1, 0)],
		[Vector3(x0, y_bas, 0), Vector3(x0, y1, 0), Vector3(-1, 0, 0)],
		[Vector3(x1, y_bas, 0), Vector3(x1, y1, 0), Vector3(1, 0, 0)],
	]
	for cote in cotes:
		var a: Vector3 = cote[0]
		var b2: Vector3 = cote[1]
		quad(st, Vector3(a.x, a.y, z_avant), Vector3(b2.x, b2.y, z_avant), Vector3(b2.x, b2.y, z_arriere), Vector3(a.x, a.y, z_arriere), cote[2])
	return st.commit()


## Cube dont chaque face porte son numéro (1 à 6) dans la couleur de sommet (rouge = n/6).
static func de(taille := 0.07) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := taille / 2.0
	# Faces opposées dont la somme fait 7
	var faces := [
		[Vector3(1, 0, 0), 3], [Vector3(-1, 0, 0), 4], [Vector3(0, 1, 0), 1],
		[Vector3(0, -1, 0), 6], [Vector3(0, 0, 1), 2], [Vector3(0, 0, -1), 5],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var col := Color(float(f[1]) / 6.0, 0, 0)
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		var c := n * h
		quad(st, c - u * h - v * h, c + u * h - v * h, c + u * h + v * h, c - u * h + v * h, n, col)
	return st.commit()


## Rideau plissé : plan vertical ondulé.
static func rideau(largeur: float, hauteur: float, plis := 5.0, profondeur := 0.035) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_seg := 40
	for i in n_seg:
		var xa := -largeur / 2.0 + largeur * i / n_seg
		var xb := -largeur / 2.0 + largeur * (i + 1) / n_seg
		var ka := xa / largeur * TAU * plis
		var kb := xb / largeur * TAU * plis
		var za := sin(ka) * profondeur
		var zb := sin(kb) * profondeur
		var na := Vector3(-cos(ka) * profondeur * TAU * plis / largeur, 0, 1).normalized()
		var nb := Vector3(-cos(kb) * profondeur * TAU * plis / largeur, 0, 1).normalized()
		tri(st, [Vector3(xa, 0, za), Vector3(xb, 0, zb), Vector3(xb, hauteur, zb)], [na, nb, nb])
		tri(st, [Vector3(xa, 0, za), Vector3(xb, hauteur, zb), Vector3(xa, hauteur, za)], [na, nb, na])
	return st.commit()


## Pointe de flèche plate (pointe vers +Z), pour indiquer une direction sur un plateau.
static func fleche(longueur := 0.05, largeur := 0.044, ep := 0.008) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := ep / 2.0
	var pts := [Vector2(0, longueur * 0.55), Vector2(-largeur / 2.0, -longueur * 0.45),
		Vector2(0, -longueur * 0.2), Vector2(largeur / 2.0, -longueur * 0.45)]
	for face in [[h, Vector3.UP], [-h, Vector3.DOWN]]:
		var y: float = face[0]
		var n: Vector3 = face[1]
		var p := []
		for q in pts:
			p.append(Vector3(q.x, y, q.y))
		tri(st, [p[0], p[1], p[2]], [n, n, n])
		tri(st, [p[0], p[2], p[3]], [n, n, n])
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 4]
		var d := b - a
		var n2 := Vector3(d.y, 0, -d.x).normalized()
		var centre := Vector3(0, 0, 0)
		if n2.dot(Vector3((a.x + b.x) / 2.0, 0, (a.y + b.y) / 2.0) - centre) < 0.0:
			n2 = -n2
		quad(st, Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(b.x, -h, b.y), Vector3(a.x, -h, a.y), n2)
	return st.commit()
