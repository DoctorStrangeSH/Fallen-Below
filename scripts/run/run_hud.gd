extends CanvasLayer
## Run HUD in the Loop Hero layout: map on the left, info panel on the right,
## hand of cards at the bottom, modal choices centred over the map.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const LootSystem = preload("res://scripts/systems/loot_system.gd")

const MAP_CENTER := Vector2(16 + 19 * 48 / 2.0, 16 + 11 * 48 / 2.0)

var run  # run.gd

# right panel
var act_label: Label
var day_label: Label
var day_bar: ProgressBar
var heart_label: Label
var heart_bar: ProgressBar
var attention_bar: ProgressBar
var res_label: Label
var relic_label: Label
var pause_btn: Button
var speed_btn: Button
var heal_btn: Button
var seal_btn: Button
var trophy_title: Label
var trophy_box: VBoxContainer
var log_label: Label

# bottom & overlays
var hand_box: HBoxContainer
var soul_panel: PanelContainer
var soul_label: Label
var raise_btn: Button
var end_panel: PanelContainer
var end_label: Label
var end_buttons: VBoxContainer
var tooltip: PanelContainer
var tooltip_label: Label
var banner: Label


func _ready() -> void:
	_build_panel()
	hand_box = HBoxContainer.new()
	hand_box.position = Vector2(16, D.HAND_Y)
	hand_box.add_theme_constant_override("separation", 6)
	add_child(hand_box)
	_build_soul_panel()
	_build_end_panel()
	_build_overlays()

	var s = run.state
	s.log_added.connect(_on_log)
	s.hand_changed.connect(_on_hand_changed)
	s.souls_changed.connect(show_souls)
	s.inventory_changed.connect(rebuild_trophies)
	s.combo_found.connect(show_banner)
	act_label.text = D.ACTS[s.act]["name"]
	_on_hand_changed()
	rebuild_trophies()
	_on_log()
	refresh()


# ============================================================ build

func _bar(max_value: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := UI.box(Color(0.12, 0.1, 0.15), Color(0, 0, 0, 0), 3)
	bg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", bg)
	var fill := UI.box(color, Color(0, 0, 0, 0), 3)
	fill.set_content_margin_all(0)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(D.PANEL_X, 8)
	panel.custom_minimum_size = Vector2(1272 - D.PANEL_X, 704)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.06, 0.11), Color(0.3, 0.22, 0.4)))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	act_label = UI.label("", 17, Color(0.75, 0.55, 1.0))
	v.add_child(act_label)

	day_label = UI.label("", 14)
	v.add_child(day_label)
	day_bar = _bar(D.DAY_LENGTH, Color(0.85, 0.75, 0.4))
	v.add_child(day_bar)

	heart_label = UI.label("", 14)
	v.add_child(heart_label)
	heart_bar = _bar(100, Color(0.85, 0.15, 0.25))
	v.add_child(heart_bar)

	var att := UI.label("Order's attention (champion at 100%)", 13, Color(1, 0.9, 0.6))
	v.add_child(att)
	attention_bar = _bar(D.BOSS_THREAT, Color(1.0, 0.85, 0.5))
	v.add_child(attention_bar)

	res_label = UI.label("", 13, Color(1, 1, 1, 0.85))
	v.add_child(res_label)
	relic_label = UI.label("", 12, Color(0.8, 0.7, 1.0))
	relic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(relic_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	pause_btn = UI.button("Pause", Vector2(150, 30))
	pause_btn.pressed.connect(func(): run.toggle_pause())
	grid.add_child(pause_btn)
	speed_btn = UI.button("x1", Vector2(150, 30))
	speed_btn.pressed.connect(func(): run.cycle_speed())
	grid.add_child(speed_btn)
	heal_btn = UI.button("Heal Heart (%d ess)" % D.RESTORE_COST, Vector2(150, 30))
	heal_btn.pressed.connect(func(): run.heal_heart())
	grid.add_child(heal_btn)
	seal_btn = UI.button("Seal", Vector2(150, 30))
	seal_btn.pressed.connect(func(): run.seal())
	grid.add_child(seal_btn)

	trophy_title = UI.label("", 12, Color(1, 0.85, 0.5))
	trophy_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trophy_title.custom_minimum_size = Vector2(300, 0)
	v.add_child(trophy_title)
	trophy_box = VBoxContainer.new()
	trophy_box.add_theme_constant_override("separation", 2)
	trophy_box.custom_minimum_size = Vector2(0, 8 * 22)
	v.add_child(trophy_box)

	log_label = UI.label("", 12, Color(1, 1, 1, 0.8))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.clip_text = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(log_label)


func _modal(width: float, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.04, 0.11, 0.97), border))
	p.custom_minimum_size = Vector2(width, 0)
	p.position = Vector2(MAP_CENTER.x - width / 2.0, 120)
	p.visible = false
	add_child(p)
	return p


