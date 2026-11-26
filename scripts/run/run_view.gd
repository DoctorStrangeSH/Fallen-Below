extends Node2D
## Draws the living dungeon: stone floor, veins from the hungry heart, torchlit door,
## card glyphs, monsters, travelers, the Warden and floating combat feedback.
## Uses sprites from res://art/ when they exist (see docs/ART.md), drawn shapes otherwise.

const D = preload("res://scripts/data/game_data.gd")
const Icons = preload("res://scripts/ui/icons.gd")
const Art = preload("res://scripts/ui/art.gd")

const STONE := Color(0.2, 0.17, 0.22)
const STONE_LIGHT := Color(0.29, 0.25, 0.31)
const BONE := Color(0.88, 0.84, 0.74)
const VEIN := Color(0.55, 0.08, 0.16)
const MAX_FX := 80

var run  # run.gd
var veins: Array = []          # Array of PackedVector2Array, built once per map
var floaters: Array = []       # {pos, vel, text, color, t, life, size}
var bursts: Array = []         # {pos, color, t, life, radius}


func _process(delta: float) -> void:
	for f in floaters:
		f["t"] += delta
		f["pos"] += f["vel"] * delta
	floaters = floaters.filter(func(f): return f["t"] < f["life"])
	for b in bursts:
		b["t"] += delta
	bursts = bursts.filter(func(b): return b["t"] < b["life"])
	queue_redraw()


# ============================================================ geometry

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


func warden_world_pos(s) -> Vector2:
	var w: Dictionary = s.warden
	var a := cell_center(s.cell_of(w["cur"]))
	var b := cell_center(s.cell_of(run.warden.next_tile()))
	var p: float = w["prog"]
	return a.lerp(b, p)


## Deterministic per-cell noise in 0..1.
static func _hash(x: int, y: int, salt: int = 0) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 1000) / 1000.0


# ============================================================ feedback

func add_fx(kind: String, target, amount: float) -> void:
	var pos := _fx_pos(target)
	if pos == Vector2.INF:
		return
	match kind:
		"hit_hero":
			_float(pos, "%d" % int(round(amount)), Color(1, 0.85, 0.5), 13)
		"hit_unit":
			_float(pos, "%d" % int(round(amount)), Color(1, 0.4, 0.35), 11)
		"hit_warden":
			_float(pos + Vector2(0, -18), "-%d" % int(round(amount)), Color(1, 0.3, 0.3), 15)
		"evade":
			_float(pos + Vector2(0, -18), Loc.t("miss"), Color(0.7, 0.9, 1.0), 12)
		"devour":
			_float(pos + Vector2(0, -24), "+%d" % int(round(amount)), Color(0.4, 1.0, 0.5), 15)
			_burst(pos, Color(0.7, 0.1, 0.2), 30.0)
		"death":
			_burst(pos, Color(0.9, 0.85, 0.75), 22.0)
		"loot":
			_float(pos, "✦", Color(1, 0.8, 0.3), 20)
		"place":
			_burst(pos, Color(0.6, 0.45, 0.8), 26.0)
		"level":
			_burst(pos, Color(0.75, 0.55, 1.0), 44.0)
		"ability":
			_burst(pos, Color(0.5, 0.85, 1.0), 70.0)
		"escape":
			_float(pos, Loc.t("escaped!"), Color(1, 0.5, 0.3), 13)
		"blast":
			_burst(pos, Color(1.0, 0.55, 0.15), 48.0)
			_burst(pos, Color(1.0, 0.85, 0.4), 26.0)
		"disarm":
			_float(pos, Loc.t("disarmed"), Color(1, 0.7, 0.3), 12)
		"ignite":
			_burst(pos, Color(1.0, 0.5, 0.1), 34.0)
		"quench":
			_burst(pos, Color(0.85, 0.15, 0.25), 30.0)
			_float(pos + Vector2(0, -14), "-%d" % D.QUENCH_BLOOD, Color(0.95, 0.25, 0.3), 13)
		"ash":
			_burst(pos, Color(0.5, 0.48, 0.45), 30.0)
		"purify":
			_float(pos, "%d" % int(round(amount)), Color(0.85, 0.85, 1.0), 10)


