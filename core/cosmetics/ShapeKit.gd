class_name ShapeKit
extends RefCounted
## Tiny procedural modelling kit for chip shapes and table toppers. A model is a list of parts;
## each part is a mesh maker (a Callable taking `grow` and returning a Mesh), a transform and a
## role (chip shapes) or colour (toppers). bake() merges parts into one ArrayMesh with one surface
## per role, plus a single inverted-hull outline mesh made from grown copies of the parts, so a
## whole toy is two draw calls.
##
##     var parts := [ShapeKit.part("body", ShapeKit.sphere(0.3), Transform3D(Basis(), Vector3(0, 0.3, 0)))]
##     var baked := ShapeKit.bake(parts)   # {mesh, roles, hull}

## Lies a slab/prism (outline on XY, thickness on Z) flat on the ground, thickness pointing up.
## The outline's +Y then points to -Z, away from a white-side owner.
const FLAT := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
const OUTLINE := 0.03


## {role, maker, xf, hull (outline width; 0 = no outline)}
static func part(role: Variant, maker: Callable, xf := Transform3D.IDENTITY, hull := OUTLINE) -> Dictionary:
	return {"role": role, "maker": maker, "xf": xf, "hull": hull}


static func at(pos: Vector3, basis := Basis.IDENTITY) -> Transform3D:
	return Transform3D(basis, pos)


# --- Mesh makers (each returns Callable(grow: float) -> Mesh) ------------------------------------

static func sphere(radius: float, height := -1.0, segments := 24) -> Callable:
	return func(grow: float) -> Mesh:
		var m := SphereMesh.new()
		m.radius = radius + grow
		m.height = (radius * 2.0 if height < 0.0 else height) + grow * 2.0
		m.radial_segments = segments
		m.rings = maxi(6, segments / 2)
		return m


static func cylinder(top: float, bottom: float, height: float, segments := 24) -> Callable:
	return func(grow: float) -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = top + grow if top > 0.0 else 0.0
		m.bottom_radius = bottom + grow if bottom > 0.0 else 0.0
		m.height = height + grow * 2.0
		m.radial_segments = segments
		m.rings = 1
		return m


static func cone(radius: float, height: float, segments := 20) -> Callable:
	return cylinder(0.0, radius, height, segments)


static func torus(inner: float, outer: float, rings := 28, ring_segments := 10) -> Callable:
	return func(grow: float) -> Mesh:
		var m := TorusMesh.new()
		m.inner_radius = maxf(0.001, inner - grow)
		m.outer_radius = outer + grow
		m.rings = rings
		m.ring_segments = ring_segments
		return m


static func capsule(radius: float, height: float, segments := 16) -> Callable:
	return func(grow: float) -> Mesh:
		var m := CapsuleMesh.new()
		m.radius = radius + grow
		m.height = maxf(height, radius * 2.0) + grow * 2.0
		m.radial_segments = segments
		m.rings = 6
		return m


## Rounded box: `size` x/y outline with rounded corners, z thickness with beveled edges.
static func box(size: Vector3, radius := 0.05, bevel := 0.02) -> Callable:
	return func(grow: float) -> Mesh:
		return InsigniaFactory.get_slab_mesh(size, minf(radius, minf(size.x, size.y) * 0.49), bevel, grow)


## Beveled prism from an XY outline, z thickness `depth`.
static func prism(poly: PackedVector2Array, depth: float, bevel := 0.02, smooth := false) -> Callable:
	return func(grow: float) -> Mesh:
		return InsigniaFactory.beveled_prism(poly, depth, bevel, grow, smooth)


## Faceted frustum along Y (flat shading): `sides` corners, bottom/top radii, centred on origin.
static func frustum(sides: int, bottom: float, top: float, height: float, angle := 0.0) -> Callable:
	return func(grow: float) -> Mesh:
		return _frustum(sides, bottom + grow, top + grow, height + grow * 2.0, angle)


## Surface of revolution around Y from a (radius, y) profile listed bottom to top, smooth shaded.
## Repeat a point to make a crease. Ends with radius > 0 get flat caps.
static func lathe(profile: PackedVector2Array, segments := 24) -> Callable:
	return func(grow: float) -> Mesh:
		return _lathe(profile, segments, grow)


# --- Baking ------------------------------------------------------------------------------------

## Merges `parts` into {mesh: ArrayMesh (one surface per role, in first-seen order), roles: Array,
## hull: ArrayMesh or null}.
static func bake(parts: Array) -> Dictionary:
	var roles: Array = []
	var tools: Dictionary = {}
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_hull := false
	for p: Dictionary in parts:
		var role: Variant = p["role"]
		var key := str(role)
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			roles.append(role)
		var maker: Callable = p["maker"]
		append(tools[key], maker.call(0.0), p["xf"])
		if p["hull"] > 0.0:
			append(hull, maker.call(p["hull"]), p["xf"])
			has_hull = true
	var mesh := ArrayMesh.new()
	for role: Variant in roles:
		(tools[str(role)] as SurfaceTool).commit(mesh)
	return {"mesh": mesh, "roles": roles, "hull": hull.commit() if has_hull else null}


