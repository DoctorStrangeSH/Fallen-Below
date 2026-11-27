extends Node2D
## Draws the sprout grid, channels and organs from SproutState only (code-drawn placeholders, GDD 16).
## cell_center()/cell_at() are the single mapping between screen and grid.

const Reg = preload("res://scripts/ag/core/registry.gd")
const Grid = preload("res://scripts/ag/run/grid_state.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const CS := 20.0
const ORIGIN := Vector2(80, 40)

const ROCK_COL := Color(0.045, 0.035, 0.05)
const FLESH_COL := Color(0.22, 0.08, 0.09)
const BONE_COL := Color(0.62, 0.56, 0.46)
const WATER_COL := Color(0.06, 0.1, 0.16)
const RUIN_COL := Color(0.42, 0.44, 0.46)
const BLOOD := Color(0.85, 0.12, 0.16)
const MEMORY := Color(0.55, 0.3, 0.85)
const WHISPER := Color(0.7, 0.85, 1.0)
const CATEGORY_COL := {
	"central": Color(0.85, 0.15, 0.2), "digestive": Color(0.75, 0.45, 0.2), "production": Color(0.8, 0.35, 0.55),
	"transport": Color(0.55, 0.4, 0.95), "sensory": Color(0.65, 0.85, 1.0), "support": Color(0.4, 0.8, 0.5),
}

var sp   # sprout root (scripts/ag/run/sprout.gd)
var t := 0.0
var ghost_def := ""          # organ id being placed, or "channel"
var ghost_cell := Vector2i(-1, -1)
var ghost_ok := false
var ghost_route: Array = []  # preview of an auto-routed channel
var hover_uid := -1


func cell_center(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CS


func cell_at(p: Vector2) -> Vector2i:
	var q := (p - ORIGIN) / CS
	return Vector2i(floori(q.x), floori(q.y))


func organ_rect(uid: int) -> Rect2:
	var cells: Array = sp.organs.cells_of(uid)
	var r := Rect2(ORIGIN + Vector2(cells[0]) * CS, Vector2(CS, CS))
	for c in cells:
		r = r.merge(Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS)))
	return r


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


static func _shade(c: Vector2i) -> float:
	return float(abs(hash(c)) % 1000) / 1000.0


func _draw() -> void:
	if sp == null or sp.state == null or sp.state.grid == null:
		return
	var g = sp.state.grid
	draw_rect(Rect2(ORIGIN - Vector2(6, 6), Vector2(g.w, g.h) * CS + Vector2(12, 12)), Color(0.02, 0.015, 0.025))
	for y in g.h:
		for x in g.w:
			_draw_cell(g, Vector2i(x, y))
	for e in g.entrances:
		_draw_entrance(g, e)
	_draw_channels(g)
	for uid in sp.state.organs:
		_draw_organ(int(uid))
	_draw_ghost(g)


func _draw_cell(g, c: Vector2i) -> void:
	var r := Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS))
	var n := _shade(c)
	if not g.is_floor(c):
		# rock: draw a lit rim where it meets the floor, like a wall top
		draw_rect(r, ROCK_COL.lightened(n * 0.05))
		for d in Grid.DIRS:
			if g.is_floor(c + d):
				var edge := Rect2(r.position, Vector2(CS, 3)) if d == Vector2i(0, 1) else Rect2()
				if d == Vector2i(0, 1):
					edge = Rect2(r.position + Vector2(0, CS - 4), Vector2(CS, 4))
				elif d == Vector2i(0, -1):
					edge = Rect2(r.position, Vector2(CS, 2))
				elif d == Vector2i(1, 0):
					edge = Rect2(r.position + Vector2(CS - 2, 0), Vector2(2, CS))
				else:
					edge = Rect2(r.position, Vector2(2, CS))
				draw_rect(edge, Color(0.3, 0.16, 0.18))
		return
	var col := FLESH_COL
	match g.tissue_at(c):
		Grid.T_BONE: col = BONE_COL
		Grid.T_WATER: col = WATER_COL
		Grid.T_RUIN: col = RUIN_COL
	col = col.darkened(0.12 * n) if g.room[g.idx(c)] >= 0 else col.darkened(0.25 + 0.1 * n)
	draw_rect(r, col)
	match g.tissue_at(c):
		Grid.T_BONE:
			# a small skull or bone
			var p := r.get_center()
			if n > 0.5:
				draw_circle(p + Vector2(0, -1), 4.0, Color(0.85, 0.8, 0.68))
				draw_circle(p + Vector2(-1.6, -1.5), 1.1, Color(0.1, 0.08, 0.08))
				draw_circle(p + Vector2(1.6, -1.5), 1.1, Color(0.1, 0.08, 0.08))
			else:
				draw_line(p + Vector2(-5, 3), p + Vector2(5, -3), Color(0.85, 0.8, 0.68), 2.0)
		Grid.T_WATER:
			var wv := sin(t * 1.5 + n * 6.0) * 0.5 + 0.5
			draw_line(r.position + Vector2(3, 8 + wv * 3), r.position + Vector2(CS - 3, 8 + wv * 3), Color(0.25, 0.4, 0.6, 0.5), 1.0)
		Grid.T_RUIN:
			draw_rect(r.grow(-1.5), Color(0.55, 0.57, 0.6), false, 1.0)
		_:
			if n > 0.82:
				draw_circle(r.get_center() + Vector2(n * 6 - 3, 2), 1.5, Color(0.35, 0.12, 0.14))
	var sc: float = g.scar[g.idx(c)]
	if sc > 0.0:
		draw_circle(r.get_center(), CS * 0.42, Color(0.05, 0.02, 0.02, 0.7 * sc))


