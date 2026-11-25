extends Control
## Title screen.

const UI = preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.background(self)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var title := UI.label("FALLEN BELOW", 64, Color(0.75, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tagline := UI.label("Build the dungeon. Kill the heroes. Raise them as your army.", 18, Color(1, 1, 1, 0.7))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tagline)
	v.add_child(Control.new())  # spacer

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(buttons)
	var play := UI.button("New Run", Vector2(260, 48))
	play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/run.tscn"))
	buttons.add_child(play)
	var lair := UI.button("The Lair", Vector2(260, 48))
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	buttons.add_child(lair)
	var quit := UI.button("Quit", Vector2(260, 48))
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)

	v.add_child(Control.new())
	var stats := UI.label("Bones: %d    Runs: %d    Wins: %d    Best day: %d    Heroes slain: %d" % [
		Meta.bones, Meta.runs, Meta.wins, Meta.best_day, Meta.total_kills], 14, Color(1, 1, 1, 0.55))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