## Appends `mesh` (surface 0) to `st` transformed by `xf`, as plain position + normal triangles so
## meshes of any format merge.
static func append(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(verts.size())
		for i in verts.size():
			indices[i] = i
	var normal_basis := xf.basis.inverse().transposed()
	var flip := xf.basis.determinant() < 0.0
	for t in range(0, indices.size(), 3):
		var order := [0, 2, 1] if flip else [0, 1, 2]
		for k: int in order:
			var i := indices[t + k]
			st.set_normal((normal_basis * normals[i]).normalized())
			st.add_vertex(xf * verts[i])


static func _frustum(sides: int, bottom: float, top: float, height: float, angle: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := -height * 0.5
	var y1 := height * 0.5
	for i in sides:
		var a0 := angle + TAU * i / sides
		var a1 := angle + TAU * (i + 1) / sides
		var b0 := Vector3(cos(a0) * bottom, y0, sin(a0) * bottom)
		var b1 := Vector3(cos(a1) * bottom, y0, sin(a1) * bottom)
		var t0 := Vector3(cos(a0) * top, y1, sin(a0) * top)
		var t1 := Vector3(cos(a1) * top, y1, sin(a1) * top)
		var mid := (a0 + a1) * 0.5
		var slope := (bottom - top) / height
		var normal := Vector3(cos(mid), slope, sin(mid)).normalized()
		_face(st, [b0, b1, t1], normal)
		_face(st, [b0, t1, t0], normal)
		if top > 0.0:
			_face(st, [Vector3(0, y1, 0), t0, t1], Vector3.UP)
		if bottom > 0.0:
			_face(st, [Vector3(0, y0, 0), b1, b0], Vector3.DOWN)
	return st.commit()


static func _lathe(profile: PackedVector2Array, segments: int, grow: float) -> ArrayMesh:
	var n := profile.size()
	# Outward normal of each profile segment (zero-length segments mark creases).
	var seg: Array[Vector2] = []
	for k in n - 1:
		var d := profile[k + 1] - profile[k]
		seg.append(Vector2(d.y, -d.x).normalized() if d.length_squared() > 1e-10 else Vector2.ZERO)
	var grown := PackedVector2Array()
	for k in n:
		var avg := Vector2.ZERO
		for j in [k - 1, k, k - 2, k + 1]:
			if j >= 0 and j < seg.size() and seg[j] != Vector2.ZERO and (j == k - 1 or j == k or avg == Vector2.ZERO):
				avg += seg[j]
		var p := profile[k] + avg.normalized() * grow
		grown.append(Vector2(maxf(p.x, 0.0), p.y))
	if grow > 0.0:
		grown[0].y -= grow * 0.5
		grown[n - 1].y += grow * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		for k in n - 1:
			if seg[k] == Vector2.ZERO:
				continue
			var p0 := grown[k]
			var p1 := grown[k + 1]
			# Smooth across neighbouring segments; a repeated point (zero segment) keeps a crease.
			var n0 := (seg[k] + seg[k - 1]).normalized() if k > 0 and seg[k - 1] != Vector2.ZERO else seg[k]
			var n1 := (seg[k] + seg[k + 1]).normalized() if k + 1 < seg.size() and seg[k + 1] != Vector2.ZERO else seg[k]
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var m00 := Vector3(cos(a0) * n0.x, n0.y, sin(a0) * n0.x).normalized()
			var m01 := Vector3(cos(a1) * n0.x, n0.y, sin(a1) * n0.x).normalized()
			var m10 := Vector3(cos(a0) * n1.x, n1.y, sin(a0) * n1.x).normalized()
			var m11 := Vector3(cos(a1) * n1.x, n1.y, sin(a1) * n1.x).normalized()
			_smooth(st, [v00, v10, v11], [m00, m10, m11])
			_smooth(st, [v00, v11, v01], [m00, m11, m01])
		if grown[0].x > 0.001:
			var y := grown[0].y
			_face(st, [Vector3(0, y, 0), Vector3(cos(a1) * grown[0].x, y, sin(a1) * grown[0].x),
				Vector3(cos(a0) * grown[0].x, y, sin(a0) * grown[0].x)], Vector3.DOWN)
		if grown[n - 1].x > 0.001:
			var y := grown[n - 1].y
			var r := grown[n - 1].x
			_face(st, [Vector3(0, y, 0), Vector3(cos(a0) * r, y, sin(a0) * r), Vector3(cos(a1) * r, y, sin(a1) * r)], Vector3.UP)
	return st.commit()


## Flat triangle wound so it faces `normal`.
static func _face(st: SurfaceTool, verts: Array, normal: Vector3) -> void:
	var order := [0, 1, 2]
	if (verts[1] - verts[0]).cross(verts[2] - verts[0]).dot(normal) > 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_normal(normal)
		st.add_vertex(verts[k])


static func _smooth(st: SurfaceTool, verts: Array, normals: Array) -> void:
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	var order := [0, 1, 2]
	if (verts[1] - verts[0]).cross(verts[2] - verts[0]).dot(facing) > 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_normal(normals[k])
		st.add_vertex(verts[k])