func _fx_pos(target) -> Vector2:
	var s = run.state
	if target is Dictionary:
		var d: Dictionary = target
		if d.has("nxt"):
			return hero_world_pos(d)
		if d.has("slots"):
			return warden_world_pos(s)
	elif target is Vector2i:
		return cell_center(target)
	elif target is int:
		var t: int = target
		if t >= 0 and t < s.tiles.size():
			return cell_center(s.cell_of(t)) + Vector2(randf_range(-10, 10), 0)
	return Vector2.INF


func _float(pos: Vector2, text: String, color: Color, size: int) -> void:
	if floaters.size() >= MAX_FX:
		floaters.pop_front()
	floaters.append({"pos": pos + Vector2(randf_range(-6, 6), -8), "vel": Vector2(randf_range(-8, 8), -32),
		"text": text, "color": color, "t": 0.0, "life": 0.9, "size": size})


func _burst(pos: Vector2, color: Color, radius: float) -> void:
	bursts.append({"pos": pos, "color": color, "t": 0.0, "life": 0.45, "radius": radius})


# ============================================================ drawing

func _draw() -> void:
	if run == null or run.state == null:
		return
	var s = run.state
	var font := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() / 1000.0
	draw_rect(get_viewport_rect(), Color(0.04, 0.03, 0.05))
	_draw_floor(s)
	_draw_veins(s, t)
	_draw_path(s, t)
	_draw_scenery(s, t)
	_draw_heart(s, t)
	_draw_preview(s)
	_draw_units(s, t)
	_draw_heroes(s, font, t)
	_draw_warden(s, font, t)
	_draw_charges(s, font, t)
	_draw_fires(s, font, t)
	if s.act == 3:
		_draw_ashfall(t)
	_draw_effects(font)
	_draw_vignette()
	if s.paused and not s.game_over:
		var vr := get_viewport_rect()
		draw_string(font, Vector2(D.MAP_OFFSET.x, vr.size.y * 0.42), Loc.t("PAUSED"), HORIZONTAL_ALIGNMENT_CENTER, D.GRID_W * D.CELL, 40, Color(1, 1, 1, 0.8))


func _draw_floor(s) -> void:
	for x in D.GRID_W:
		for y in D.GRID_H:
			var c := Vector2i(x, y)
			var r := cell_rect(c)
			if Art.draw(self, "tile_floor", r.get_center(), D.CELL):
				continue
			var n := _hash(x, y)
			var base := Color(0.07, 0.06, 0.08).lerp(Color(0.1, 0.085, 0.11), n)
			if s.act == 2:
				base = Color(0.05, 0.07, 0.09).lerp(Color(0.07, 0.1, 0.12), n)
			elif s.act == 3:
				base = Color(0.07, 0.06, 0.06).lerp(Color(0.11, 0.09, 0.08), n)
			draw_rect(r, base)
			if s.act == 2 and _hash(x, y, 9) > 0.78 and not s.path_lookup.has(c):
				# black water pooling in the mines
				var ripple := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 600.0 + n * 6.0)
				draw_rect(r.grow(-2), Color(0.05, 0.15, 0.22, 0.85))
				draw_line(r.position + Vector2(8, 18 + ripple * 4), r.position + Vector2(30, 18 + ripple * 4), Color(0.3, 0.55, 0.7, 0.4), 1.0)
				continue
			# a few cracks and pebbles
			if n > 0.7:
				var p := r.position + Vector2(8 + n * 20, 10 + _hash(y, x) * 22)
				draw_line(p, p + Vector2(10, 4), Color(0.03, 0.02, 0.04), 1.0)
			if _hash(x, y, 3) > 0.85:
				draw_circle(r.position + Vector2(_hash(x, y, 4) * 40 + 4, _hash(x, y, 5) * 40 + 4), 1.5, Color(0.16, 0.14, 0.18))


