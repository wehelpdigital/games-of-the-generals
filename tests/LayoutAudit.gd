class_name LayoutAudit
extends RefCounted
## Finds UI that runs off the side of the screen: the deepest visible controls whose right edge is
## past the viewport (or left edge before it). Screenshot tests call report() with --audit.


static func report(root: Node, tag: String) -> int:
	var view := root.get_viewport().get_visible_rect().size
	var found: Array[String] = []
	_walk(root, view, found)
	for line in found:
		print("OVERFLOW [%s] %s" % [tag, line])
	var causes: Array[String] = []
	_wide(root, view.x - 4.0, causes)
	for line in causes:
		print("TOO WIDE [%s] %s" % [tag, line])
	return found.size()


## The deepest visible containers whose minimum width alone is wider than the screen: these are
## what force a page wider than the phone (rows that need to wrap, stack or clip).
static func _wide(node: Node, limit: float, found: Array[String]) -> bool:
	var child_wide := false
	for child in node.get_children():
		if _wide(child, limit, found):
			child_wide = true
	if not (node is Control) or not (node as Control).is_visible_in_tree() or node is ScrollContainer:
		return child_wide
	var c := node as Control
	var w := c.get_combined_minimum_size().x
	if w > limit and not child_wide:
		var parts: Array[String] = []
		for child in c.get_children():
			if child is Control and (child as Control).visible:
				var label := ""
				if child is Label:
					label = "'%s'" % (child as Label).text.left(18)
				elif child is Button:
					label = "'%s'" % (child as Button).text.left(18)
				parts.append("%s%s=%d" % [child.get_class().left(10), label, (child as Control).get_combined_minimum_size().x])
		found.append("%s min=%d children: %s  (%s)" % [c.get_class(), w, ", ".join(parts), _path(c)])
	return w > limit or child_wide


static func _walk(node: Node, view: Vector2, found: Array[String]) -> bool:
	var child_overflowed := false
	for child in node.get_children():
		if _walk(child, view, found):
			child_overflowed = true
	if not (node is Control) or not (node as Control).is_visible_in_tree():
		return child_overflowed
	var c := node as Control
	if c is ScrollContainer or _clipped(c):
		return child_overflowed  # Content inside a scroll or clip area may be wider by design.
	var rect := c.get_global_rect()
	var over := rect.end.x > view.x + 2.0 or rect.position.x < -2.0
	if over and not child_overflowed and rect.size.x > 0.0:
		var text := ""
		if c is Label:
			text = (c as Label).text
		elif c is Button:
			text = (c as Button).text
		found.append("%s %s x=%d..%d (view %d) min=%d %s" % [c.get_class(), c.name, rect.position.x, rect.end.x, view.x,
			c.get_combined_minimum_size().x, ("\"" + text.left(30) + "\"") if text != "" else _path(c)])
	return over or child_overflowed


static func _clipped(c: Control) -> bool:
	var p := c.get_parent()
	while p is Control:
		if (p as Control).clip_contents and not (p is ScrollContainer):
			return false
		if p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		p = p.get_parent()
	return false


static func _path(c: Control) -> String:
	var parts: Array[String] = []
	var n: Node = c
	for i in 4:
		if n == null:
			break
		parts.push_front(n.name)
		n = n.get_parent()
	return "/".join(parts)
