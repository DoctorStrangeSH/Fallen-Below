extends RefCounted
## Drawn icons for the HUD (stats, slots, resources, lures, controls) and card glyphs.
## A sprite named `icon_<kind>` / `card_<id>` in res://art/ replaces the drawing.

const Art = preload("res://scripts/ui/art.gd")
const D = preload("res://scripts/data/game_data.gd")

const BONE := Color(0.92, 0.88, 0.78)

const COLORS := {
	"dmg": Color(1.0, 0.55, 0.4), "hp": Color(0.95, 0.3, 0.35), "def": Color(0.6, 0.75, 0.95),
	"regen": Color(0.45, 0.9, 0.5), "vamp": Color(0.85, 0.15, 0.3), "evade": Color(0.7, 0.95, 0.95),
	"counter": Color(1.0, 0.8, 0.35), "bones": BONE, "blood": Color(0.85, 0.15, 0.2),
	"gold": Color(1.0, 0.8, 0.25), "sun": Color(1.0, 0.85, 0.45), "moon": Color(0.75, 0.8, 1.0),
}


static func color_of(kind: String) -> Color:
	return COLORS.get(kind, Color(0.85, 0.8, 0.95))


## Draws icon `kind` on canvas item `ci`, centred at `c`, roughly `sz` pixels across.
static func paint(ci: CanvasItem, kind: String, c: Vector2, sz: float, col: Color) -> void:
	if Art.draw(ci, "icon_" + kind, c, sz):
		return
	var k := sz / 16.0
	var dark := Color(0.06, 0.04, 0.08)
	match kind:
		"dmg", "weapon":
			ci.draw_line(c + Vector2(-6, 6) * k, c + Vector2(6, -6) * k, col, 2.5 * k)
			ci.draw_line(c + Vector2(-6, 1) * k, c + Vector2(-1, 6) * k, col, 2.0 * k)
			ci.draw_line(c + Vector2(-7, 7) * k, c + Vector2(-4.5, 4.5) * k, col.darkened(0.3), 3.0 * k)
		"hp":
			ci.draw_circle(c + Vector2(-3.2, -2) * k, 3.8 * k, col)
			ci.draw_circle(c + Vector2(3.2, -2) * k, 3.8 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6.8, -0.5) * k, c + Vector2(6.8, -0.5) * k, c + Vector2(0, 7) * k]), col)
		"def", "shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -7) * k, c + Vector2(6, -7) * k, c + Vector2(6, 0) * k,
				c + Vector2(0, 7.5) * k, c + Vector2(-6, 0) * k]), col)
			ci.draw_line(c + Vector2(0, -5) * k, c + Vector2(0, 5) * k, col.darkened(0.35), 1.5 * k)
		"regen":
			ci.draw_rect(Rect2(c + Vector2(-2, -7) * k, Vector2(4, 14) * k), col)
			ci.draw_rect(Rect2(c + Vector2(-7, -2) * k, Vector2(14, 4) * k), col)
		"vamp", "blood":
			ci.draw_circle(c + Vector2(0, 2.5) * k, 4.8 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7.5) * k, c + Vector2(-4.6, 1) * k, c + Vector2(4.6, 1) * k]), col)
		"evade":
			for i in 2:
				var o := Vector2(i * 5 - 4, 0) * k
				ci.draw_polyline(PackedVector2Array([c + o + Vector2(-2, -6) * k, c + o + Vector2(3, 0) * k, c + o + Vector2(-2, 6) * k]), col, 2.2 * k)
		"counter":
			ci.draw_arc(c + Vector2(0, 1) * k, 5.5 * k, PI * 1.1, PI * 2.2, 10, col, 2.2 * k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0) * k, c + Vector2(-3, 0) * k, c + Vector2(-6, 5) * k]), col)
		"bones":
			for sgn in [-1.0, 1.0]:
				var a := c + Vector2(-5 * sgn, -5) * k
				var b := c + Vector2(5 * sgn, 5) * k
				ci.draw_line(a, b, col, 2.4 * k)
				ci.draw_circle(a, 2.0 * k, col)
				ci.draw_circle(b, 2.0 * k, col)
		"gold":
			ci.draw_circle(c, 6.5 * k, col)
			ci.draw_arc(c, 4.2 * k, 0, TAU, 16, col.darkened(0.35), 1.4 * k)
		"sun":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 5.5 * k, c + Vector2(cos(a), sin(a)) * 8 * k, col, 1.6 * k)
			ci.draw_circle(c, 4.2 * k, col)
		"moon":
			ci.draw_circle(c, 6.5 * k, col)
			ci.draw_circle(c + Vector2(3, -2.5) * k, 5.5 * k, Color(0.16, 0.11, 0.22))
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-5, -6) * k, Vector2(3.5, 12) * k), col)
			ci.draw_rect(Rect2(c + Vector2(1.5, -6) * k, Vector2(3.5, 12) * k), col)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -6.5) * k, c + Vector2(6, 0) * k, c + Vector2(-4, 6.5) * k]), col)
		"skull", "raise":
			ci.draw_circle(c + Vector2(0, -1.5) * k, 6 * k, col)
			ci.draw_rect(Rect2(c + Vector2(-3.5, 2) * k, Vector2(7, 5) * k), col)
			ci.draw_circle(c + Vector2(-2.4, -1.5) * k, 1.7 * k, dark)
			ci.draw_circle(c + Vector2(2.4, -1.5) * k, 1.7 * k, dark)
		"devour":
			ci.draw_arc(c, 7 * k, 0.2, PI - 0.2, 12, col, 2.2 * k)
			ci.draw_arc(c, 7 * k, PI + 0.2, TAU - 0.2, 12, col, 2.2 * k)
			for i in 3:
				var x := (i - 1) * 4.0
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 1.8, -5) * k, c + Vector2(x + 1.8, -5) * k, c + Vector2(x, -0.5) * k]), col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 1.8, 5) * k, c + Vector2(x + 1.8, 5) * k, c + Vector2(x, 0.5) * k]), col)
		"armor":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -5) * k, c + Vector2(-3, -7) * k, c + Vector2(0, -5) * k,
				c + Vector2(3, -7) * k, c + Vector2(7, -5) * k, c + Vector2(5, 0) * k, c + Vector2(5, 7) * k, c + Vector2(-5, 7) * k, c + Vector2(-5, 0) * k]), col)
		"amulet":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-6, -7) * k, c + Vector2(0, 1) * k, c + Vector2(6, -7) * k]), col.darkened(0.2), 1.3 * k)
			ci.draw_circle(c + Vector2(0, 3) * k, 4 * k, col)
		"ring":
			ci.draw_arc(c + Vector2(0, 1.5) * k, 5 * k, 0, TAU, 18, col, 2.4 * k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7.5) * k, c + Vector2(-3, -4) * k, c + Vector2(0, -2) * k, c + Vector2(3, -4) * k]), col.lightened(0.3))
		"eye", "rumors":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 0) * k, c + Vector2(0, -5) * k, c + Vector2(8, 0) * k, c + Vector2(0, 5) * k]), col)
			ci.draw_circle(c, 2.8 * k, dark)
		"flame", "holy":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8) * k, c + Vector2(5, 1) * k, c + Vector2(3, 6) * k,
				c + Vector2(-3, 6) * k, c + Vector2(-5, 1) * k]), col)
			ci.draw_circle(c + Vector2(0, 3) * k, 2.5 * k, Color(1, 0.95, 0.7))
		"star", "arcane", "ability":
			var pts := PackedVector2Array()
			for i in 8:
				var a := TAU * i / 8.0 - PI / 2.0
				var r := 8.0 if i % 2 == 0 else 3.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * k)
			ci.draw_colored_polygon(pts, col)
		"martyr":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8) * k, c + Vector2(5, 1) * k, c + Vector2(3, 6) * k,
				c + Vector2(-3, 6) * k, c + Vector2(-5, 1) * k]), Color(1.0, 0.4, 0.15, col.a))
			ci.draw_line(c + Vector2(0, -6) * k, c + Vector2(0, 7) * k, col, 1.6 * k)
			ci.draw_line(c + Vector2(-4, -2) * k, c + Vector2(4, -2) * k, col, 1.6 * k)
		"incense":
			ci.draw_circle(c + Vector2(0, 3) * k, 4.5 * k, col)
			ci.draw_line(c + Vector2(0, -1) * k, c + Vector2(0, -8) * k, col.darkened(0.3), 1.2 * k)
			ci.draw_arc(c + Vector2(4, -4) * k, 3 * k, PI, TAU, 8, Color(col, 0.5), 1.2 * k)
			ci.draw_arc(c + Vector2(6, -8) * k, 2 * k, 0, PI, 8, Color(col, 0.4), 1.2 * k)
		"crystal", "vein":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8) * k, c + Vector2(5, -1) * k, c + Vector2(0, 8) * k, c + Vector2(-5, -1) * k]), col)
			ci.draw_line(c + Vector2(0, -8) * k, c + Vector2(0, 8) * k, col.lightened(0.4), 1.0 * k)
		"pick", "shaft":
			ci.draw_line(c + Vector2(-5, 7) * k, c + Vector2(3, -3) * k, Color(0.6, 0.45, 0.3), 2.2 * k)
			ci.draw_arc(c + Vector2(4, 0) * k, 7 * k, PI * 1.05, PI * 1.75, 10, col, 2.6 * k)
		"lock":
			ci.draw_arc(c + Vector2(0, -2) * k, 4 * k, PI, TAU, 10, col, 2.0 * k)
			ci.draw_rect(Rect2(c + Vector2(-5.5, -2) * k, Vector2(11, 9) * k), col)
		"relic":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7) * k, c + Vector2(6, 0) * k, c + Vector2(0, 7) * k, c + Vector2(-6, 0) * k]), col)
			ci.draw_circle(c, 2 * k, Color(1, 1, 1, 0.7))
		_:
			ci.draw_circle(c, 5 * k, col)