## Veins run from the heart to the path and pulse with its beat.
func _draw_veins(s, t: float) -> void:
	if veins.is_empty():
		_build_veins(s)
	var beat := 0.5 + 0.5 * sin(t * (2.0 + 0.4 * s.heroes.size()))
	for v in veins:
		var line: PackedVector2Array = v
		draw_polyline(line, VEIN.darkened(0.5), 5.0)
		draw_polyline(line, VEIN.lerp(Color(0.9, 0.15, 0.25), beat * 0.6), 2.0)


func _build_veins(s) -> void:
	var heart := cell_center(s.heart_cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = s.heart_cell.x * 977 + s.heart_cell.y
	var targets: Array = []
	for i in range(0, s.loop_size, maxi(1, s.loop_size / 6)):
		targets.append(cell_center(s.cell_of(i)))
	for tg in targets:
		var target: Vector2 = tg
		var pts := PackedVector2Array()
		var steps := 14
		var bend := Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		for k in steps + 1:
			var f := float(k) / steps
			var p := heart.lerp(target, f) + bend * sin(f * PI) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			pts.append(p)
		veins.append(pts)


func _draw_path(s, t: float) -> void:
	for i in s.tiles.size():
		var cell: Vector2i = s.cell_of(i)
		var r := cell_rect(cell).grow(-1)
		var center := r.get_center()
		var side: bool = i >= s.loop_size
		var base_id := "tile_gate" if i == 0 else ("tile_side" if side else "tile_path")
		if not Art.draw(self, base_id, center, D.CELL):
			# worn flagstones: a slab with a darker rim and a crack
			var n := _hash(cell.x, cell.y, 7)
			var slab := STONE.lerp(STONE_LIGHT, n * 0.6)
			if s.act == 2:
				slab = Color(0.17, 0.2, 0.24).lerp(Color(0.24, 0.28, 0.32), n * 0.6)
			elif s.act == 3:
				slab = Color(0.24, 0.22, 0.21).lerp(Color(0.32, 0.29, 0.27), n * 0.6)
			if side:
				slab = slab.darkened(0.25)
			draw_rect(r, slab.darkened(0.35))
			draw_rect(r.grow(-3), slab)
			draw_line(r.position + Vector2(3, r.size.y * 0.5), r.position + Vector2(r.size.x - 3, r.size.y * 0.5 + (n - 0.5) * 6), slab.darkened(0.25), 1.0)
		var card: String = s.card_at(i)
		if i == 0:
			_draw_door(center, t)
		elif card != "":
			if not Art.draw(self, "card_" + card, center, D.CELL):
				_glyph(card, center, t)
	# fork markers
	for f in s.forks:
		var c := cell_center(s.cell_of(f))
		draw_circle(c + Vector2(0, 16), 3.5, Color(1, 0.85, 0.3, 0.8))


func _draw_door(center: Vector2, t: float) -> void:
	if Art.tex("tile_gate") != null:
		return
	var flick := 0.75 + 0.25 * sin(t * 13.0) * sin(t * 7.3)
	draw_circle(center, 30.0, Color(1.0, 0.6, 0.2, 0.08 * flick))
	draw_circle(center, 20.0, Color(1.0, 0.65, 0.25, 0.1 * flick))
	var door := Rect2(center + Vector2(-12, -14), Vector2(24, 28))
	draw_circle(center + Vector2(0, -14), 12.0, Color(0.28, 0.16, 0.08))
	draw_rect(door, Color(0.28, 0.16, 0.08))
	draw_rect(Rect2(center + Vector2(-3, -6), Vector2(6, 14)), Color(1.0, 0.75, 0.35, 0.7 * flick))


## Simple drawn icons for cards (used until sprites exist).
func _glyph(card: String, c: Vector2, t: float) -> void:
	Icons.card_glyph(self, card, c, t)


func _draw_scenery(s, t: float) -> void:
	for cc in s.scenery:
		var cell: Vector2i = cc
		var center := cell_rect(cell).get_center()
		var id: String = s.scenery[cc]
		if Art.draw(self, "card_" + id, center, D.CELL):
			continue
		var col: Color = D.CARDS[id]["color"]
		match id:
			"altar", "spire":
				var h := 22.0 if id == "spire" else 12.0
				draw_rect(Rect2(center + Vector2(-10, 4), Vector2(20, 8)), Color(0.25, 0.2, 0.28))
				draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 4), center + Vector2(6, 4), center + Vector2(0, 4 - h)]), col.darkened(0.3))
				var flick := 0.7 + 0.3 * sin(t * 9.0 + center.x)
				draw_circle(center + Vector2(0, 2 - h), 4.0 * flick, col.lightened(0.3))
				draw_circle(center, 22.0, Color(col, 0.08 * flick))
			"graveyard":
				for k in 3:
					var p := center + Vector2((k - 1) * 12, 4 - (k % 2) * 4)
					draw_rect(Rect2(p + Vector2(-4, -8), Vector2(8, 12)), Color(0.45, 0.47, 0.45))
					draw_circle(p + Vector2(0, -8), 4, Color(0.45, 0.47, 0.45))
				draw_rect(Rect2(center + Vector2(-18, 8), Vector2(36, 4)), Color(0.4, 0.5, 0.45, 0.25))
			_:
				draw_rect(cell_rect(cell).grow(-8), col)