func _build_soul_panel() -> void:
	soul_panel = _modal(480, Color(0.6, 0.4, 0.9))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	soul_panel.add_child(v)
	soul_label = UI.label("", 16)
	soul_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	soul_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(soul_label)
	raise_btn = UI.button("Raise")
	raise_btn.pressed.connect(func(): run.souls.resolve("raise"))
	v.add_child(raise_btn)
	var absorb := UI.button("Absorb  (+5 essence)")
	absorb.pressed.connect(func(): run.souls.resolve("absorb"))
	v.add_child(absorb)
	var inter := UI.button("Interrogate  (+2 cards, reveal next party)")
	inter.pressed.connect(func(): run.souls.resolve("interrogate"))
	v.add_child(inter)


func _build_end_panel() -> void:
	end_panel = _modal(440, Color(0.9, 0.8, 0.4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	end_panel.add_child(v)
	end_label = UI.label("", 20)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(end_label)
	end_buttons = VBoxContainer.new()
	end_buttons.add_theme_constant_override("separation", 8)
	v.add_child(end_buttons)


func _build_overlays() -> void:
	tooltip = PanelContainer.new()
	tooltip.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.03, 0.06, 0.93), Color(0.4, 0.3, 0.5), 4))
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	add_child(tooltip)
	tooltip_label = UI.label("", 12)
	tooltip.add_child(tooltip_label)

	banner = UI.label("", 30, Color(1, 0.8, 0.3))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(D.MAP_OFFSET.x, 60)
	banner.size = Vector2(D.GRID_W * D.CELL, 50)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	add_child(banner)


# ============================================================ cards

func _card_button(id: String, highlighted: bool, min_size: Vector2) -> Button:
	var def: Dictionary = D.CARDS[id]
	var btn := Button.new()
	btn.text = "%s\n\n%s" % [def["name"], def["desc"]]
	btn.custom_minimum_size = min_size
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	var base: Color = def["color"]
	var col := base.darkened(0.45)
	var border := Color(1, 1, 1) if highlighted else col.lightened(0.3)
	btn.add_theme_stylebox_override("normal", UI.box(col, border))
	btn.add_theme_stylebox_override("hover", UI.box(col.lightened(0.15), Color(1, 1, 1, 0.8)))
	btn.add_theme_stylebox_override("pressed", UI.box(col.lightened(0.25), Color(1, 1, 1)))
	return btn


func _on_hand_changed() -> void:
	rebuild_hand()


func rebuild_hand() -> void:
	var s = run.state
	for c in hand_box.get_children():
		c.queue_free()
	for i in s.hand.size():
		var btn := _card_button(s.hand[i], i == s.selected, Vector2(126, 140))
		btn.pressed.connect(func(): run.cards.use_card(i))
		hand_box.add_child(btn)


# ============================================================ update

func refresh() -> void:
	var s = run.state
	day_label.text = "Day %d" % s.day
	day_bar.value = s.day_timer
	heart_label.text = "Heart %d/%d" % [s.heart_hp, s.heart_max]
	heart_bar.max_value = s.heart_max
	heart_bar.value = s.heart_hp
	attention_bar.value = s.threat
	var pct: float = s.seal_pct()
	res_label.text = "Essence %d    Undead %d/%d\nHarvest: %d Bones  %d Blood  %d Gold\nSeal now keeps %d%%" % [
		s.essence, s.undead_count(), s.jar_cap, s.pouch["bones"], s.pouch["blood"], s.pouch["gold"], int(pct * 100.0)]
	relic_label.text = _relic_text(s)
	heal_btn.disabled = s.essence < D.RESTORE_COST or s.heart_hp >= s.heart_max or s.game_over
	pause_btn.text = "Play" if s.paused else "Pause"
	speed_btn.text = "Speed x%d" % int(s.time_scale)
	seal_btn.text = "Seal %d%%" % int(pct * 100.0)
	seal_btn.disabled = s.game_over
	seal_btn.modulate = Color(1, 0.9, 0.4) if pct >= 1.0 else Color(1, 1, 1)
	_update_tooltip()


func show_souls() -> void:
	var h: Dictionary = run.souls.current()
	if h.is_empty():
		soul_panel.visible = false
		return
	var s = run.state
	soul_label.text = run.souls.describe(h)
	raise_btn.text = "Raise as %s  (undead %d/%d)" % [run.souls.dark_name(h), s.undead_count(), s.jar_cap]
	raise_btn.disabled = not run.souls.can_raise()
	soul_panel.visible = true


func _relic_text(s) -> String:
	var names: Array = []
	for r in s.relics:
		names.append(D.RELICS[r]["name"])
	var line := "Relics: %s" % (", ".join(names) if not names.is_empty() else "none")
	if not s.found_relics.is_empty():
		var found: Array = []
		for r in s.found_relics:
			found.append(D.RELICS[r]["name"])
		line += "\nFound (keep by surviving): %s" % ", ".join(found)
	return line