## Small drawn picture of a card, used on the map and in the hand.
static func card_glyph(ci: CanvasItem, card: String, c: Vector2, t: float) -> void:
	if Art.draw(ci, "card_" + card, c, 40.0):
		return
	var col: Color = D.CARDS[card]["color"]
	match card:
		"crypt", "catacomb", "necropolis":
			var n := 1 if card == "crypt" else 2
			for k in n:
				var o := Vector2((k - (n - 1) * 0.5) * 14, -4)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-5, -9), c + o + Vector2(5, -9), c + o + Vector2(7, 9), c + o + Vector2(-7, 9)]), col.darkened(0.2))
				ci.draw_line(c + o + Vector2(-3, -2), c + o + Vector2(3, -2), BONE, 1.5)
			if card == "necropolis":
				ci.draw_arc(c + Vector2(0, -2), 16, PI, TAU, 16, Color(0.5, 1, 0.8), 2.0)
		"spider", "queen":
			ci.draw_circle(c + Vector2(0, -6), 9 if card == "queen" else 6, col.darkened(0.3))
			for k in 6:
				var a := TAU * k / 6.0
				ci.draw_line(c + Vector2(0, -6), c + Vector2(0, -6) + Vector2(cos(a), sin(a)) * 15, Color(0.85, 0.85, 0.85, 0.5), 1.0)
		"spikes", "grinder":
			for k in 3:
				var x := (k - 1) * 10.0
				var tip := c + Vector2(x, -15)
				ci.draw_colored_polygon(PackedVector2Array([tip, c + Vector2(x - 4, -2), c + Vector2(x + 4, -2)]), Color(0.75, 0.72, 0.7))
			if card == "grinder":
				ci.draw_arc(c + Vector2(0, -6), 13, t * 4.0, t * 4.0 + PI * 1.5, 12, Color(0.9, 0.2, 0.2), 2.5)
		"cavein":
			for k in 4:
				var o := Vector2((k % 2) * 10 - 5, (k / 2) * 8 - 10)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-6, 3), c + o + Vector2(0, -5), c + o + Vector2(6, 3)]), col.lightened(0.1 * k))
			ci.draw_line(c + Vector2(-14, -14), c + Vector2(14, -14), Color(0.4, 0.3, 0.2), 3.0)
		"drowned":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -11), c + Vector2(6, -11), c + Vector2(8, 7), c + Vector2(-8, 7)]), col.darkened(0.3))
			var wave := sin(t * 2.0) * 2.0
			ci.draw_rect(Rect2(c + Vector2(-14, 2 + wave), Vector2(28, 6)), Color(0.15, 0.4, 0.55, 0.7))
		"pyre":
			for k in 3:
				ci.draw_line(c + Vector2(-12, 6 - k * 4), c + Vector2(12, 2 - k * 4), Color(0.45, 0.3, 0.18), 3.0)
			var fl := 4.0 * sin(t * 8.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -4), c + Vector2(0, -18 - fl), c + Vector2(8, -4)]), Color(1.0, 0.45, 0.1))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -4), c + Vector2(0, -12 - fl * 0.5), c + Vector2(4, -4)]), Color(1.0, 0.85, 0.4))
		"ashcrypt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -11), c + Vector2(6, -11), c + Vector2(8, 7), c + Vector2(-8, 7)]), col.darkened(0.2))
			ci.draw_line(c + Vector2(-3, -4), c + Vector2(3, -4), Color(1, 0.55, 0.2), 1.5)
			for k in 3:
				ci.draw_circle(c + Vector2(-10 + k * 10, 10), 2.0, Color(0.7, 0.68, 0.65, 0.6))
		"chest", "mimic":
			ci.draw_rect(Rect2(c + Vector2(-11, -12), Vector2(22, 14)), col.darkened(0.2))
			ci.draw_rect(Rect2(c + Vector2(-11, -12), Vector2(22, 4)), col.lightened(0.2))
			if card == "mimic":
				for k in 4:
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9 + k * 6, -8), c + Vector2(-6 + k * 6, -8), c + Vector2(-7.5 + k * 6, -3)]), BONE)
			else:
				ci.draw_circle(c + Vector2(0, -5), 2, Color(1, 0.9, 0.4))
		"altar", "spire":
			var h := 22.0 if card == "spire" else 14.0
			ci.draw_rect(Rect2(c + Vector2(-10, 2), Vector2(20, 7)), Color(0.3, 0.24, 0.33))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 2), c + Vector2(6, 2), c + Vector2(0, 2 - h)]), col.darkened(0.2))
			ci.draw_circle(c + Vector2(0, -h), 3.5, col.lightened(0.3))
		"graveyard":
			for k in 3:
				var p := c + Vector2((k - 1) * 12, 2 - (k % 2) * 4)
				ci.draw_rect(Rect2(p + Vector2(-4, -8), Vector2(8, 12)), Color(0.5, 0.52, 0.5))
				ci.draw_circle(p + Vector2(0, -8), 4, Color(0.5, 0.52, 0.5))
		"jar":
			ci.draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 18)), Color(col, 0.6))
			ci.draw_rect(Rect2(c + Vector2(-5, -12), Vector2(10, 4)), Color(0.5, 0.4, 0.3))
			ci.draw_circle(c + Vector2(0, 1), 4.0 + sin(t * 3.0), Color(0.6, 0.9, 1.0, 0.8))
		_:
			ci.draw_rect(Rect2(c - Vector2(10, 10), Vector2(20, 20)), col)
	# a thin colour bar so the card type is readable at a glance
	ci.draw_rect(Rect2(c + Vector2(-20, 17), Vector2(40, 3)), col)