## The dungeon's hungry heart. Beats faster the more travelers are inside.
func _draw_heart(s, t: float) -> void:
	var center := cell_center(s.heart_cell)
	if Art.draw(self, "heart", center, 44.0 * (1.0 + 0.09 * Icons.heartbeat(t, 60.0))):
		return
	# it beats faster the more travelers are inside, and glows hotter as the Order closes in
	var bpm: float = 52.0 + 10.0 * s.heroes.size()
	Icons.heart(self, center, 1.2, t, bpm, clampf(s.threat / D.BOSS_THREAT, 0.0, 1.0))


func _draw_preview(s) -> void:
	if s.is_blocked():
		return
	var mc := mouse_cell()
	var id: String = run.cards.selected_id()
	if id == "":
		return
	var ok: bool = run.cards.can_place(id, mc)
	var r := cell_rect(mc)
	draw_rect(r, Color(0.3, 1, 0.4, 0.2) if ok else Color(1, 0.2, 0.2, 0.18))
	draw_rect(r, Color(0.3, 1, 0.4) if ok else Color(1, 0.3, 0.3), false, 2.0)


func _draw_units(s, t: float) -> void:
	for i in s.tiles.size():
		var units: Array = s.tiles[i]["units"]
		var k := 0
		var base := D.MAP_OFFSET + Vector2(s.cell_of(i)) * D.CELL
		for u in units:
			if u["hp"] <= 0.0:
				continue
			var p := base + Vector2(10 + (k % 3) * 14, 28 + (k / 3) * 11)
			var kind: String = str(u.get("kind", ""))
			var sprite_id: String = ("undead_" + str(u.get("cls", ""))) if u["undead"] else ("monster_" + kind)
			if not Art.draw(self, sprite_id, p, 18.0):
				_monster_shape(u, kind, p, t)
			var frac: float = clampf(u["hp"] / u["max_hp"], 0.0, 1.0)
			draw_rect(Rect2(p + Vector2(-6, 8), Vector2(12, 2)), Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(p + Vector2(-6, 8), Vector2(12 * frac, 2)), Color(0.4, 0.9, 1.0))
			k += 1


