extends Control
## Title screen: the menu on the left, the dungeon's beating heart on the right.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const Icons = preload("res://scripts/ui/icons.gd")
const Icon = preload("res://scripts/ui/icon.gd")

var heart_view: Control
var veins: Array = []


func _ready() -> void:
	Music.play("menu")
	UI.background(self)

	# the heart, with veins crawling out across the right half of the screen
	heart_view = Control.new()
	heart_view.position = Vector2(560, 0)
	heart_view.size = Vector2(720, 720)
	heart_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart_view.draw.connect(_draw_heart)
	add_child(heart_view)
	_make_veins()

	var title := UI.title(Loc.t("FALLEN BELOW"), 60)
	title.position = Vector2(80, 90)
	add_child(title)
	var tagline := UI.label(Loc.t("The dungeon hungers. You are its will."), 18, Color(1, 1, 1, 0.65))
	tagline.position = Vector2(84, 186)
	add_child(tagline)

	var buttons := VBoxContainer.new()
	buttons.position = Vector2(80, 250)
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	var play := UI.primary(Loc.t("New Run"), Vector2(300, 54))
	play.pressed.connect(func(): Meta.start_run())
	buttons.add_child(play)
	for pair in [["The Lair", "res://scenes/lair.tscn"], ["Book of the Fallen", "res://scenes/book.tscn"], ["Grimoire", "res://scenes/grimoire.tscn"]]:
		var b := UI.button(Loc.t(pair[0]), Vector2(300, 46))
		var path: String = pair[1]
		b.pressed.connect(func(): get_tree().change_scene_to_file(path))
		buttons.add_child(b)
	var settings := UI.button(Loc.t("Settings"), Vector2(300, 46))
	settings.pressed.connect(func():
		var panel: Control = load("res://scripts/ui/settings_panel.gd").new()
		panel.closed.connect(func():
			if panel.language_changed:
				get_tree().reload_current_scene()
		)
		add_child(panel)
	)
	buttons.add_child(settings)
	var quit := UI.button(Loc.t("Quit"), Vector2(300, 46))
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)

	# what the dungeon has gathered so far
	var stats := HBoxContainer.new()
	stats.position = Vector2(80, 650)
	stats.add_theme_constant_override("separation", 18)
	add_child(stats)
	for r in ["bones", "blood", "gold"]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(Icon.make(r, 15))
		cell.add_child(UI.label(str(int(Meta.res[r])), 15, Icons.color_of(r)))
		stats.add_child(cell)
	var relics := HBoxContainer.new()
	relics.add_theme_constant_override("separation", 4)
	relics.add_child(Icon.make("relic", 14, Color(0.85, 0.6, 1.0)))
	relics.add_child(UI.label("%d/%d" % [Meta.relics.size(), D.RELICS.size()], 15, Color(0.85, 0.7, 1.0)))
	stats.add_child(relics)
	stats.add_child(UI.label(Loc.t("Runs %d  ·  Travelers taken %d") % [Meta.runs, Meta.total_kills], 14, Color(1, 1, 1, 0.45)))


func _make_veins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var c := Vector2(360, 340)
	for i in 14:
		var p := c
		var dir := Vector2.from_angle(TAU * i / 14.0 + rng.randf_range(-0.2, 0.2))
		var pts := PackedVector2Array([p])
		for k in 9:
			dir = dir.rotated(rng.randf_range(-0.45, 0.45))
			p += dir * rng.randf_range(26.0, 48.0)
			pts.append(p)
		veins.append(pts)


func _process(_d: float) -> void:
	heart_view.queue_redraw()


func _draw_heart() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var beat := Icons.heartbeat(t, 54.0)
	for v in veins:
		var pts: PackedVector2Array = v
		for j in pts.size() - 1:
			var f: float = float(j) / pts.size()
			var a: float = (0.55 - f * 0.5) * (0.6 + 0.4 * beat)
			heart_view.draw_line(pts[j], pts[j + 1], Color(0.6, 0.05, 0.12, a), (5.0 - f * 4.0))
	Icons.heart(heart_view, Vector2(360, 340), 6.0, t, 54.0, 0.4)
