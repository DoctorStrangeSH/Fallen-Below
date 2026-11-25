extends Control
## The Book of the Fallen: pages whispered by the travelers you raised.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.background(self)

	var title := UI.label("THE BOOK OF THE FALLEN", 34, Color(0.75, 0.55, 1.0))
	title.position = Vector2(40, 20)
	add_child(title)
	var sub := UI.label("Pages %d/%d. Raise the dead instead of devouring them, and they will tell you what they knew." % [
		Meta.fragment_count(), Meta.fragment_total()], 14, Color(1, 1, 1, 0.6))
	sub.position = Vector2(40, 66)
	add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 100)
	scroll.size = Vector2(1200, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)

	for kind in D.FRAGMENTS:
		var pages: Array = D.FRAGMENTS[kind]
		var have := int(Meta.fragments.get(kind, 0))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.box(Color(0.09, 0.06, 0.12), Color(0.35, 0.25, 0.45)))
		panel.custom_minimum_size = Vector2(585, 0)
		grid.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		panel.add_child(v)
		var kind_name: String = D.HERO_CLASSES[kind]["name"]
		v.add_child(UI.label("%ss  (%d/%d)" % [kind_name, have, pages.size()], 17, Color(1, 0.85, 0.55)))
		for i in pages.size():
			var text := "\"%s\"" % pages[i] if i < have else "???"
			var l := UI.label(text, 13, Color(0.92, 0.88, 1.0) if i < have else Color(1, 1, 1, 0.3))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(560, 0)
			v.add_child(l)
		if have == 0 and D.LURES.values().any(func(lu): return lu["traveler"] == kind and lu.has("building")):
			v.add_child(UI.label("Lure them first: build their shrine in the Lair.", 12, Color(1, 0.6, 0.4, 0.7)))

	var row := HBoxContainer.new()
	row.position = Vector2(40, 640)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var lair := UI.button("The Lair")
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	row.add_child(lair)
	var menu := UI.button("Main menu")
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)
