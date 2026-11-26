extends Control
## The Lair drawn as a cavern. Each building has a spot; built ones glow,
## available ones are outlined, locked ones are dark. Lines show what requires what.

const D = preload("res://scripts/data/game_data.gd")
const Art = preload("res://scripts/ui/art.gd")
const Icons = preload("res://scripts/ui/icons.gd")

signal selected(id: String)

## What each building looks like on the map: an icon kind, or "card:<id>" for a card glyph.
const LOOKS := {
	"forge": "dmg", "walls": "def", "larder": "hp", "pit": "devour", "pens": "card:crypt",
	"traps": "card:spikes", "archive": "eye", "reliquary": "relic", "library": "arcane",
	"treasury": "gold", "golden_hoard": "card:chest", "shrine": "holy", "stones": "rumors",
	"jars": "card:jar", "brood_chamber": "card:spider", "bait_workshop": "trail",
}

var current := ""
var hover := ""
var cave: PackedVector2Array


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_make_cave()


func _make_cave() -> void:
	# an irregular cavern outline around the spots
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pts := PackedVector2Array()
	var c := size * 0.5
	for i in 48:
		var a := TAU * i / 48.0
		var r := Vector2(size.x * 0.5, size.y * 0.5) * rng.randf_range(0.9, 1.0)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	cave = pts


func spot(id: String) -> Vector2:
	var p: Vector2 = D.BUILDINGS[id]["pos"]
	var pad := Vector2(50, 40)
	return pad + p * (size - pad * 2)


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		hover = _hit(mm.position)
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var id := _hit(mb.position)
		if id != "":
			current = id
			selected.emit(id)


func _hit(p: Vector2) -> String:
	for id in D.BUILDINGS:
		if spot(id).distance_to(p) < 30.0:
			return id
	return ""


func _draw() -> void:
	if cave.is_empty():
		_make_cave()
	draw_colored_polygon(cave, Color(0.07, 0.05, 0.1, 0.85))
	var closed := cave.duplicate()
	closed.append(cave[0])
	draw_polyline(closed, Color(0.25, 0.18, 0.32), 3.0)
	var font := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() / 1000.0

	# requirement links
	for id in D.BUILDINGS:
		var req: Dictionary = D.BUILDINGS[id].get("requires", {})
		for b in req:
			var built: bool = Meta.level(id) > 0
			draw_line(spot(b), spot(id), Color(0.55, 0.35, 0.7, 0.6) if built else Color(0.3, 0.25, 0.35, 0.35), 2.0)

	for id in D.BUILDINGS:
		var p := spot(id)
		var lvl: int = Meta.level(id)
		var max_lvl: int = Meta.max_level(id)
		var can: bool = Meta.requirements_met(id)
		var r := 24.0
		if id == "den":
			# the Warden's den is where the dungeon's heart beats
			Icons.heart(self, p + Vector2(0, -2), 1.5, t, 50.0 + 6.0 * lvl, 0.2 + 0.1 * lvl)
			if id == current or id == hover:
				draw_arc(p, r + 14, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0)
		elif lvl > 0:
			var glow := 0.5 + 0.5 * sin(t * 2.0 + p.x)
			draw_circle(p, r + 8, Color(0.8, 0.45, 1.0, 0.12 + 0.08 * glow))
			if not Art.draw(self, "lair_" + id, p, r * 2.2):
				draw_circle(p, r, Color(0.32, 0.18, 0.42))
			draw_arc(p, r, 0, TAU, 32, Color(0.85, 0.65, 1.0), 2.0)
		elif can:
			draw_circle(p, r, Color(0.12, 0.09, 0.15))
			draw_arc(p, r, 0, TAU, 32, Color(0.6, 0.5, 0.7, 0.8), 2.0)
			var cost: Dictionary = Meta.next_cost(id)
			if Meta.can_afford(cost):
				draw_arc(p, r + 4, 0, TAU, 32, Color(1, 0.85, 0.4, 0.5 + 0.4 * sin(t * 4.0)), 2.0)
		else:
			draw_circle(p, r, Color(0.05, 0.04, 0.06))
			draw_arc(p, r, 0, TAU, 32, Color(0.25, 0.22, 0.28), 1.5)
		if id != "den" and (id == current or id == hover):
			draw_arc(p, r + 7, 0, TAU, 40, Color(1, 1, 1, 0.8), 2.0)
		if id != "den" and LOOKS.has(id) and not Art.tex("lair_" + id):
			var look: String = LOOKS[id]
			var a := 1.0 if lvl > 0 else (0.55 if can else 0.2)
			if look.begins_with("card:"):
				draw_set_transform(p + Vector2(0, -3), 0.0, Vector2(0.8, 0.8))
				Icons.card_glyph(self, look.substr(5), Vector2.ZERO, t)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				Icons.paint(self, look, p, 22.0, Color(Icons.color_of(look), a))
		# level pips
		for k in max_lvl:
			var pp := p + Vector2((k - (max_lvl - 1) * 0.5) * 8.0, r + 7)
			draw_circle(pp, 2.5, Color(1, 0.8, 0.4) if k < lvl else Color(0.3, 0.27, 0.33))
		var name_col := Color(1, 1, 1, 0.9) if lvl > 0 else (Color(1, 1, 1, 0.55) if can else Color(1, 1, 1, 0.25))
		var label: String = Loc.t(D.BUILDINGS[id]["name"])
		draw_string(font, p + Vector2(-70, r + 24), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, name_col)
