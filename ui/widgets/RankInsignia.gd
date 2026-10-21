class_name RankInsignia
extends Control
## Round badge for an account rank (PlayerRanks tiers 0–12), drawn with the same insignia family
## as the pieces: chevrons for enlisted, triangles for lieutenants and captains, suns for field
## officers and stars for generals.
##
##     row.add_child(RankInsignia.new(profile.rank_tier, 40))

const MARKS := [
	["chevron", 1], ["chevron", 3],
	["triangle", 1], ["triangle", 2], ["triangle", 3],
	["sun", 1], ["sun", 2], ["sun", 3],
	["star", 1], ["star", 2], ["star", 3], ["star", 4], ["star", 5],
]

var tier := 0


func _init(rank_tier := 0, diameter := 40.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	set_tier(rank_tier)


func set_tier(rank_tier: Variant) -> void:
	tier = PlayerRanks.clamp_tier(rank_tier)
	tooltip_text = PlayerRanks.name_of(tier)
	queue_redraw()


func _draw() -> void:
	var diameter := minf(size.x, size.y)
	var center := size / 2.0
	var radius := diameter / 2.0
	draw_circle(center, radius, AppTheme.INK, true, -1.0, true)
	draw_circle(center, radius * 0.86, PlayerRanks.color_of(tier), true, -1.0, true)
	var shape: String = MARKS[tier][0]
	var count: int = MARKS[tier][1]
	var ink := AppTheme.INK if tier > 1 else Color.WHITE
	if shape == "chevron":
		for i in count:
			_chevron(center + Vector2(0, (i - (count - 1) / 2.0) * radius * 0.3), radius * 0.5, ink)
		return
	var mark := radius * (0.42 if count == 1 else 0.3 if count <= 3 else 0.24)
	var spread := radius * (0.0 if count == 1 else 0.5)
	for i in count:
		var pos := center
		if count > 1:
			# Fan the marks along a shallow arc so up to five fit inside the badge.
			var angle := lerpf(-0.55, 0.55, i / float(count - 1)) * (1.0 if count <= 3 else 1.35)
			pos = center + Vector2(sin(angle) * spread * (1.0 if count <= 3 else 1.25), -cos(angle) * spread * 0.35 + spread * 0.18)
		match shape:
			"triangle":
				_polygon(_star_points(pos, mark, mark, 3), ink)
			"sun":
				_sun(pos, mark, ink)
			_:
				_polygon(_star_points(pos, mark, mark * 0.45, 5), ink)


func _chevron(pos: Vector2, half_width: float, color: Color) -> void:
	var depth := half_width * 0.45
	var thick := half_width * 0.28
	_polygon(PackedVector2Array([
		pos + Vector2(-half_width, -depth / 2.0), pos + Vector2(0, depth / 2.0), pos + Vector2(half_width, -depth / 2.0),
		pos + Vector2(half_width, -depth / 2.0 + thick), pos + Vector2(0, depth / 2.0 + thick),
		pos + Vector2(-half_width, -depth / 2.0 + thick),
	]), color)


func _sun(pos: Vector2, radius: float, color: Color) -> void:
	_polygon(_star_points(pos, radius, radius * 0.62, 8), color)
	draw_circle(pos, radius * 0.38, PlayerRanks.color_of(tier), true, -1.0, true)
	draw_circle(pos, radius * 0.24, color, true, -1.0, true)


func _star_points(pos: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var steps := points * 2 if inner < outer else points
	for i in steps:
		var r := outer if inner >= outer or i % 2 == 0 else inner
		result.append(pos + Vector2.from_angle(-PI / 2.0 + TAU * i / steps) * r)
	return result


func _polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	# Polygons have hard pixel edges; a thin antialiased outline in the same colour smooths them.
	draw_polyline(points + PackedVector2Array([points[0]]), color, 1.0, true)
