extends Control
## After the Archon falls: the key to the Night's chains is in Ren's hands.
## Three endings. The true one needs the whole Book of the Fallen: the truth the raised dead told.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const CHOICES := [
	{"id": "ending_hunger", "icon": "devour", "color": Color(1.0, 0.55, 0.3), "name": "Devour the Archon",
		"desc": "Take his light into yourself. Become the new sun: eternal day, paid for with eternal hunger."},
	{"id": "ending_night", "icon": "moon", "color": Color(0.7, 0.75, 1.0), "name": "Break the chains",
		"desc": "Set the Night free. The false sun goes out, and the world sees its first true night in a thousand years."},
	{"id": "ending_fallen", "icon": "skull", "color": Color(0.6, 1.0, 0.8), "name": "Rise with the Fallen",
		"desc": "Break the chains and lead the raised dead up into the world, to tell everyone what they knew.", "book": true},
]

var heart: Control


func _ready() -> void:
	Music.play("story")
	UI.background(self)
	var tip := UI.hover_tip(self)

	heart = Control.new()
	heart.position = Vector2(440, 40)
	heart.size = Vector2(400, 240)
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.draw.connect(func():
		var t := Time.get_ticks_msec() / 1000.0
		Icons.heart(heart, Vector2(200, 120), 3.2, t, 40.0, 0.2)
		# the chains, still holding
		for side in [-1.0, 1.0]:
			for k in 7:
				var p := Vector2(200 + side * (70 + k * 18), 120 + sin(k * 0.9) * 10)
				heart.draw_arc(p, 7, 0, TAU, 10, Color(0.6, 0.6, 0.65, 0.8 - k * 0.09), 2.5)
	)
	add_child(heart)

	var title := UI.title(Loc.t("THE KEY TO THE CHAINS"), 32, true)
	title.position = Vector2(290, 280)
	title.size = Vector2(700, 0)
	add_child(title)
	var text := UI.label(Loc.t("The Archon lies still. The key is cold in Ren's hand, and the chains of the Night ring softly, waiting."), 17, Color(1, 1, 1, 0.75))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.position = Vector2(240, 344)
	text.size = Vector2(800, 50)
	add_child(text)

	var row := HBoxContainer.new()
	row.position = Vector2(64, 420)
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var have: int = Meta.fragment_count()
	var total: int = Meta.fragment_total()
	for c in CHOICES:
		var locked: bool = c.get("book", false) and have < total
		var col: Color = c["color"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(372, 210)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = locked
		b.add_theme_stylebox_override("normal", UI.frame(Color(0.08, 0.06, 0.11, 0.94), Color(col, 0.6)))
		b.add_theme_stylebox_override("hover", UI.frame(Color(0.12, 0.09, 0.16, 0.96), col, 3))
		b.add_theme_stylebox_override("pressed", UI.frame(Color(0.16, 0.12, 0.2), Color(1, 1, 1), 3))
		b.add_theme_stylebox_override("disabled", UI.frame(Color(0.05, 0.04, 0.07, 0.9), Color(0.2, 0.18, 0.24)))
		row.add_child(b)
		var v := VBoxContainer.new()
		v.position = Vector2(18, 16)
		v.size = Vector2(336, 180)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 10)
		b.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(Icon.make(c["icon"] if not locked else "lock", 26, col if not locked else Color(1, 1, 1, 0.3)))
		head.add_child(UI.label(Loc.t(c["name"]), 21, col.lightened(0.2) if not locked else Color(1, 1, 1, 0.35)))
		v.add_child(head)
		var d := UI.label(Loc.t(c["desc"]), 15, Color(1, 1, 1, 0.75 if not locked else 0.3))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 336
		v.add_child(d)
		if c.get("book", false):
			v.add_child(UI.label(Loc.t("Book of the Fallen: %d/%d pages") % [have, total], 13,
				Color(0.6, 1.0, 0.8) if not locked else Color(1, 0.6, 0.45, 0.8)))
		var id: String = c["id"]
		b.pressed.connect(func():
			Sfx.play("click")
			Meta.first_time(id)
			Meta.play_story(id, "res://scenes/main_menu.tscn")
		)
		if locked:
			tip.bind(b, func(): return Loc.t("Raise the dead instead of devouring them, and collect every page of the Book of the Fallen."))


func _process(_d: float) -> void:
	heart.queue_redraw()
