extends Control
## The Grimoire: secret card combos you have discovered.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	Music.play("menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.background(self)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)

	var title := UI.label("GRIMOIRE", 44, Color(0.75, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var found: int = Meta.discovered.size()
	var sub := UI.label("Secret combos discovered: %d/%d" % [found, D.COMBOS.size()], 16, Color(1, 1, 1, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	for id in D.COMBOS:
		var def: Dictionary = D.COMBOS[id]
		var known: bool = Meta.discovered.has(id)
		var panel := PanelContainer.new()
		var border := Color(0.8, 0.6, 0.3) if known else Color(0.25, 0.2, 0.3)
		panel.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.07, 0.14), border))
		panel.custom_minimum_size = Vector2(640, 0)
		v.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		if known:
			box.add_child(UI.label(def["name"], 18, Color(1, 0.85, 0.5)))
			box.add_child(UI.label(def["desc"], 14, Color(1, 1, 1, 0.75)))
		else:
			box.add_child(UI.label("???", 18, Color(1, 1, 1, 0.4)))
			box.add_child(UI.label("Hint: %s" % def["hint"], 14, Color(1, 1, 1, 0.5)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var lair := UI.button("The Lair")
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	row.add_child(lair)
	var back := UI.button("Main menu")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(back)
