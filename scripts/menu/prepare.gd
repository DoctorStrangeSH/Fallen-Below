extends Control
## Before the descent: choose the act, the Warden, the memories (cards) and the relics.
## Each choice is a picture with a short name; the full rules are in the hover tip.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Icons = preload("res://scripts/ui/icons.gd")

var tip: CanvasLayer
var act_box: HBoxContainer
var act_name: Label
var warden_box: HBoxContainer
var deck_title: Label
var deck_box: GridContainer
var relic_title: Label
var relic_box: GridContainer


func _ready() -> void:
	Music.play("menu")
	UI.background(self)
	tip = UI.hover_tip(self)

	var title := UI.title(Loc.t("PREPARE THE DESCENT"), 32)
	title.position = Vector2(40, 18)
	add_child(title)

	act_box = HBoxContainer.new()
	act_box.position = Vector2(740, 26)
	act_box.add_theme_constant_override("separation", 6)
	add_child(act_box)

	act_name = UI.label("", 13, Color(0.85, 0.75, 1.0))
	act_name.position = Vector2(740, 68)
	add_child(act_name)
	var wh := UI.header(Loc.t("Warden"))
	wh.position = Vector2(40, 82)
	add_child(wh)
	warden_box = HBoxContainer.new()
	warden_box.position = Vector2(40, 100)
	warden_box.add_theme_constant_override("separation", 8)
	add_child(warden_box)

	deck_title = UI.header("")
	deck_title.position = Vector2(40, 282)
	add_child(deck_title)
	deck_box = GridContainer.new()
	deck_box.columns = 5
	deck_box.position = Vector2(40, 300)
	deck_box.add_theme_constant_override("h_separation", 6)
	deck_box.add_theme_constant_override("v_separation", 6)
	add_child(deck_box)

	relic_title = UI.header("")
	relic_title.position = Vector2(620, 282)
	add_child(relic_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(620, 300)
	scroll.size = Vector2(624, 318)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	relic_box = GridContainer.new()
	relic_box.columns = 2
	relic_box.add_theme_constant_override("h_separation", 6)
	relic_box.add_theme_constant_override("v_separation", 6)
	scroll.add_child(relic_box)

	var row := HBoxContainer.new()
	row.position = Vector2(40, 640)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var go := UI.primary(Loc.t("DESCEND"), Vector2(280, 52))
	go.pressed.connect(_descend)
	row.add_child(go)
	var lair := UI.button(Loc.t("The Lair"), Vector2(180, 52))
	lair.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lair.tscn"))
	row.add_child(lair)
	var menu := UI.button(Loc.t("Main menu"), Vector2(180, 52))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)

	_rebuild()


## The first descent into a new act plays its introduction.
func _descend() -> void:
	var act: Dictionary = D.ACTS[Meta.selected_act]
	var intro: String = act.get("intro_story", "")
	if intro != "" and Meta.first_time(intro):
		Meta.play_story(intro, "res://scenes/run.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/run.tscn")


func _style(b: Button, bg: Color, border: Color, width: int = 2) -> void:
	b.add_theme_stylebox_override("normal", UI.frame(bg, border, width))
	b.add_theme_stylebox_override("hover", UI.frame(bg.lightened(0.1), border.lightened(0.3), width))
	b.add_theme_stylebox_override("pressed", UI.frame(bg.lightened(0.18), Color(1, 1, 1), width))
	b.add_theme_stylebox_override("disabled", UI.frame(Color(0.05, 0.04, 0.07, 0.9), Color(0.18, 0.16, 0.22), width))


func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


func _rebuild() -> void:
	_build_acts()
	_build_wardens()
	_build_deck()
	_build_relics()


func _build_acts() -> void:
	_clear(act_box)
	var cur: Dictionary = D.ACTS[Meta.selected_act]
	act_name.text = "%s  ·  %s" % [Loc.t(cur["name"]), Loc.t(cur["boss"])]
	for a in D.ACTS:
		var act_id: int = a
		var open: bool = act_id <= Meta.max_act()
		var on: bool = act_id == Meta.selected_act
		const ROMAN := ["", "I", "II", "III", "IV"]
		var b := UI.button(Loc.t("Act %s") % ROMAN[act_id], Vector2(0, 38))
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size.x = 120
		b.disabled = not open
		if on:
			_style(b, Color(0.25, 0.14, 0.34), UI.ACCENT)
		b.pressed.connect(func():
			Meta.set_act(act_id)
			_rebuild()
		)
		var act_def: Dictionary = D.ACTS[a]
		tip.bind(b, func():
			if not open:
				return Loc.t("Locked: clear the previous act")
			return Loc.t("%s\nChampion: %s, %s") % [Loc.t(act_def["name"]), Loc.t(act_def["boss"]), Loc.t(act_def["boss_title"])])
		act_box.add_child(b)


