class_name InsigniaFactory
extends RefCounted
## Procedural geometry for the toy/anime look, so no external models are needed:
## - rank insignia (stars, suns, triangles, chevrons, eye, flag) as extruded "stickers" with a dark
##   outline backing,
## - chunky beveled slabs for piece bodies, tiles and the board frame (with smooth rounded corners
##   so cel shading bands stay clean),
## - flat shapes for comic-style effects (burst stars, speed lines, discs).
## Insignia meshes fit a 1×1 square on the XY plane and are extruded toward +Z (the piece face).
## Everything is cached.

const DEPTH := 0.14
const STICKER_OUTLINE := 0.14  ## Outline width around an insignia, relative to its 1×1 size.

static var _cache: Dictionary = {}


static func get_mesh(shape: String) -> ArrayMesh:
	if not _cache.has(shape):
		_cache[shape] = extrude(outline(shape), DEPTH)
	return _cache[shape]


## Two surfaces: 0 = the insignia, 1 = a slightly larger, thinner dark backing that reads as an
## ink outline from the front.
static func get_sticker_mesh(shape: String) -> ArrayMesh:
	var key := "sticker/" + shape
	if not _cache.has(key):
		var mesh := ArrayMesh.new()
		_add_surface(mesh, get_mesh(shape))
		_add_surface(mesh, extrude(offset(outline(shape), STICKER_OUTLINE), DEPTH * 0.55))
		_cache[key] = mesh
	return _cache[key]


## A chunky slab of `size` (x, y outline; z thickness) centred on the origin, with rounded corners
## and beveled front/back edges. Grow it with `grow` to get a matching outline hull.
static func get_slab_mesh(size: Vector3, radius: float, bevel := 0.0, grow := 0.0) -> ArrayMesh:
	var key := "slab/%s/%s/%s/%s" % [size, radius, bevel, grow]
	if not _cache.has(key):
		var grown := size + Vector3.ONE * grow * 2.0
		_cache[key] = _beveled_slab(grown, radius + grow, bevel, 6)
	return _cache[key]


## Flat single-sided polygon on the XY plane facing +Z (for billboards and decals).
static func flat_mesh(poly: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var a := poly[tris[i]]
		var b := poly[tris[i + 1]]
		var c := poly[tris[i + 2]]
		_tri(st, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), Vector3(c.x, c.y, 0.0), Vector3.BACK)
	return st.commit()


