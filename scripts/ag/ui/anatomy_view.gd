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
var selected_uid := -1


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
	_draw_units()
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
	if uid == hover_uid or uid == selected_uid:
		draw_rect(r.grow(2), Color(1, 0.8, 0.45, 0.9), false, 1.5)
	if str(o["def"]) == "organ.incubator":
		var bp: float = sp.creatures.breed_progress(uid)
		var queued: int = (sp.state.breeding.get(uid, {}).get("queue", []) as Array).size()
		if queued > 0:
			draw_arc(c, r.size.y * 0.62, 0.0, TAU, 24, Color(0.9, 0.5, 0.75, 0.25), 2.0)
			draw_arc(c, r.size.y * 0.62, -PI / 2.0, -PI / 2.0 + TAU * bp, 20, Color(0.9, 0.5, 0.75), 2.0)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(r.size.x - 6, r.size.y + 2), str(queued), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.85, 0.95))
	var ratio := float(o["hp"]) / maxf(1.0, float(o["max_hp"]))
	if ratio < 1.0:
		var bar := Rect2(r.position + Vector2(2, -5), Vector2(r.size.x - 4, 3))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 3)), BLOOD if ratio > 0.25 else Color(1, 0.3, 0.2))
	if st == "asleep" or st == "dormant":
		# sleeping: a drifting "z"
		var zp := r.position + Vector2(r.size.x - 4, 2 - fmod(t * 6.0, 6.0))
		draw_string(ThemeDB.fallback_font, zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.85, 1.0, 0.9))
	var om := 0
	for m in o.get("mutations", []):
		draw_circle(r.position + Vector2(r.size.x - 3 - om * 4, r.size.y - 3), 1.6, Color(0.75, 0.5, 1.0))
		om += 1
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


func unit_screen_pos(u: Dictionary) -> Vector2:
	return ORIGIN + (Vector2(float(u["pos"][0]), float(u["pos"][1])) + Vector2(0.5, 0.5)) * CS


func _draw_units() -> void:
	var keys: Array = sp.state.units.keys()
	keys.sort()
	# heal beams under the bodies
	for uid in keys:
		var u: Dictionary = sp.state.units[uid]
		if str(u["state"]) == "heal" and sp.state.units.has(int(u["target"])):
			var a := unit_screen_pos(u)
			var b := unit_screen_pos(sp.state.units[int(u["target"])])
			if a.distance_to(b) <= 2.2 * CS:
				draw_line(a, b, Color(0.5, 1.0, 0.6, 0.35 + 0.25 * sin(t * 8.0)), 3.0)
	for uid in keys:
		_draw_unit(sp.state.units[uid])