func _build_wardens() -> void:
	_clear(warden_box)
	for id in D.WARDENS:
		var def: Dictionary = D.WARDENS[id]
		var unlocked: bool = Meta.warden_unlocked(id)
		var on: bool = Meta.warden_id == id
		var col: Color = def["color"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(294, 168)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not unlocked
		_style(b, Color(0.09, 0.06, 0.12).lerp(col, 0.14) if on else Color(0.08, 0.06, 0.11, 0.92), col if on else Color(0.28, 0.22, 0.36), 3 if on else 2)
		var wid: String = id
		b.pressed.connect(func():
			Sfx.play("click")
			Meta.set_warden(wid)
			_rebuild()
		)
		warden_box.add_child(b)

		var portrait := Control.new()
		portrait.position = Vector2(8, 20)
		portrait.size = Vector2(96, 110)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.25)
		portrait.draw.connect(func(): Icons.warden_figure(portrait, Vector2(48, 50), col, 1.7, Time.get_ticks_msec() / 1000.0))
		b.add_child(portrait)

		var info := VBoxContainer.new()
		info.position = Vector2(106, 12)
		info.size = Vector2(178, 146)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_theme_constant_override("separation", 4)
		b.add_child(info)
		var name := UI.label(Loc.t(def["name"]), 17, col.lightened(0.2) if unlocked else Color(1, 1, 1, 0.4))
		info.add_child(name)
		if not unlocked:
			var lock_row := HBoxContainer.new()
			lock_row.add_child(Icon.make("lock", 13, Color(1, 1, 1, 0.4)))
			var req := UI.label(Meta.unlock_text(id), 12, Color(1, 0.7, 0.5, 0.7))
			req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			req.custom_minimum_size.x = 150
			lock_row.add_child(req)
			info.add_child(lock_row)
			continue
		var style := UI.label(Loc.t(def["style"]), 11, Color(1, 1, 1, 0.6))
		style.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		style.custom_minimum_size = Vector2(178, 0)
		info.add_child(style)
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 3)
		for pair in [["hp", "%d" % int(def["hp"])], ["dmg", "%.1f" % float(def["dmg"])], ["def", "%.1f" % float(def["def"])]]:
			stats.add_child(Icon.make(pair[0], 13))
			var l := UI.label(pair[1], 13)
			l.custom_minimum_size.x = 30
			stats.add_child(l)
		info.add_child(stats)
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation", 2)
		for sl in def["slots"]:
			slots.add_child(Icon.make(str(sl), 15, Color(1, 1, 1, 0.55)))
		info.add_child(slots)
		var q := UI.label(Loc.t("[Q] %s") % Loc.t(def["active"]), 12, Color(0.85, 0.75, 1.0))
		info.add_child(q)
		tip.bind(b, func():
			var slot_names: Array = def["slots"].map(func(x): return Loc.t(str(x).capitalize()))
			return Loc.t("%s, %s\n\nPassive, %s: %s\n\n[Q] %s: %s\n\nSlots: %s") % [Loc.t(def["name"]), Loc.t(def["title"]),
				Loc.t(def["passive"]), Loc.t(def["passive_desc"]), Loc.t(def["active"]), Loc.t(def["active_desc"]), ", ".join(slot_names)])


func _build_deck() -> void:
	deck_title.text = (Loc.t("Deck: %d/%d card types") % [Meta.deck.size(), Meta.deck_slots()]).to_upper()
	_clear(deck_box)
	for id in Meta.unlocked_cards():
		var def: Dictionary = D.CARDS[id]
		var on: bool = Meta.deck.has(id)
		var base: Color = def["color"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(108, 102)
		b.focus_mode = Control.FOCUS_NONE
		_style(b, base.darkened(0.55) if on else Color(0.07, 0.06, 0.09, 0.9), Color(1, 1, 1, 0.9) if on else Color(0.25, 0.22, 0.3))
		var glyph := Icon.make("card:" + id, 40)
		glyph.position = Vector2(14, 6)
		glyph.size = Vector2(80, 52)
		glyph.modulate = Color(1, 1, 1, 1.0 if on else 0.35)
		b.add_child(glyph)
		var name := UI.label(Loc.t(def["name"]), 12, Color(1, 1, 1, 0.95 if on else 0.45))
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.position = Vector2(4, 60)
		name.size = Vector2(100, 38)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name)
		var cid: String = id
		b.pressed.connect(func():
			Sfx.play("click")
			Meta.toggle_card(cid)
			_rebuild()
		)
		tip.bind(b, func(): return "%s\n%s\n\n%s" % [Loc.t(def["name"]), Loc.t(def["desc"]),
			Loc.t("In the deck: click to remove.") if Meta.deck.has(cid) else Loc.t("Click to add to the deck.")])
		deck_box.add_child(b)


func _build_relics() -> void:
	relic_title.text = (Loc.t("Relics: %d/%d equipped   (%d found of %d)") % [
		Meta.loadout.size(), Meta.relic_slots(), Meta.relics.size(), D.RELICS.size()]).to_upper()
	_clear(relic_box)
	if Meta.relics.is_empty():
		var hint := UI.label(Loc.t("No relics yet. Veterans sometimes carry one, champions always do,\nand a dungeon sealed at the end of a week may give one up."), 14, Color(1, 1, 1, 0.5))
		relic_box.add_child(hint)
	for id in Meta.relics:
		var def: Dictionary = D.RELICS[id]
		var on: bool = Meta.loadout.has(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 36)
		b.focus_mode = Control.FOCUS_NONE
		b.text = Loc.t(def["name"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color(1, 0.95, 1.0) if on else Color(1, 1, 1, 0.6))
		_style(b, Color(0.22, 0.12, 0.3) if on else Color(0.08, 0.06, 0.11, 0.9), UI.ACCENT if on else Color(0.25, 0.2, 0.32))
		for st in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.content_margin_left = 34
		var ic := Icon.make("relic", 14, Color(0.9, 0.7, 1.0) if on else Color(0.6, 0.5, 0.7, 0.6))
		ic.position = Vector2(8, 7)
		ic.size = Vector2(20, 22)
		b.add_child(ic)
		var rid: String = id
		b.pressed.connect(func():
			Sfx.play("click")
			Meta.toggle_relic(rid)
			_rebuild()
		)
		tip.bind(b, func(): return "%s\n%s\n\n%s" % [Loc.t(def["name"]), Loc.t(def["desc"]),
			Loc.t("Equipped: click to take it off.") if Meta.loadout.has(rid) else Loc.t("Click to take it into the dungeon.")])
		relic_box.add_child(b)