func _monster_shape(u: Dictionary, kind: String, p: Vector2, t: float) -> void:
	if u["undead"]:
		var col: Color = u["color"]
		draw_circle(p, 7.0, Color(0.3, 0.8, 1.0, 0.25))
		draw_circle(p, 5.5, col.lightened(0.1))
		draw_circle(p + Vector2(-2, -1), 1.2, Color(0.5, 1, 1))
		draw_circle(p + Vector2(2, -1), 1.2, Color(0.5, 1, 1))
		return
	match kind:
		"skeleton":
			draw_circle(p + Vector2(0, -2), 4.5, BONE)
			draw_circle(p + Vector2(-1.6, -2.5), 1.1, Color(0.1, 0.1, 0.1))
			draw_circle(p + Vector2(1.6, -2.5), 1.1, Color(0.1, 0.1, 0.1))
			draw_line(p + Vector2(0, 2), p + Vector2(0, 7), BONE, 1.5)
		"spider":
			for a in [-0.6, -0.2, 0.2, 0.6]:
				draw_line(p, p + Vector2(-6, a * 8), Color(0.5, 0.45, 0.45), 1.0)
				draw_line(p, p + Vector2(6, a * 8), Color(0.5, 0.45, 0.45), 1.0)
			draw_circle(p, 4.0, Color(0.25, 0.2, 0.2))
			draw_circle(p + Vector2(-1.2, -1), 0.8, Color(1, 0.2, 0.2))
			draw_circle(p + Vector2(1.2, -1), 0.8, Color(1, 0.2, 0.2))
		"queen":
			draw_circle(p + Vector2(0, -5), 6.5 + sin(t * 3.0), Color(0.3, 1.0, 0.4, 0.2))
			draw_circle(p + Vector2(0, 2), 7.0, Color(0.15, 0.45, 0.15))
			draw_circle(p + Vector2(0, -5), 4.5, Color(0.2, 0.6, 0.2))
		"golem":
			draw_rect(Rect2(p + Vector2(-7, -8), Vector2(14, 14)), BONE.darkened(0.2))
			draw_circle(p + Vector2(0, -1), 3.0, Color(0.4, 1.0, 0.7, 0.7 + 0.3 * sin(t * 4.0)))
		"ashen":
			draw_circle(p, 5.5, Color(0.5, 0.48, 0.46))
			draw_circle(p + Vector2(-1.8, -1), 1.1, Color(1, 0.55, 0.2))
			draw_circle(p + Vector2(1.8, -1), 1.1, Color(1, 0.55, 0.2))
		"drowned":
			draw_circle(p, 5.5, Color(0.3, 0.5, 0.55))
			draw_circle(p + Vector2(-1.8, -1), 1.1, Color(0.6, 1, 0.9))
			draw_circle(p + Vector2(1.8, -1), 1.1, Color(0.6, 1, 0.9))
			draw_line(p + Vector2(-4, 4), p + Vector2(4, 4), Color(0.2, 0.45, 0.6), 1.5)
		"mimic":
			draw_rect(Rect2(p + Vector2(-8, -5), Vector2(16, 10)), Color(0.75, 0.45, 0.12))
			for k in 3:
				draw_colored_polygon(PackedVector2Array([p + Vector2(-6 + k * 5, -1), p + Vector2(-3 + k * 5, -1), p + Vector2(-4.5 + k * 5, 3)]), BONE)
		_:
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), u["color"])


func _draw_heroes(s, font: Font, t: float) -> void:
	var stack := {}
	for h in s.heroes:
		if h["gone"] or h["delay"] > 0.0:
			continue
		var tile: int = s.tile_of(h)
		var n: int = stack.get(tile, 0)
		stack[tile] = n + 1
		var p := hero_world_pos(h) + Vector2((n % 2) * 14 - 7, (n / 2) * 14 - 10)
		var is_boss: bool = h["boss"]
		var rad := 16.0 if is_boss else 9.0
		var bob := sin(t * 8.0 + float(h["id"])) * 1.2
		draw_circle(p + Vector2(0, rad * 0.9), rad * 0.8, Color(0, 0, 0, 0.35))  # shadow
		if is_boss:
			draw_circle(p, rad + 8 + 2 * sin(t * 3.0), Color(1, 0.95, 0.7, 0.15))
		var sprite_id := "boss_aurelia" if is_boss else "traveler_" + str(h["cls"])
		if not Art.draw(self, sprite_id, p + Vector2(0, bob), rad * 2.6):
			var col: Color = h["color"]
			draw_circle(p + Vector2(0, bob), rad + 1.5, col.darkened(0.6))
			draw_circle(p + Vector2(0, bob), rad, col)
			var cls_name: String = Loc.t(D.HERO_CLASSES[h["cls"]]["name"])
			draw_string(font, p + Vector2(-rad, 4 + bob), cls_name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 11, Color(0.15, 0.08, 0.05))
		var frac: float = clampf(h["hp"] / h["max_hp"], 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2, 3)), Color(0.2, 0, 0))
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2 * frac, 3)), Color(1, 0.3, 0.3))
		if int(h.get("poison", 0)) > 0:
			draw_circle(p + Vector2(rad, -rad + 2), 2.5, Color(0.4, 1.0, 0.3))
		if h["stun"] > 0.0:
			draw_string(font, p + Vector2(-rad, -rad - 8), "zz", HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 11, Color(1, 0.85, 0.3))
		var laps: int = h["laps"]
		for k in laps:
			draw_circle(p + Vector2(-rad + 3 + k * 5, rad + 4), 1.8, Color(1, 0.4, 0.3))
		if h["revenge"]:
			draw_string(font, p + Vector2(rad, -rad), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.2))
		var trait_id: String = h["trait"]
		if trait_id != "":
			var tn: String = Loc.t(D.TRAITS[trait_id]["name"])
			draw_string(font, p + Vector2(rad - 2, rad + 8), tn.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.85, 0.3))


