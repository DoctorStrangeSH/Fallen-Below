extends Control
## The Grimoire: secret card combos you have discovered.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")

## Which card each combo turns into, for its picture.
const RESULT := {"queen": "queen", "grinder": "grinder", "catacombs": "catacomb", "necropolis": "necropolis", "spire": "spire", "mimic": "mimic"}


func _ready() -> void:
	Music.play("menu")
	UI.background(self)

	var title := UI.title(Loc.t("GRIMOIRE"), 40, true)
	title.position = Vector2(340, 40)
	title.size = Vector2(600, 0)
	add_child(title)
	var found: int = Meta.discovered.size()
	var sub := UI.label(Loc.t("Secret combos discovered: %d/%d") % [found, D.COMBOS.size()], 16, Color(1, 1, 1, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(340, 112)
	sub.size = Vector2(600, 24)
	add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(110, 160)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)
	for id in D.COMBOS:
		var def: Dictionary = D.COMBOS[id]
		var known: bool = Meta.discovered.has(id)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.frame(Color(0.08, 0.06, 0.11, 0.92), Color(0.8, 0.6, 0.3) if known else Color(0.22, 0.18, 0.28), 2, 8, 12))
		panel.custom_minimum_size = Vector2(522, 118)
		grid.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var pic := Icon.make("card:" + str(RESULT[id]), 40) if known else Icon.make("lock", 26, Color(1, 1, 1, 0.25))
		pic.custom_minimum_size = Vector2(70, 70)
		pic.animated = known
		row.add_child(pic)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		if known:
			box.add_child(UI.label(Loc.t(def["name"]), 19, Color(1, 0.85, 0.5)))
			var d := UI.label(Loc.t(def["desc"]), 14, Color(1, 1, 1, 0.75))
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 400
			box.add_child(d)
		else:
			box.add_child(UI.label("???", 19, Color(1, 1, 1, 0.35)))
			var h := UI.label(Loc.t("Hint: %s") % Loc.t(def["hint"]), 14, Color(0.85, 0.75, 1.0, 0.6))
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h.custom_minimum_size.x = 400
			box.add_child(h)

	var nav := HBoxContainer.new()
	nav.position = Vector2(430, 640)
	nav.add_theme_constant_override("separation", 10)
	add_child(nav)
	var lair := UI.button(Loc.t("The Lair"), Vector2(200, 46))
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	nav.add_child(lair)
	var back := UI.button(Loc.t("Main menu"), Vector2(200, 46))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	nav.add_child(back)