func _draw_unit(u: Dictionary) -> void:
	var p := unit_screen_pos(u)
	var def_id := str(u["def"])
	var period := 1.0
	var lunge := Vector2.ZERO
	var cd := float(u["cd"])
	if cd > period - 0.2 and str(u["state"]) == "engage":
		var tp := p
		if str(u["target_kind"]) == "unit" and sp.state.units.has(int(u["target"])):
			tp = unit_screen_pos(sp.state.units[int(u["target"])])
		elif str(u["target_kind"]) == "organ" and sp.state.organs.has(int(u["target"])):
			tp = organ_rect(int(u["target"])).get_center()
		if tp != p:
			lunge = (tp - p).normalized() * 4.0
	p += lunge
	var bob := sin(t * 6.0 + float(u["uid"])) * 0.8
	var hidden := bool(u.get("hidden", false))
	var a := 0.35 if hidden else 1.0
	match def_id:
		"species.bone_crawler":
			_blob(p + Vector2(0, bob * 0.3), Vector2(7.5, 6.0), Color(0.78, 0.72, 0.6, a), Color(0.35, 0.3, 0.25, a))
			for k in 3:
				draw_arc(p + Vector2(-3 + k * 3, 0), 4.0, PI * 1.1, PI * 1.9, 6, Color(0.45, 0.4, 0.33, a), 1.5)
			for side in [-1.0, 1.0]:
				draw_line(p + Vector2(side * 6, 2), p + Vector2(side * 9, 5 + bob), Color(0.6, 0.55, 0.45, a), 1.5)
		"species.blood_tick":
			for k in 4:
				var ang := PI * (0.15 + 0.23 * k)
				draw_line(p, p + Vector2.from_angle(ang) * 7.0 + Vector2(0, bob), Color(0.4, 0.05, 0.08, a), 1.2)
				draw_line(p, p + Vector2.from_angle(PI - ang) * 7.0 + Vector2(0, bob), Color(0.4, 0.05, 0.08, a), 1.2)
			draw_circle(p, 4.5, Color(0.75, 0.08, 0.14, a))
			draw_circle(p + Vector2(-1.5, -1.5), 1.4, Color(1, 0.5, 0.5, a))
		"species.devourer":
			_blob(p, Vector2(8.0, 5.5), Color(0.45, 0.06, 0.1, a), Color(0.2, 0.02, 0.04, a))
			var jaw := 0.25 + 0.2 * absf(sin(t * 5.0))
			draw_arc(p + Vector2(5, 0), 3.5, -jaw * PI, jaw * PI, 8, Color(0.95, 0.85, 0.75, a), 2.0)
			draw_circle(p + Vector2(2, -2.5), 1.2, Color(1, 0.8, 0.3, a))
		"species.nerve_stalker":
			if hidden:
				draw_arc(p, 6.0, 0.0, TAU, 14, Color(0.7, 0.55, 1.0, 0.25 + 0.15 * sin(t * 3.0)), 1.0)
			else:
				var pts := PackedVector2Array([p + Vector2(0, -8), p + Vector2(5, 3), p + Vector2(0, 6), p + Vector2(-5, 3)])
				draw_colored_polygon(pts, Color(0.45, 0.25, 0.8))
				for side in [-1.0, 1.0]:
					draw_line(p + Vector2(side * 3, -2), p + Vector2(side * 9, -6 + bob), Color(0.7, 0.55, 1.0), 1.2)
				draw_circle(p + Vector2(0, -3), 1.3, Color(1, 1, 1))
		"species.lymphatic":
			_blob(p + Vector2(0, bob * 0.5), Vector2(6.5, 6.5), Color(0.5, 0.95, 0.65, 0.55 * a), Color(0.75, 1.0, 0.85, 0.8 * a))
			draw_circle(p + Vector2(1, 1), 2.0, Color(0.9, 1.0, 0.9, 0.8 * a))
		"species.zero":
			_draw_zero(p, bob, u)
		"enemy.pilgrim", "enemy.knight", "enemy.burner":
			_draw_invader(p, def_id, bob)
	var ratio := float(u["hp"]) / maxf(1.0, float(u["max_hp"]))
	if ratio < 1.0 and not hidden:
		var bar := Rect2(p + Vector2(-7, -13), Vector2(14, 2.5))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		var col := Color(0.85, 0.2, 0.25) if str(u["team"]) == "abyss" else Color(1.0, 0.8, 0.45)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), 2.5)), col)
	if str(u["state"]) == "retreat" or str(u["state"]) == "recover":
		draw_arc(p, 9.0, 0.0, TAU * fmod(t, 1.0), 10, Color(0.6, 0.8, 1.0, 0.6), 1.0)
	var mk := 0
	for m in u.get("mutations", []):
		draw_circle(p + Vector2(-8 + mk * 3.5, 9), 1.4, Color(0.75, 0.5, 1.0))
		mk += 1
	for x in u.get("defects", []):
		draw_circle(p + Vector2(-8 + mk * 3.5, 9), 1.4, Color(1.0, 0.3, 0.25))
		mk += 1
	if float(u.get("slow_t", 0.0)) > 0.0:
		draw_arc(p, 7.0, 0.0, TAU, 10, Color(0.6, 0.9, 0.4, 0.5), 1.0)
	if float(u.get("infect_t", 0.0)) > 0.0:
		draw_circle(p + Vector2(6, -6), 2.0, Color(0.4, 0.9, 0.2, 0.9))