func _draw_warden(s, font: Font, t: float) -> void:
	if s.warden.is_empty() or s.warden["hp"] <= 0.0:
		return
	var w: Dictionary = s.warden
	var p := warden_world_pos(s) + Vector2(0, -2)
	var col: Color = w["color"]
	var glow := 0.5 + 0.5 * sin(t * 3.0)
	draw_circle(p + Vector2(0, 14), 14.0, Color(0, 0, 0, 0.4))
	draw_circle(p, 22.0, Color(col, 0.12 + 0.1 * glow))
	if not Art.draw(self, "warden_" + str(w["id"]), p, 40.0):
		var body := PackedVector2Array([p + Vector2(0, -16), p + Vector2(14, -2), p + Vector2(9, 14), p + Vector2(-9, 14), p + Vector2(-14, -2)])
		draw_colored_polygon(body, Color(0.1, 0.14, 0.2))
		draw_polyline(body + PackedVector2Array([body[0]]), col, 2.0)
		for k in 3:  # ribs
			draw_line(p + Vector2(-7, -2 + k * 5), p + Vector2(7, -2 + k * 5), col.darkened(0.3), 1.0)
		draw_circle(p + Vector2(-4, -7), 2.2, col.lightened(0.4))
		draw_circle(p + Vector2(4, -7), 2.2, col.lightened(0.4))
	var frac: float = clampf(w["hp"] / w["max_hp"], 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(-18, -26), Vector2(36, 4)), Color(0.1, 0.1, 0.15))
	draw_rect(Rect2(p + Vector2(-18, -26), Vector2(36 * frac, 4)), Color(0.4, 0.85, 1.0))
	draw_string(font, p + Vector2(-30, 28), Loc.t("WARDEN"), HORIZONTAL_ALIGNMENT_CENTER, 60, 9, col)