func _draw_entrance(g, e: Vector2i) -> void:
	var p := cell_center(e)
	var glow := 0.6 + 0.4 * sin(t * 2.0)
	draw_circle(p, CS * 0.9, Color(1.0, 0.8, 0.45, 0.12 * glow))
	draw_arc(p, CS * 0.45, PI, TAU, 12, Color(1.0, 0.8, 0.45, 0.9), 2.0)
	draw_line(p + Vector2(-CS * 0.45, 0), p + Vector2(-CS * 0.45, CS * 0.4), Color(1.0, 0.8, 0.45, 0.9), 2.0)
	draw_line(p + Vector2(CS * 0.45, 0), p + Vector2(CS * 0.45, CS * 0.4), Color(1.0, 0.8, 0.45, 0.9), 2.0)


func _draw_channels(g) -> void:
	var net: Dictionary = sp.state.network
	for i in g.channel.size():
		if g.channel[i] != 1:
			continue
		var c := Vector2i(i % g.w, i / g.w)
		var live := net.has(c)
		var pulse := 0.5 + 0.5 * sin(t * 4.0 - (c.x + c.y) * 0.6)
		var col := BLOOD.lerp(Color(1, 0.5, 0.5), pulse * 0.4) if live else Color(0.35, 0.3, 0.32)
		var p := cell_center(c)
		for d in Grid.DIRS:
			var n: Vector2i = c + d
			if g.has_channel(n) or g.organ_at(n) >= 0:
				draw_line(p, p + Vector2(d) * CS * 0.5, col, 4.0 if live else 3.0)
		draw_circle(p, 3.2, col)


func _state_tint(st: String) -> Color:
	match st:
		"disabled": return Color(0.45, 0.42, 0.45, 0.75)
		"asleep", "dormant": return Color(0.55, 0.55, 0.75, 0.8)
		"recovering": return Color(1, 1, 1, 0.55 + 0.35 * sin(t * 8.0))
		"critical": return Color(1, 0.55 + 0.45 * sin(t * 10.0), 0.55 + 0.45 * sin(t * 10.0))
		"damaged": return Color(1, 0.85, 0.85)
	return Color(1, 1, 1)