## Heartbeat with a "lub-dub" double pulse. Returns 0..1.
static func heartbeat(t: float, bpm: float) -> float:
	var ph := fmod(t * bpm / 60.0, 1.0)
	return exp(-pow((ph - 0.06) / 0.045, 2.0)) + 0.55 * exp(-pow((ph - 0.24) / 0.045, 2.0))


## The dungeon's heart: a dark muscle caged in ribs, with glowing seams that
## flare on every beat. `sc` 1.0 is about one map tile; `hunger` 0..1 makes it glow hotter.
static func heart(ci: CanvasItem, c: Vector2, sc: float, t: float, bpm: float = 60.0, hunger: float = 0.3) -> void:
	var beat := heartbeat(t, bpm)
	var s := sc * (1.0 + 0.08 * beat)
	var hot := clampf(0.3 + 0.5 * hunger + 0.45 * beat, 0.0, 1.0)
	var line_w := minf(sc, 3.0)  # strokes stay fine when the heart is drawn large

	# glow
	for i in 8:
		var f := 1.0 - i / 8.0
		ci.draw_circle(c, (12.0 + 30.0 * f) * sc * (1.0 + 0.12 * beat), Color(0.8, 0.06, 0.14, 0.03 + 0.025 * beat))

	# great vessels behind, rising from the top
	var vessel := Color(0.38, 0.04, 0.09)
	ci.draw_arc(c + Vector2(4, -13) * s, 8.0 * s, PI * 1.05, PI * 1.85, 14, vessel, 5.0 * sc)
	ci.draw_line(c + Vector2(-5, -9) * s, c + Vector2(-8, -20) * s, vessel.darkened(0.15), 4.0 * sc)
	ci.draw_line(c + Vector2(9, -8) * s, c + Vector2(14, -16) * s, vessel.darkened(0.25), 3.0 * sc)
	for e in [Vector2(-8, -20), Vector2(14, -16), Vector2(11.5, -19.5)]:
		ci.draw_circle(c + (e as Vector2) * s, 1.6 * sc, Color(0.16, 0.01, 0.04))

	# ribs cradling it on both sides: ( ( heart ) )
	var bone := Color(0.8, 0.74, 0.64)
	for k in 3:
		var y := -8.0 + k * 8.0
		var r := 21.0 - absf(k - 1) * 2.5 + k * 1.5
		for side in [-1.0, 1.0]:
			var a0: float = PI * 0.72 if side < 0.0 else -PI * 0.28
			var a1: float = PI * 1.22 if side < 0.0 else PI * 0.22
			var cc := c + Vector2(0, y) * sc
			ci.draw_arc(cc, r * sc, a0, a1, 14, Color(bone.darkened(0.25 + 0.1 * k), 0.95), 3.2 * line_w)
			ci.draw_arc(cc, r * sc, a0 + 0.05, a1 - 0.05, 14, Color(bone, 0.9), 1.6 * line_w)
			ci.draw_circle(cc + Vector2.from_angle(a0) * r * sc, 1.9 * line_w, bone.darkened(0.2))
			ci.draw_circle(cc + Vector2.from_angle(a1) * r * sc, 1.9 * line_w, bone.darkened(0.2))

	# the muscle: a lopsided heart curve with a slow organic wobble, shaded in soft layers
	var layers := [[1.0, Color(0.3, 0.02, 0.07)], [0.86, Color(0.42, 0.04, 0.09)], [0.68, Color(0.55, 0.06, 0.12)], [0.45, Color(0.68, 0.1, 0.15)]]
	var outline := PackedVector2Array()
	for li in layers.size():
		var k: float = layers[li][0]
		var col: Color = layers[li][1]
		col = col.lerp(Color(0.9, 0.15, 0.18), beat * 0.25 * li / 3.0)
		var poly := PackedVector2Array()
		for i in 44:
			var th := TAU * i / 44.0
			var x := 16.0 * pow(sin(th), 3.0)
			var y := -(13.0 * cos(th) - 5.0 * cos(2.0 * th) - 2.0 * cos(3.0 * th) - cos(4.0 * th))
			var wob := 1.0 + 0.035 * sin(th * 5.0 + t * 1.3)
			var p := Vector2(x, y + 1.5) * 0.92 * wob
			p = (p * k + Vector2(-3.0, -3.5) * (1.0 - k)).rotated(-0.22)
			poly.append(c + p * s)
		ci.draw_colored_polygon(poly, col)
		if li == 0:
			outline = poly
	var closed := outline.duplicate()
	closed.append(outline[0])
	ci.draw_polyline(closed, Color(0.1, 0.0, 0.03, 0.9), 1.2 * line_w)

	# glowing seams, branching like cracks in cooling lava
	var seam := Color(1.0, 0.45 + 0.3 * hot, 0.2, 0.3 + 0.7 * hot)
	var seams := [
		[Vector2(-1, -8), Vector2(-3, -3), Vector2(-2, 1), Vector2(-5, 6), Vector2(-4, 10)],
		[Vector2(-2, 1), Vector2(-8, 2), Vector2(-11, -1)],
		[Vector2(5, -6), Vector2(6, -1), Vector2(4, 3), Vector2(6, 7)],
		[Vector2(4, 3), Vector2(1, 7), Vector2(0, 12)],
		[Vector2(6, -1), Vector2(10, -3)],
	]
	for line in seams:
		var pl := PackedVector2Array()
		for p in line:
			pl.append(c + (p as Vector2).rotated(-0.22) * s)
		ci.draw_polyline(pl, Color(seam, seam.a * 0.25), 2.6 * line_w)
		ci.draw_polyline(pl, seam, 0.9 * line_w)
	# a wet sheen along the upper left curve
	for i in 5:
		var a := PI * (1.05 + i * 0.08)
		ci.draw_circle(c + (Vector2(-6.5, -5.5) + Vector2.from_angle(a) * 4.5).rotated(-0.22) * s, (1.4 - i * 0.18) * line_w, Color(1, 0.75, 0.75, 0.28))


