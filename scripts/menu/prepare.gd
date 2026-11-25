extends Control
## Before the descent: choose which memories (cards) and relics to bring.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")

var deck_title: Label
var deck_box: GridContainer
var relic_title: Label
var relic_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.background(self)

	var title := UI.label("PREPARE THE DESCENT", 36, Color(0.75, 0.55, 1.0))
	title.position = Vector2(40, 24)
	add_child(title)
	var sub := UI.label("Choose the memories you will rebuild from, and the relics you carry. More slots and cards come from the Lair.", 14, Color(1, 1, 1, 0.6))
	sub.position = Vector2(40, 74)
	add_child(sub)

	# deck column
	deck_title = UI.label("", 18, Color(1, 0.9, 0.6))
	deck_title.position = Vector2(40, 110)
	add_child(deck_title)
	deck_box = GridContainer.new()
	deck_box.columns = 3
	deck_box.position = Vector2(40, 142)
	deck_box.add_theme_constant_override("h_separation", 8)
	deck_box.add_theme_constant_override("v_separation", 8)
	add_child(deck_box)

	# relic column
	relic_title = UI.label("", 18, Color(0.8, 0.7, 1.0))
	relic_title.position = Vector2(640, 110)
	add_child(relic_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(640, 142)
	scroll.size = Vector2(600, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	relic_box = VBoxContainer.new()
	relic_box.add_theme_constant_override("separation", 6)
	relic_box.custom_minimum_size = Vector2(580, 0)
	scroll.add_child(relic_box)

	var row := HBoxContainer.new()
	row.position = Vector2(40, 640)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var go := UI.button("DESCEND", Vector2(260, 52))
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/run.tscn"))
	row.add_child(go)
	var lair := UI.button("The Lair", Vector2(200, 52))
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	row.add_child(lair)
	var menu := UI.button("Main menu", Vector2(200, 52))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)

	_rebuild()


func _rebuild() -> void:
	deck_title.text = "Deck: %d/%d card types" % [Meta.deck.size(), Meta.deck_slots()]
	for c in deck_box.get_children():
		c.queue_free()
	for id in Meta.unlocked_cards():
		var def: Dictionary = D.CARDS[id]
		var on: bool = Meta.deck.has(id)
		var btn := Button.new()
		btn.text = "%s\n\n%s" % [def["name"], def["desc"]]
		btn.custom_minimum_size = Vector2(180, 120)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		var base: Color = def["color"]
		var col := base.darkened(0.45) if on else Color(0.1, 0.09, 0.12)
		var border := Color(1, 1, 1) if on else Color(0.3, 0.28, 0.35)
		btn.add_theme_stylebox_override("normal", UI.box(col, border))
		btn.add_theme_stylebox_override("hover", UI.box(col.lightened(0.12), border))
		btn.add_theme_stylebox_override("pressed", UI.box(col.lightened(0.2), border))
		if not on:
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		var cid: String = id
		btn.pressed.connect(func():
			Meta.toggle_card(cid)
			_rebuild()
		)
		deck_box.add_child(btn)

	relic_title.text = "Relics: %d/%d equipped   (%d found of %d)" % [
		Meta.loadout.size(), Meta.relic_slots(), Meta.relics.size(), D.RELICS.size()]
	for c in relic_box.get_children():
		c.queue_free()
	if Meta.relics.is_empty():
		var hint := UI.label("No relics yet. Veterans sometimes carry one, champions always do,\nand a dungeon sealed at the end of a week may give one up.", 14, Color(1, 1, 1, 0.5))
		relic_box.add_child(hint)
	for id in Meta.relics:
		var def: Dictionary = D.RELICS[id]
		var on: bool = Meta.loadout.has(id)
		var btn := Button.new()
		btn.text = "%s  —  %s" % [def["name"], def["desc"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(570, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		var col := Color(0.22, 0.12, 0.3) if on else Color(0.1, 0.08, 0.13)
		var border := Color(0.85, 0.7, 1.0) if on else Color(0.3, 0.25, 0.38)
		btn.add_theme_stylebox_override("normal", UI.box(col, border))
		btn.add_theme_stylebox_override("hover", UI.box(col.lightened(0.1), border))
		btn.add_theme_stylebox_override("pressed", UI.box(col.lightened(0.2), border))
		var rid: String = id
		btn.pressed.connect(func():
			Meta.toggle_relic(rid)
			_rebuild()
		)
		relic_box.add_child(btn)
