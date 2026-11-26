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