func _draw_organ(uid: int) -> void:
	var o: Dictionary = sp.state.organs[uid]
	var d: Dictionary = Reg.get_def(str(o["def"]))
	var r := organ_rect(uid)
	var st := str(o["state"])
	var tint := _state_tint(st)
	var col: Color = CATEGORY_COL.get(str(d.get("category", "")), Color.WHITE)
	if st == "disabled":
		col = col.lerp(Color(0.4, 0.4, 0.42), 0.7)
	elif st == "asleep" or st == "dormant":
		col = col.lerp(Color(0.25, 0.28, 0.45), 0.55)
	col *= tint
	var c := r.get_center()
	if str(o["def"]) == "organ.heart":
		draw_circle(c, r.size.x * 0.62, Color(0.6, 0.05, 0.1, 0.15 + 0.1 * Icons.heartbeat(t, 60.0)))
		Icons.heart(self, c, r.size.x / 44.0, t, 60.0, 0.3)
	else:
		_organ_body(str(o["def"]), r, c, col)
	if uid == hover_uid:
		draw_rect(r.grow(2), Color(1, 0.8, 0.45, 0.9), false, 1.5)
	var ratio := float(o["hp"]) / maxf(1.0, float(o["max_hp"]))
	if ratio < 1.0:
		var bar := Rect2(r.position + Vector2(2, -5), Vector2(r.size.x - 4, 3))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 3)), BLOOD if ratio > 0.25 else Color(1, 0.3, 0.2))
	if st == "asleep" or st == "dormant":
		# sleeping: a drifting "z"
		var zp := r.position + Vector2(r.size.x - 4, 2 - fmod(t * 6.0, 6.0))
		draw_string(ThemeDB.fallback_font, zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.85, 1.0, 0.9))
	var pr := int(o.get("priority", 1))
	if pr != 1:
		draw_circle(r.position + Vector2(3, 3), 2.5, Color(1.0, 0.8, 0.45) if pr == 2 else Color(0.5, 0.5, 0.6))
	if st == "disabled":
		# broken link marker
		draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), Color(0.9, 0.9, 0.9, 0.8), 2.0)
		draw_line(c + Vector2(4, -4), c + Vector2(-4, 4), Color(0.9, 0.9, 0.9, 0.8), 2.0)


func _organ_body(def_id: String, r: Rect2, c: Vector2, col: Color) -> void:
	var dark := col.darkened(0.55)
	var beat := 1.0 + 0.04 * sin(t * 3.0 + c.x)
	match def_id:
		"organ.stomach":
			_blob(c, Vector2(r.size.x * 0.46, r.size.y * 0.42) * beat, col, dark)
			var churn := 3.0 if not sp.state.bodies.is_empty() else 1.0
			draw_arc(c, r.size.y * 0.2, t * churn, t * churn + PI * 1.4, 12, dark, 2.0)
		"organ.incubator":
			_blob(c, Vector2(r.size.x * 0.47, r.size.y * 0.4), dark.lightened(0.1), col.darkened(0.3))
			for k in 3:
				var e := c + Vector2((k - 1) * r.size.x * 0.25, sin(t * 2.0 + k) * 1.5)
				draw_circle(e, r.size.y * 0.2 * beat, col)
				draw_circle(e + Vector2(-1.5, -1.5), 1.5, col.lightened(0.5))
		"organ.nerve_node":
			for k in 6:
				var a := TAU * k / 6.0 + t * 0.4
				draw_line(c, c + Vector2.from_angle(a) * r.size.x * 0.48, col, 1.5)
			draw_circle(c, r.size.x * 0.24 * beat, col)
			draw_circle(c, r.size.x * 0.1, Color(1, 1, 1, 0.8))
		"organ.sensor":
			_blob(c, Vector2(r.size.x * 0.46, r.size.y * 0.3), dark, col)
			draw_circle(c, r.size.y * 0.22, col)
			var look := Vector2(sin(t * 0.7), cos(t * 0.9) * 0.5) * 2.0
			draw_circle(c + look, r.size.y * 0.1, Color(0.02, 0.02, 0.05))
		"organ.regen_tissue":
			for k in 3:
				var a := TAU * k / 3.0 - PI / 2.0
				draw_circle(c + Vector2.from_angle(a) * r.size.x * 0.18, r.size.x * 0.24 * beat, col)
			draw_circle(c, r.size.x * 0.12, col.lightened(0.4))
		_:
			_blob(c, r.size * 0.45, col, dark)


func _blob(c: Vector2, rad: Vector2, fill: Color, rim: Color) -> void:
	var pts := PackedVector2Array()
	for k in 18:
		var a := TAU * k / 18.0
		var wob := 1.0 + 0.06 * sin(a * 3.0 + t * 2.0)
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * wob)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, rim, 1.5)


func _draw_ghost(g) -> void:
	if ghost_def == "" or not g.in_bounds(ghost_cell):
		return
	var col := Color(0.4, 1.0, 0.5, 0.45) if ghost_ok else Color(1.0, 0.3, 0.3, 0.45)
	if ghost_def == "channel":
		for c in ghost_route:
			draw_circle(cell_center(c), 4.0, Color(0.4, 1.0, 0.5, 0.45))
		draw_rect(Rect2(ORIGIN + Vector2(ghost_cell) * CS, Vector2(CS, CS)), col, false, 2.0)
		return
	for c in sp.organs.footprint_cells(ghost_def, ghost_cell):
		draw_rect(Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS)).grow(-1), col)
