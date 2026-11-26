extends Control
## The Book of the Fallen: pages whispered by the travelers you raised.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")


func _ready() -> void:
	Music.play("menu")
	UI.background(self)

	var title := UI.title(Loc.t("THE BOOK OF THE FALLEN"), 32)
	title.position = Vector2(40, 16)
	add_child(title)
	var sub := UI.label(Loc.t("Pages %d/%d. Raise the dead instead of devouring them, and they will tell you what they knew.") % [
		Meta.fragment_count(), Meta.fragment_total()], 14, Color(1, 1, 1, 0.6))
	sub.position = Vector2(40, 74)
	add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 104)
	scroll.size = Vector2(1200, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	for kind in D.FRAGMENTS:
		var pages: Array = D.FRAGMENTS[kind]
		var have := int(Meta.fragments.get(kind, 0))
		var cls: Dictionary = D.HERO_CLASSES[kind]
		var col: Color = cls["color"]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.frame(Color(0.08, 0.06, 0.11, 0.92), Color(col, 0.45) if have > 0 else Color(0.22, 0.18, 0.28), 2, 8, 14))
		panel.custom_minimum_size = Vector2(585, 0)
		grid.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		panel.add_child(v)

		# header: a coloured mark, the kind's name, and one diamond per page
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		v.add_child(head)
		head.add_child(Icon.make("skull", 16, col if have > 0 else Color(1, 1, 1, 0.25)))
		var name := UI.label(Loc.t(cls["name"]), 17, col.lightened(0.25) if have > 0 else Color(1, 1, 1, 0.4))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		for i in pages.size():
			head.add_child(Icon.make("relic", 11, Color(1, 0.8, 0.45) if i < have else Color(1, 1, 1, 0.15)))

		for i in pages.size():
			if i < have:
				var l := UI.label(Loc.t("\"%s\"") % Loc.t(pages[i]), 14, Color(0.92, 0.88, 1.0))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(555, 0)
				v.add_child(l)
			else:
				v.add_child(UI.label("· · ·", 14, Color(1, 1, 1, 0.2)))
		if have == 0 and int(cls.get("act", 1)) > 1:
			v.add_child(UI.label(Loc.t("They only come down in %s.") % Loc.t(D.ACTS[int(cls["act"])]["name"]), 12, Color(1, 0.6, 0.4, 0.7)))
		elif have == 0 and D.LURES.values().any(func(lu): return lu["traveler"] == kind and lu.has("building")):
			v.add_child(UI.label(Loc.t("Lure them first: build their shrine in the Lair."), 12, Color(1, 0.6, 0.4, 0.7)))

	var row := HBoxContainer.new()
	row.position = Vector2(40, 646)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var lair := UI.button(Loc.t("The Lair"), Vector2(200, 46))
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	row.add_child(lair)
	var menu := UI.button(Loc.t("Main menu"), Vector2(200, 46))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)
