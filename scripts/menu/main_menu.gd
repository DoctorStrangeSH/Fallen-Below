extends Control
## Title screen.

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
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var title := UI.label(Loc.t("FALLEN BELOW"), 64, Color(0.75, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tagline := UI.label(Loc.t("Build the dungeon. Kill the heroes. Raise them as your army."), 18, Color(1, 1, 1, 0.7))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tagline)
	v.add_child(Control.new())  # spacer

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(buttons)
	var play := UI.button(Loc.t("New Run"), Vector2(260, 48))
	play.pressed.connect(func(): Meta.start_run())
	buttons.add_child(play)
	var lair := UI.button(Loc.t("The Lair"), Vector2(260, 48))
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	buttons.add_child(lair)
	var book := UI.button(Loc.t("Book of the Fallen"), Vector2(260, 48))
	book.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/book.tscn"))
	buttons.add_child(book)
	var grim := UI.button(Loc.t("Grimoire"), Vector2(260, 48))
	grim.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/grimoire.tscn"))
	buttons.add_child(grim)
	var music := UI.button("", Vector2(260, 48))
	music.text = Loc.t("Music: %d%%") % int(Meta.music_volume * 100.0)
	music.pressed.connect(func():
		var steps: Array = [0.0, 0.35, 0.7, 1.0]
		var i := steps.find(snappedf(Meta.music_volume, 0.05))
		Meta.music_volume = steps[(i + 1) % steps.size()] if i >= 0 else 0.7
		Meta.save_game()
		music.text = Loc.t("Music: %d%%") % int(Meta.music_volume * 100.0)
	)
	buttons.add_child(music)
	var lang := UI.button(Loc.t("Language: %s") % Loc.LANGUAGES[Loc.lang], Vector2(260, 48))
	lang.pressed.connect(func():
		Loc.next_language()
		get_tree().reload_current_scene()
	)
	buttons.add_child(lang)
	var quit := UI.button(Loc.t("Quit"), Vector2(260, 48))
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)

	v.add_child(Control.new())
	var stats := UI.label(Loc.t("Bones %d  ·  Blood %d  ·  Gold %d  ·  Relics %d/%d  ·  Runs %d  ·  Heroes slain %d") % [
		int(Meta.res["bones"]), int(Meta.res["blood"]), int(Meta.res["gold"]), Meta.relics.size(), D.RELICS.size(),
		Meta.runs, Meta.total_kills], 14, Color(1, 1, 1, 0.55))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
