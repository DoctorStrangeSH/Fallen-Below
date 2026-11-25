extends Control
## Before the descent: choose which memories (cards) and relics to bring.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")

var warden_box: HBoxContainer
var deck_title: Label
var deck_box: GridContainer
var relic_title: Label
var relic_box: VBoxContainer


func _ready() -> void:
	Music.play("menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.background(self)

	var title := UI.label(Loc.t("PREPARE THE DESCENT"), 36, Color(0.75, 0.55, 1.0))
	title.position = Vector2(40, 24)
	add_child(title)
	var sub := UI.label(Loc.t("Choose your Warden, the memories you will rebuild from, and the relics you carry."), 14, Color(1, 1, 1, 0.6))
	sub.position = Vector2(40, 66)
	add_child(sub)

	warden_box = HBoxContainer.new()
	warden_box.position = Vector2(40, 92)
	warden_box.add_theme_constant_override("separation", 8)
	add_child(warden_box)

	# deck column
	deck_title = UI.label("", 18, Color(1, 0.9, 0.6))
	deck_title.position = Vector2(40, 250)
	add_child(deck_title)
	deck_box = GridContainer.new()
	deck_box.columns = 3
	deck_box.position = Vector2(40, 280)
	deck_box.add_theme_constant_override("h_separation", 8)
	deck_box.add_theme_constant_override("v_separation", 8)
	add_child(deck_box)

	# relic column
	relic_title = UI.label("", 18, Color(0.8, 0.7, 1.0))
	relic_title.position = Vector2(640, 250)
	add_child(relic_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(640, 280)
	scroll.size = Vector2(600, 340)
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
	var go := UI.button(Loc.t("DESCEND"), Vector2(260, 52))
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/run.tscn"))
	row.add_child(go)
	var lair := UI.button(Loc.t("The Lair"), Vector2(200, 52))
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	row.add_child(lair)
	var menu := UI.button(Loc.t("Main menu"), Vector2(200, 52))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)

	_rebuild()


func _rebuild() -> void:
	for c in warden_box.get_children():
		c.queue_free()
	for id in D.WARDENS:
		var def: Dictionary = D.WARDENS[id]
		var unlocked: bool = Meta.warden_unlocked(id)
		var on: bool = Meta.warden_id == id
		var btn := Button.new()
		if unlocked:
			btn.text = Loc.t("%s\n%s\n\n%s: %s\n[Q] %s") % [Loc.t(def["name"]), Loc.t(def["style"]), Loc.t(def["passive"]), Loc.t(def["passive_desc"]), Loc.t(def["active"])]
			btn.tooltip_text = Loc.t("%s: %s\nSlots: %s") % [Loc.t(def["active"]), Loc.t(def["active_desc"]), ", ".join(def["slots"].map(func(x): return Loc.t(str(x).capitalize())))]
		else:
			btn.text = Loc.t("%s\n\nLOCKED\n%s") % [Loc.t(def["name"]), Meta.unlock_text(id)]
			btn.disabled = true
		btn.custom_minimum_size = Vector2(294, 148)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 12)
		var col: Color = def["color"]
		var bg := col.darkened(0.75) if on else Color(0.08, 0.07, 0.1)
		var border := col if on else Color(0.3, 0.28, 0.35)
		btn.add_theme_stylebox_override("normal", UI.box(bg, border))
		btn.add_theme_stylebox_override("hover", UI.box(bg.lightened(0.1), col))
		btn.add_theme_stylebox_override("pressed", UI.box(bg.lightened(0.2), col))
		btn.add_theme_stylebox_override("disabled", UI.box(Color(0.05, 0.05, 0.06), Color(0.2, 0.2, 0.22)))
		var wid: String = id
		btn.pressed.connect(func():
			Meta.set_warden(wid)
			_rebuild()
		)
		warden_box.add_child(btn)

	deck_title.text = Loc.t("Deck: %d/%d card types") % [Meta.deck.size(), Meta.deck_slots()]
	for c in deck_box.get_children():
		c.queue_free()
	for id in Meta.unlocked_cards():
		var def: Dictionary = D.CARDS[id]
		var on: bool = Meta.deck.has(id)
		var btn := Button.new()
		btn.text = Loc.t("%s\n\n%s") % [Loc.t(def["name"]), Loc.t(def["desc"])]
		btn.custom_minimum_size = Vector2(180, 100)
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

	relic_title.text = Loc.t("Relics: %d/%d equipped   (%d found of %d)") % [
		Meta.loadout.size(), Meta.relic_slots(), Meta.relics.size(), D.RELICS.size()]
	for c in relic_box.get_children():
		c.queue_free()
	if Meta.relics.is_empty():
		var hint := UI.label(Loc.t("No relics yet. Veterans sometimes carry one, champions always do,\nand a dungeon sealed at the end of a week may give one up."), 14, Color(1, 1, 1, 0.5))
		relic_box.add_child(hint)
	for id in Meta.relics:
		var def: Dictionary = D.RELICS[id]
		var on: bool = Meta.loadout.has(id)
		var btn := Button.new()
		btn.text = Loc.t("%s  —  %s") % [Loc.t(def["name"]), Loc.t(def["desc"])]
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