## Comic "speed lines": thin wedges radiating between `inner` and `outer` radius.
static func speed_lines_mesh(count: int, inner: float, outer: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var angle := TAU * (i + randf_range(-0.25, 0.25)) / count
		var length := randf_range(0.75, 1.0)
		var dir := Vector2(cos(angle), sin(angle))
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		var base := dir * inner
		var tip := dir * lerpf(inner, outer, length)
		_tri(st, Vector3(base.x + side.x, base.y + side.y, 0.0), Vector3(base.x - side.x, base.y - side.y, 0.0),
			Vector3(tip.x, tip.y, 0.0), Vector3.BACK)
	return st.commit()


static func rounded_rect(size: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var half := size * 0.5 - Vector2(radius, radius)
	var corners := [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	for c in 4:
		for s in segments + 1:
			var angle := (c + float(s) / segments) * PI / 2.0
			poly.append(corners[c] + Vector2(cos(angle), sin(angle)) * radius)
	return poly


## Grows (or shrinks, with a negative delta) a polygon with rounded joins.
static func offset(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	var result := Geometry2D.offset_polygon(poly, delta, Geometry2D.JOIN_ROUND)
	var best := poly
	var best_area := 0.0
	for candidate: PackedVector2Array in result:
		var area := absf(_signed_area(candidate))
		if area > best_area:
			best_area = area
			best = candidate
	return best


static func outline(shape: String) -> PackedVector2Array:
	match shape:
		"star":
			return _star(5, 0.5, 0.24)
		"sun":
			return _star(8, 0.5, 0.32)
		"triangle":
			# Inner radius just over the inradius (0.25) so no three points are collinear.
			return _star(3, 0.5, 0.27)
		"chevron":
			return PackedVector2Array([
				Vector2(-0.5, -0.02), Vector2(0.0, 0.32), Vector2(0.5, -0.02),
				Vector2(0.5, -0.26), Vector2(0.0, 0.08), Vector2(-0.5, -0.26),
			])
		"eye":
			return _lens(0.5, 0.26, 12)
		"flag":
			return PackedVector2Array([
				Vector2(-0.42, -0.5), Vector2(-0.28, -0.5), Vector2(-0.28, 0.02),
				Vector2(0.45, 0.02), Vector2(0.28, 0.26), Vector2(0.45, 0.5), Vector2(-0.42, 0.5),
			])
		"burst":
			return _star(14, 0.5, 0.32)
		"disc":
			return _star(16, 0.5, 0.5)
	return _star(4, 0.45, 0.45)


## Extrudes a simple polygon from z = 0 (back) to z = depth (front) with flat normals.
static func extrude(poly: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var a := poly[tris[i]]
		var b := poly[tris[i + 1]]
		var c := poly[tris[i + 2]]
		_tri(st, Vector3(a.x, a.y, depth), Vector3(b.x, b.y, depth), Vector3(c.x, c.y, depth), Vector3.BACK)
		_tri(st, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), Vector3(c.x, c.y, 0.0), Vector3.FORWARD)

	var ccw := _signed_area(poly) > 0.0
	var n := poly.size()
	for i in n:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		var edge := p1 - p0
		var out := Vector2(edge.y, -edge.x) if ccw else Vector2(-edge.y, edge.x)
		var normal := Vector3(out.x, out.y, 0.0).normalized()
		var f0 := Vector3(p0.x, p0.y, depth)
		var f1 := Vector3(p1.x, p1.y, depth)
		var b0 := Vector3(p0.x, p0.y, 0.0)
		var b1 := Vector3(p1.x, p1.y, 0.0)
		_tri(st, f0, b0, b1, normal)
		_tri(st, f0, b1, f1, normal)
	return st.commit()


## Rounded slab with beveled edges and analytic smooth normals around the corners.
static func _beveled_slab(size: Vector3, radius: float, bevel: float, segments: int) -> ArrayMesh:
	var hz := size.z * 0.5
	bevel = minf(bevel, minf(hz * 0.9, radius * 0.9))
	var outer := rounded_rect(Vector2(size.x, size.y), radius, segments)
	var inner := rounded_rect(Vector2(size.x, size.y) - Vector2.ONE * bevel * 2.0, maxf(radius - bevel, 0.001), segments)
	var dirs := PackedVector2Array()
	for c in 4:
		for s in segments + 1:
			var angle := (c + float(s) / segments) * PI / 2.0
			dirs.append(Vector2(cos(angle), sin(angle)))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(inner)
	for i in range(0, tris.size(), 3):
		var a := inner[tris[i]]
		var b := inner[tris[i + 1]]
		var c := inner[tris[i + 2]]
		_tri(st, Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(c.x, c.y, hz), Vector3.BACK)
		_tri(st, Vector3(a.x, a.y, -hz), Vector3(b.x, b.y, -hz), Vector3(c.x, c.y, -hz), Vector3.FORWARD)

	# Rings from front to back: inner@front, outer@front-bevel, outer@back+bevel, inner@back.
	var rings := [[inner, hz, 1.0], [outer, hz - bevel, 0.0], [outer, -hz + bevel, 0.0], [inner, -hz, -1.0]]
	var bevel_tilt := 1.0 if bevel > 0.0 else 0.0
	for r in 3:
		var ring_a: Array = rings[r]
		var ring_b: Array = rings[r + 1]
		# Side band (r == 1) faces straight out; bevel bands lean toward the face they meet.
		var lean := 0.0 if r == 1 else (bevel_tilt if r == 0 else -bevel_tilt)
		var a_poly: PackedVector2Array = ring_a[0]
		var b_poly: PackedVector2Array = ring_b[0]
		for i in a_poly.size():
			var j := (i + 1) % a_poly.size()
			var n0 := Vector3(dirs[i].x, dirs[i].y, lean).normalized()
			var n1 := Vector3(dirs[j].x, dirs[j].y, lean).normalized()
			var a0 := Vector3(a_poly[i].x, a_poly[i].y, ring_a[1])
			var a1 := Vector3(a_poly[j].x, a_poly[j].y, ring_a[1])
			var b0 := Vector3(b_poly[i].x, b_poly[i].y, ring_b[1])
			var b1 := Vector3(b_poly[j].x, b_poly[j].y, ring_b[1])
			if a0.is_equal_approx(b0) and a1.is_equal_approx(b1):
				continue
			_tri_smooth(st, [a0, b0, b1], [n0, n0, n1])
			_tri_smooth(st, [a0, b1, a1], [n0, n1, n1])
	return st.commit()


static func _add_surface(target: ArrayMesh, source: ArrayMesh) -> void:
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(0))


## Godot treats clockwise triangles (seen from the side the normal points to) as front faces.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for v in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)


static func _tri_smooth(st: SurfaceTool, verts: Array, normals: Array) -> void:
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	var order := [0, 1, 2]
	if (verts[1] - verts[0]).cross(verts[2] - verts[0]).dot(facing) > 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_normal(normals[k])
		st.add_vertex(verts[k])


static func _signed_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		area += p0.x * p1.y - p1.x * p0.y
	return area * 0.5


static func _star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in points * 2:
		var radius := outer if i % 2 == 0 else inner
		var angle := PI / 2.0 + i * PI / points
		poly.append(Vector2(cos(angle), sin(angle)) * radius)
	return poly


static func _lens(half_width: float, half_height: float, steps: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		poly.append(Vector2(lerpf(-half_width, half_width, t), sin(PI * t) * half_height))
	for i in range(steps - 1, 0, -1):
		var t := float(i) / steps
		poly.append(Vector2(lerpf(-half_width, half_width, t), -sin(PI * t) * half_height))
	return poly
