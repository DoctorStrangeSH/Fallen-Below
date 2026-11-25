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
	var s = run.state
	var a := cell_center(s.cell_of(h["cur"]))
	var b := cell_center(s.cell_of(h["nxt"]))
	var p: float = h["prog"]
	return a.lerp(b, p)


func _draw() -> void:
	if run == null or run.state == null:
		return
	var s = run.state
	var font := ThemeDB.fallback_font
	draw_rect(get_viewport_rect(), Color(0.06, 0.05, 0.08))
	_draw_floor(s)
	_draw_path(s, font)
	_draw_scenery(s, font)
	_draw_heart(s, font)
	_draw_preview(s)
	_draw_units(s)
	_draw_heroes(s, font)
	_draw_warden(s, font)
	if s.paused and not s.game_over:
		var vr := get_viewport_rect()
		draw_string(font, Vector2(D.MAP_OFFSET.x, vr.size.y * 0.42), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, D.GRID_W * D.CELL, 40, Color(1, 1, 1, 0.8))


func _draw_floor(s) -> void:
	for x in D.GRID_W:
		for y in D.GRID_H:
			var c := Vector2i(x, y)
			var r := cell_rect(c)
			# cells where scenery may go are a bit lighter
			var near_path := false
			for nb in s.neighbors(c):
				if s.path_lookup.has(nb):
					near_path = true
					break
			draw_rect(r, Color(0.11, 0.1, 0.13) if near_path else Color(0.08, 0.07, 0.1))
			draw_rect(r, Color(0.13, 0.12, 0.16), false, 1.0)


func _draw_path(s, font: Font) -> void:
	for i in s.tiles.size():
		var r := cell_rect(s.cell_of(i)).grow(-2)
		var card: String = s.tiles[i]["card"]
		var col := Color(0.24, 0.21, 0.27)
		if i >= s.loop_size:
			col = Color(0.2, 0.18, 0.22)  # side passage
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
	# fork markers
	for f in s.forks:
		var c := cell_center(s.cell_of(f))
		draw_circle(c + Vector2(0, 14), 4.0, Color(1, 0.85, 0.3, 0.8))


func _draw_scenery(s, font: Font) -> void:
	for c in s.scenery:
		var cell: Vector2i = c
		var r := cell_rect(cell).grow(-6)
		var id: String = s.scenery[c]
		var col: Color = D.CARDS[id]["color"]
		draw_rect(r, col)
		var label: String = D.CARDS[id]["name"]
		draw_string(font, r.position + Vector2(0, 24), label.substr(0, 5).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10)


## The dungeon's hungry heart (decorative). Beats faster the more travelers are inside.
func _draw_heart(s, font: Font) -> void:
	var center := cell_center(s.heart_cell)
	var beat := 300.0 / (1.0 + 0.25 * s.heroes.size())
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / beat)
	draw_circle(center, 20.0 * pulse, Color(0.45, 0.05, 0.12))
	draw_circle(center, 13.0 * pulse, Color(0.8, 0.15, 0.25))
	draw_string(font, center + Vector2(-40, 36), "HUNGER", HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(1, 0.5, 0.5, 0.6))


func warden_world_pos(s) -> Vector2:
	var w: Dictionary = s.warden
	var a := cell_center(s.cell_of(w["cur"]))
	var b := cell_center(s.cell_of(run.warden.next_tile()))
	var p: float = w["prog"]
	return a.lerp(b, p)


func _draw_warden(s, font: Font) -> void:
	if s.warden.is_empty() or s.warden["hp"] <= 0.0:
		return
	var w: Dictionary = s.warden
	var p := warden_world_pos(s) + Vector2(0, -2)
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	draw_circle(p, 19.0, Color(0.3, 0.7, 1.0, 0.25 + 0.2 * glow))
	var body := PackedVector2Array([p + Vector2(0, -15), p + Vector2(13, 0), p + Vector2(0, 15), p + Vector2(-13, 0)])
	draw_colored_polygon(body, Color(0.12, 0.2, 0.3))
	draw_polyline(body + PackedVector2Array([body[0]]), w["color"], 2.0)
	draw_circle(p + Vector2(-4, -2), 2.2, Color(0.6, 1, 1))
	draw_circle(p + Vector2(4, -2), 2.2, Color(0.6, 1, 1))
	var frac: float = clampf(w["hp"] / w["max_hp"], 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-18, -24), Vector2(36, 4)), Color(0.1, 0.1, 0.15))
	draw_rect(Rect2(p + Vector2(-18, -24), Vector2(36 * frac, 4)), Color(0.4, 0.85, 1.0))
	draw_string(font, p + Vector2(-30, 28), "WARDEN", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color(0.6, 0.9, 1.0))


func _draw_preview(s) -> void:
	if s.is_blocked():
		return
	var mc := mouse_cell()
	var id: String = run.cards.selected_id()
	if id == "":
		return
	var ok: bool = run.cards.can_place(id, mc)
	var r := cell_rect(mc)
	draw_rect(r, Color(0.3, 1, 0.4, 0.25) if ok else Color(1, 0.2, 0.2, 0.2))
	draw_rect(r, Color(0.3, 1, 0.4) if ok else Color(1, 0.3, 0.3), false, 2.0)


func _draw_units(s) -> void:
	for i in s.tiles.size():
		var units: Array = s.tiles[i]["units"]
		var k := 0
		for u in units:
			if u["hp"] <= 0.0:
				continue
			var base := D.MAP_OFFSET + Vector2(s.cell_of(i)) * D.CELL
			var p := base + Vector2(6 + (k % 3) * 13, 22 + (k / 3) * 13)
			var sz := 11.0
			if u["name"] in ["Spider Queen", "Bone Golem", "Mimic"]:
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
		if is_boss:
			draw_circle(p, rad + 3, Color(1, 0.2, 0.2))
		var col: Color = h["color"]
		draw_circle(p, rad, col)
		var cls_name: String = D.HERO_CLASSES[h["cls"]]["name"]
		draw_string(font, p + Vector2(-rad, 5), cls_name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 13, Color(0.1, 0.05, 0.05))
		var frac: float = clampf(h["hp"] / h["max_hp"], 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2, 3)), Color(0.2, 0, 0))
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2 * frac, 3)), Color(1, 0.3, 0.3))
		if h["stun"] > 0.0:
			draw_string(font, p + Vector2(-rad, -rad - 8), "zz", HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 11, Color(1, 0.85, 0.3))
		var laps: int = h["laps"]
		for k in laps:
			draw_circle(p + Vector2(-rad + 3 + k * 5, rad + 4), 1.8, Color(1, 0.4, 0.3))
		if h["revenge"]:
			draw_string(font, p + Vector2(rad, -rad), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.2))
		var trait_id: String = h["trait"]
		if trait_id != "":
			var tn: String = D.TRAITS[trait_id]["name"]
			draw_string(font, p + Vector2(rad - 2, rad + 8), tn.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.3))
