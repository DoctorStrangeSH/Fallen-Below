extends Node2D
## Draws the map, units and heroes with primitives. Will be replaced by sprites in M1.

const D = preload("res://scripts/data/game_data.gd")

var run  # run.gd


func _process(_delta: float) -> void:
	queue_redraw()


func cell_center(c: Vector2i) -> Vector2:
	return D.MAP_OFFSET + Vector2(c) * D.CELL + Vector2(D.CELL, D.CELL) * 0.5


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(D.MAP_OFFSET + Vector2(c) * D.CELL, Vector2(D.CELL, D.CELL))


func mouse_cell() -> Vector2i:
	var p := (get_global_mouse_position() - D.MAP_OFFSET) / D.CELL
	return Vector2i(floori(p.x), floori(p.y))


func hero_world_pos(h: Dictionary) -> Vector2:
	var path: Array[Vector2i] = run.state.path
	var n := path.size()
	var p: float = h["pos"]
	var i := int(floor(p))
	var a := cell_center(path[posmod(i, n)])
	var b := cell_center(path[posmod(i + 1, n)])
	return a.lerp(b, p - i)


func _draw() -> void:
	if run == null or run.state == null:
		return
	var s = run.state
	var font := ThemeDB.fallback_font
	draw_rect(get_viewport_rect(), Color(0.06, 0.05, 0.08))
	_draw_floor()
	_draw_path(s, font)
	_draw_scenery(s, font)
	_draw_heart(s, font)
	_draw_preview(s)
	_draw_units(s)
	_draw_heroes(s, font)
	if s.paused and not s.game_over:
		var vr := get_viewport_rect()
		draw_string(font, Vector2(0, vr.size.y * 0.42), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, vr.size.x, 40, Color(1, 1, 1, 0.8))


func _draw_floor() -> void:
	for x in range(0, D.LOOP_MAX.x + 2):
		for y in range(0, D.LOOP_MAX.y + 1):
			var r := cell_rect(Vector2i(x, y))
			draw_rect(r, Color(0.1, 0.09, 0.12))
			draw_rect(r, Color(0.13, 0.12, 0.16), false, 1.0)


func _draw_path(s, font: Font) -> void:
	var path: Array[Vector2i] = s.path
	for i in path.size():
		var r := cell_rect(path[i]).grow(-2)
		var card: String = s.tiles[i]["card"]
		var col := Color(0.24, 0.21, 0.27)
		if i == 0:
			col = Color(0.55, 0.45, 0.2)
		elif card != "":
			var cc: Color = D.CARDS[card]["color"]
			col = cc.darkened(0.35)
		draw_rect(r, col)
		if i == 0:
			draw_string(font, r.position + Vector2(0, 30), "GATE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12)
		elif card != "":
			var label: String = D.CARDS[card]["name"]
			draw_string(font, r.position + Vector2(0, 14), label.substr(0, 6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(1, 1, 1, 0.7))


func _draw_scenery(s, font: Font) -> void:
	for c in s.scenery:
		var cell: Vector2i = c
		var r := cell_rect(cell).grow(-6)
		var id: String = s.scenery[c]
		var col: Color = D.CARDS[id]["color"]
		draw_rect(r, col)
		var label: String = D.CARDS[id]["name"]
		draw_string(font, r.position + Vector2(0, 24), label.substr(0, 5).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10)


func _draw_heart(s, font: Font) -> void:
	var center := (cell_center(D.LOOP_MIN) + cell_center(D.LOOP_MAX)) * 0.5 + Vector2(0, 40)
	var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() / 250.0)
	draw_circle(center, 34.0 * pulse, Color(0.5, 0.05, 0.12))
	draw_circle(center, 24.0 * pulse, Color(0.85, 0.15, 0.25))
	var txt := "HEART %d/%d" % [s.heart_hp, s.heart_max]
	draw_string(font, center + Vector2(-60, 58), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 14)


func _draw_preview(s) -> void:
	if s.game_over or not s.pending_souls.is_empty():
		return
	var id: String = run.cards.selected_id()
	if id == "":
		return
	var mc := mouse_cell()
	var ok: bool = run.cards.can_place(id, mc)
	var r := cell_rect(mc)
	draw_rect(r, Color(0.3, 1, 0.4, 0.25) if ok else Color(1, 0.2, 0.2, 0.2))
	draw_rect(r, Color(0.3, 1, 0.4) if ok else Color(1, 0.3, 0.3), false, 2.0)


func _draw_units(s) -> void:
	var path: Array[Vector2i] = s.path
	for i in s.tiles.size():
		var units: Array = s.tiles[i]["units"]
		var k := 0
		for u in units:
			if u["hp"] <= 0.0:
				continue
			var base := D.MAP_OFFSET + Vector2(path[i]) * D.CELL
			var p := base + Vector2(6 + (k % 3) * 13, 22 + (k / 3) * 13)
			var sz := 11.0
			if u["name"] == "Spider Queen":
				sz = 16.0
			if u["undead"]:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(sz + 2, sz + 2)), Color(0.5, 0.9, 1.0))
			var col: Color = u["color"]
			draw_rect(Rect2(p, Vector2(sz, sz)), col)
			var frac: float = clampf(u["hp"] / u["max_hp"], 0.0, 1.0)
			draw_rect(Rect2(p + Vector2(0, sz), Vector2(sz * frac, 2)), Color(0.4, 0.9, 1.0))
			k += 1


func _draw_heroes(s, font: Font) -> void:
	var stack := {}
	for h in s.heroes:
		if h["gone"] or h["delay"] > 0.0:
			continue
		var t: int = s.tile_of(h)
		var n: int = stack.get(t, 0)
		stack[t] = n + 1
		var p := hero_world_pos(h) + Vector2((n % 2) * 14 - 7, (n / 2) * 14 - 10)
		var is_boss: bool = h["boss"]
		var rad := 16.0 if is_boss else 10.0
		if h["nemesis"] or is_boss:
			draw_circle(p, rad + 3, Color(1, 0.2, 0.2))
		var col: Color = h["color"]
		draw_circle(p, rad, col)
		var cls_name: String = D.HERO_CLASSES[h["cls"]]["name"]
		draw_string(font, p + Vector2(-rad, 5), cls_name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 13, Color(0.1, 0.05, 0.05))
		var frac: float = clampf(h["hp"] / h["max_hp"], 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2, 3)), Color(0.2, 0, 0))
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2 * frac, 3)), Color(1, 0.3, 0.3))
		if h["revenge"]:
			draw_string(font, p + Vector2(rad, -rad), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.2))
		var trait_id: String = h["trait"]
		if trait_id != "":
			var tn: String = D.TRAITS[trait_id]["name"]
			draw_string(font, p + Vector2(rad - 2, rad + 8), tn.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.3))