func show_end(outcome: String, payout: Dictionary, pct: float, kept: Array, lost: Array) -> void:
	soul_panel.visible = false
	tooltip.visible = false
	var s = run.state
	var head := ""
	match outcome:
		"victory":
			head = "ACT CLEARED\n%s has fallen." % D.ACTS[s.act]["boss"]
		"sealed":
			head = "DUNGEON SEALED\nYou keep %d%% of the spoils." % int(pct * 100.0)
		_:
			head = "THE HEART FALLS\nOnly %d%% of the harvest remains." % int(pct * 100.0)
	var gains: Array = []
	for k in payout:
		gains.append("+%d %s" % [int(payout[k]), D.RESOURCES[k]["name"]])
	var text := "%s\n\nDays: %d   Heroes slain: %d\n%s" % [head, s.day, s.kills, "   ".join(gains)]
	for r in kept:
		text += "\nNew relic: %s" % D.RELICS[r]["name"]
	for r in lost:
		text += "\nLost in the dark: %s" % D.RELICS[r]["name"]
	end_label.text = text
	for c in end_buttons.get_children():
		c.queue_free()
	if outcome == "victory":
		var cont := UI.button("Continue")
		cont.pressed.connect(func(): run.continue_after_victory())
		end_buttons.add_child(cont)
	var lair := UI.button("Return to the Lair")
	lair.pressed.connect(func(): run.go_to("res://scenes/lair.tscn"))
	end_buttons.add_child(lair)
	var again := UI.button("New run")
	again.pressed.connect(func(): run.go_to("res://scenes/prepare.tscn"))
	end_buttons.add_child(again)
	end_panel.visible = true


func rebuild_trophies() -> void:
	var s = run.state
	trophy_title.text = "Trophies %d/%d   (click, then your undead · RMB: melt)" % [s.inventory.size(), D.INVENTORY_MAX]
	for c in trophy_box.get_children():
		c.queue_free()
	for i in s.inventory.size():
		var item: Dictionary = s.inventory[i]
		var rar: Dictionary = D.RARITIES[item["rarity"]]
		var col: Color = rar["color"]
		var btn := Button.new()
		btn.text = "%s  (%s)" % [item["name"], LootSystem.describe(item)]
		btn.tooltip_text = btn.text
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(300, 20)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", col.lightened(0.3))
		var border := Color(1, 1, 1) if i == s.selected_item else Color(col, 0.4)
		btn.add_theme_stylebox_override("normal", UI.box(Color(0.07, 0.05, 0.1, 0.9), border, 3))
		btn.add_theme_stylebox_override("hover", UI.box(Color(0.12, 0.09, 0.16, 0.95), border, 3))
		btn.pressed.connect(func(): run.loot.select_item(i))
		btn.gui_input.connect(func(ev: InputEvent):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				run.loot.melt(i)
		)
		trophy_box.add_child(btn)


func show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(banner, "modulate:a", 0.0, 1.2)


func _on_log() -> void:
	log_label.text = "\n".join(run.state.log_lines)


func _update_tooltip() -> void:
	var s = run.state
	if s.game_over or soul_panel.visible:
		tooltip.visible = false
		return
	var cell: Vector2i = run.view.mouse_cell()
	var lines: Array = []
	if s.path_lookup.has(cell):
		var t: int = s.path_lookup[cell]
		var card: String = s.card_at(t)
		if t == 0:
			lines.append("Gate: heroes enter here. Each lap they steal from your Heart.")
		elif card != "":
			lines.append("%s: %s" % [D.CARDS[card]["name"], D.CARDS[card]["desc"]])
		elif t >= s.loop_size:
			lines.append("Side passage")
		if s.forks.has(t):
			lines.append("Fork: each hero picks a branch by personality.")
		for u in s.alive_units(t):
			var line := "%s  %d/%d HP  %.1f dmg" % [u["name"], int(u["hp"]), int(u["max_hp"]), u["dmg"]]
			var gear: Dictionary = u.get("gear", {})
			for slot in gear:
				line += "\n   - %s" % gear[slot]["name"]
			lines.append(line)
		for h in s.heroes:
			if h["cur"] == t and not h["gone"] and h["delay"] <= 0.0:
				var trait_id: String = h["trait"]
				var tr_txt := "" if trait_id == "" else "  [%s]" % D.TRAITS[trait_id]["name"]
				lines.append("%s (%s)%s  %d/%d HP" % [s.hero_name(h), D.HERO_CLASSES[h["cls"]]["name"], tr_txt, int(h["hp"]), int(h["max_hp"])])
	elif s.scenery.has(cell):
		var id: String = s.scenery[cell]
		lines.append("%s: %s" % [D.CARDS[id]["name"], D.CARDS[id]["desc"]])
	elif cell == s.heart_cell:
		lines.append("Your Heart. If it falls, the run is over.")
	if lines.is_empty():
		tooltip.visible = false
		return
	tooltip_label.text = "\n".join(lines)
	tooltip.visible = true
	tooltip.reset_size()
	var mp: Vector2 = get_viewport().get_mouse_position() + Vector2(16, 16)
	var vp := get_viewport().get_visible_rect().size
	mp.x = minf(mp.x, vp.x - tooltip.size.x - 4)
	mp.y = minf(mp.y, vp.y - tooltip.size.y - 4)
	tooltip.position = mp