## Act III: flames on burning halls (with the time left), ash where halls burned down.
func _draw_fires(s, font: Font, t: float) -> void:
	for key in s.ash:
		var tile: int = key
		if s.card_at(tile) == "" and not s.fires.has(tile):
			var r := cell_rect(s.cell_of(tile)).grow(-6)
			draw_rect(r, Color(0.12, 0.11, 0.1, 0.8))
			for k in 5:
				var p := r.position + Vector2(_hash(tile, k) * r.size.x, _hash(k, tile) * r.size.y)
				draw_circle(p, 1.5, Color(0.9, 0.4, 0.15, 0.25 + 0.2 * sin(t * 2.0 + k)))
	for key in s.fires:
		var tile: int = key
		var f: Dictionary = s.fires[tile]
		var c := cell_center(s.cell_of(tile))
		draw_rect(cell_rect(s.cell_of(tile)).grow(-2), Color(1.0, 0.35, 0.05, 0.12 + 0.06 * sin(t * 9.0 + tile)))
		for k in 5:
			var x := (k - 2) * 8.0
			var h := 14.0 + 8.0 * sin(t * (7.0 + k) + tile * 1.7 + k)
			var base := c + Vector2(x, 14)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(0, -h), base + Vector2(5, 0)]), Color(1.0, 0.45, 0.1, 0.8))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-2.5, 0), base + Vector2(0, -h * 0.55), base + Vector2(2.5, 0)]), Color(1.0, 0.85, 0.4, 0.9))
		var left: float = f["left"]
		var frac := clampf(left / D.FIRE_BURN, 0.0, 1.0)
		draw_rect(Rect2(c + Vector2(-20, 19), Vector2(40, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(c + Vector2(-20, 19), Vector2(40 * frac, 3)), Color(1, 0.6, 0.2))


## Act III: ash drifting down over the whole map.
func _draw_ashfall(t: float) -> void:
	var area := Vector2(D.GRID_W, D.GRID_H) * D.CELL
	for i in 60:
		var sx := _hash(i, 3) * area.x
		var speed := 12.0 + _hash(i, 5) * 18.0
		var y := fmod(_hash(i, 7) * area.y + t * speed, area.y)
		var x := sx + sin(t * 0.8 + i) * 10.0
		var glow := _hash(i, 11) > 0.85
		draw_circle(D.MAP_OFFSET + Vector2(x, y), 1.6 if glow else 1.2, Color(1.0, 0.5, 0.2, 0.6) if glow else Color(0.7, 0.68, 0.65, 0.35))


## Brann's planted charges: a pulsing ring and a countdown, so the player can react.
func _draw_charges(s, font: Font, t: float) -> void:
	for c in s.charges:
		var tile: int = c["tile"]
		var p := cell_center(s.cell_of(tile))
		var fuse: float = c["fuse"]
		var blink := 0.5 + 0.5 * sin(t * (10.0 + (D.BRANN_FUSE - fuse) * 8.0))
		draw_arc(p, 22.0, 0, TAU, 24, Color(1, 0.3, 0.1, 0.5 + 0.5 * blink), 3.0)
		draw_rect(Rect2(p + Vector2(-5, -8), Vector2(10, 12)), Color(0.5, 0.15, 0.08))
		draw_string_outline(font, p + Vector2(-20, 24), "%.1f" % maxf(fuse, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 40, 13, 3, Color(0, 0, 0))
		draw_string(font, p + Vector2(-20, 24), "%.1f" % maxf(fuse, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 40, 13, Color(1, 0.6, 0.3))


func _draw_effects(font: Font) -> void:
	for b in bursts:
		var k: float = b["t"] / b["life"]
		var col: Color = b["color"]
		draw_arc(b["pos"], float(b["radius"]) * (0.4 + k), 0, TAU, 24, Color(col, 1.0 - k), 2.5 * (1.0 - k) + 0.5)
	for f in floaters:
		var k: float = f["t"] / f["life"]
		var col: Color = f["color"]
		var text: String = f["text"]
		draw_string_outline(font, f["pos"], text, HORIZONTAL_ALIGNMENT_LEFT, -1, f["size"], 3, Color(0, 0, 0, 0.8 * (1.0 - k)))
		draw_string(font, f["pos"], text, HORIZONTAL_ALIGNMENT_LEFT, -1, f["size"], Color(col, 1.0 - k * k))


## Darkens the edges of the map so the dungeon feels enclosed.
func _draw_vignette() -> void:
	var r := Rect2(D.MAP_OFFSET, Vector2(D.GRID_W, D.GRID_H) * D.CELL)
	for k in 6:
		var a := 0.09 * (6 - k) / 6.0
		var w := 6.0 + k * 6.0
		draw_rect(Rect2(r.position, Vector2(r.size.x, w)), Color(0, 0, 0, a))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), Color(0, 0, 0, a))
		draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color(0, 0, 0, a))
		draw_rect(Rect2(r.position + Vector2(r.size.x - w, 0), Vector2(w, r.size.y)), Color(0, 0, 0, a))