## Zero: a child's silhouette in a bone mask (Narrative Bible 6.2). Form: Vessel.
func _draw_zero(p: Vector2, bob: float, u: Dictionary) -> void:
	var body := Color(0.08, 0.05, 0.1)
	var glow := 0.5 + 0.5 * sin(t * 2.0)
	draw_circle(p + Vector2(0, -2), 11.0, Color(0.6, 0.8, 1.0, 0.06 + 0.05 * glow))
	# small body and thin legs
	var torso := PackedVector2Array([p + Vector2(-4, -2), p + Vector2(4, -2), p + Vector2(5, 7), p + Vector2(-5, 7)])
	draw_colored_polygon(torso, body)
	draw_line(p + Vector2(-2, 7), p + Vector2(-2.5, 11 + bob * 0.3), body, 2.0)
	draw_line(p + Vector2(2, 7), p + Vector2(2.5, 11 - bob * 0.3), body, 2.0)
	# bone fingers
	draw_line(p + Vector2(-5, 0), p + Vector2(-8, 6), Color(0.85, 0.8, 0.7), 1.2)
	draw_line(p + Vector2(5, 0), p + Vector2(8, 6), Color(0.85, 0.8, 0.7), 1.2)
	# the mask grown from his skull
	var m := p + Vector2(0, -7 + bob * 0.4)
	draw_circle(m, 5.5, Color(0.9, 0.86, 0.76))
	draw_circle(m + Vector2(-2, -0.5), 1.4, Color(0.05, 0.03, 0.05))
	draw_circle(m + Vector2(2, -0.5), 1.4, Color(0.05, 0.03, 0.05))
	draw_line(m + Vector2(-1.5, 3), m + Vector2(1.5, 3), Color(0.4, 0.35, 0.3), 1.0)
	draw_line(m + Vector2(1, -5), m + Vector2(2.5, -1), Color(0.5, 0.45, 0.4), 0.8)   # crack
	if int(u.get("level", 1)) > 1:
		draw_string(ThemeDB.fallback_font, p + Vector2(7, -9), str(int(u["level"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.85, 1.0))


func _draw_invader(p: Vector2, def_id: String, bob: float) -> void:
	var robe := Color(0.45, 0.33, 0.2)
	var trim := Color(1.0, 0.8, 0.45)
	if def_id == "enemy.knight":
		robe = Color(0.62, 0.64, 0.7)
	elif def_id == "enemy.burner":
		robe = Color(0.6, 0.15, 0.1)
	var pts := PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 8), p + Vector2(-6, 8)])
	draw_colored_polygon(pts, robe)
	draw_circle(p + Vector2(0, -7), 3.2, Color(0.85, 0.72, 0.6))
	match def_id:
		"enemy.pilgrim":
			draw_line(p + Vector2(5, -2), p + Vector2(8, 4), Color(0.4, 0.3, 0.2), 1.2)
			draw_circle(p + Vector2(8, 5 + bob * 0.4), 2.2, Color(1.0, 0.85, 0.4, 0.9))
		"enemy.knight":
			draw_line(p + Vector2(6, -8), p + Vector2(6, 6), Color(0.95, 0.95, 1.0), 2.0)
			draw_line(p + Vector2(3.5, -3), p + Vector2(8.5, -3), trim, 1.5)
			draw_circle(p + Vector2(0, -7), 3.4, Color(0.7, 0.72, 0.8))
		"enemy.burner":
			var f := 2.0 + sin(t * 12.0) * 0.8
			draw_circle(p + Vector2(7, -3), f + 1.0, Color(1.0, 0.4, 0.1, 0.7))
			draw_circle(p + Vector2(7, -3.5), f * 0.6, Color(1.0, 0.85, 0.3))
	draw_line(p + Vector2(-4, 1), p + Vector2(4, 1), trim, 1.0)


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