## A Warden figure: a bone mask over a dark body, in the Warden's colour.
static func warden_figure(ci: CanvasItem, p: Vector2, col: Color, sc: float, t: float) -> void:
	var glow := 0.5 + 0.5 * sin(t * 2.0)
	ci.draw_circle(p, 30.0 * sc, Color(col, 0.08 + 0.06 * glow))
	ci.draw_circle(p + Vector2(0, 22) * sc, 16.0 * sc, Color(0, 0, 0, 0.35))
	var body := PackedVector2Array([p + Vector2(0, -18) * sc, p + Vector2(16, -3) * sc, p + Vector2(11, 18) * sc,
		p + Vector2(-11, 18) * sc, p + Vector2(-16, -3) * sc])
	ci.draw_colored_polygon(body, Color(0.08, 0.1, 0.15))
	var closed := body.duplicate()
	closed.append(body[0])
	ci.draw_polyline(closed, col, 2.0 * sc)
	for k in 3:
		ci.draw_line(p + Vector2(-8, 1 + k * 5) * sc, p + Vector2(8, 1 + k * 5) * sc, col.darkened(0.35), 1.4 * sc)
	ci.draw_circle(p + Vector2(-5, -7) * sc, 2.6 * sc, col.lightened(0.5))
	ci.draw_circle(p + Vector2(5, -7) * sc, 2.6 * sc, col.lightened(0.5))
