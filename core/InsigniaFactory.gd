class_name InsigniaFactory
extends RefCounted
## Builds the raised rank insignia (stars, suns, triangles, chevrons, eye, flag) as extruded meshes
## from 2D outlines, so no external models are needed. Meshes fit a 1×1 square on the XY plane, are
## extruded toward +Z (the piece face), and are cached per shape.

const DEPTH := 0.14

static var _cache: Dictionary = {}


static func get_mesh(shape: String) -> ArrayMesh:
	if not _cache.has(shape):
		_cache[shape] = extrude(outline(shape), DEPTH)
	return _cache[shape]


## A rounded slab of `size` (x, y outline; z thickness) centred on the origin. Used for piece bodies.
static func get_slab_mesh(size: Vector3, radius: float) -> ArrayMesh:
	var key := "slab/%s/%s" % [size, radius]
	if not _cache.has(key):
		var mesh := extrude(rounded_rect(Vector2(size.x, size.y), radius, 5), size.z)
		var centred := ArrayMesh.new()
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var v := vertices[i]
			v.z -= size.z * 0.5
			vertices[i] = v
		arrays[Mesh.ARRAY_VERTEX] = vertices
		centred.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_cache[key] = centred
	return _cache[key]


static func rounded_rect(size: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var half := size * 0.5 - Vector2(radius, radius)
	var corners := [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	for c in 4:
		for s in segments + 1:
			var angle := (c + float(s) / segments) * PI / 2.0
			poly.append(corners[c] + Vector2(cos(angle), sin(angle)) * radius)
	return poly


static func outline(shape: String) -> PackedVector2Array:
	match shape:
		"star":
			return _star(5, 0.5, 0.2)
		"sun":
			return _star(8, 0.5, 0.3)
		"triangle":
			# Inner radius just over the inradius (0.25) so no three points are collinear.
			return _star(3, 0.5, 0.27)
		"chevron":
			return PackedVector2Array([
				Vector2(-0.5, -0.02), Vector2(0.0, 0.32), Vector2(0.5, -0.02),
				Vector2(0.5, -0.24), Vector2(0.0, 0.1), Vector2(-0.5, -0.24),
			])
		"eye":
			return _lens(0.5, 0.24, 12)
		"flag":
			return PackedVector2Array([
				Vector2(-0.42, -0.5), Vector2(-0.3, -0.5), Vector2(-0.3, 0.02),
				Vector2(0.45, 0.02), Vector2(0.28, 0.26), Vector2(0.45, 0.5), Vector2(-0.42, 0.5),
			])
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


## Godot treats clockwise triangles (seen from the side the normal points to) as front faces.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for v in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)


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
