extends CanvasLayer
## Run HUD: map on the left, the Warden / dungeon panel on the right,
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
var warden_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var warden_stats: Label
var gear_label: Label
var attention_bar: ProgressBar
var lure_box: GridContainer
var stance_btn: Button
var harvest_label: Label
var pause_btn: Button
var speed_btn: Button
var sleep_btn: Button
var trophy_title: Label
var trophy_box: VBoxContainer
var log_label: Label

# bottom & overlays
var hand_box: HBoxContainer
var level_panel: PanelContainer
var level_box: HBoxContainer
var end_panel: PanelContainer
var end_label: Label
var end_buttons: VBoxContainer
var tooltip: PanelContainer
var tooltip_label: Label
var banner: Label
var narration: PanelContainer
var narration_label: Label
var narration_queue: Array = []
var narration_time := 0.0


func _ready() -> void:
	_build_panel()
	hand_box = HBoxContainer.new()
	hand_box.position = Vector2(16, D.HAND_Y)
	hand_box.add_theme_constant_override("separation", 6)
	add_child(hand_box)
	_build_level_panel()
	_build_end_panel()
	_build_overlays()

	var s = run.state
	s.log_added.connect(_on_log)
	s.hand_changed.connect(rebuild_hand)
	s.inventory_changed.connect(rebuild_trophies)
	s.combo_found.connect(show_banner)
	s.level_up.connect(show_level_up)
	s.narrate.connect(_on_narrate)
	act_label.text = D.ACTS[s.act]["name"]
	rebuild_hand()
	rebuild_trophies()
	rebuild_lures()
	_on_log()
	refresh()


# ============================================================ build

func _bar(max_value: float, color: Color, height: float = 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := UI.box(Color(0.12, 0.1, 0.15), Color(0, 0, 0, 0), 3)
	bg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", bg)
	var fill := UI.box(color, Color(0, 0, 0, 0), 3)
	fill.set_content_margin_all(0)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _small(text: String, size: int, color: Color = Color(1, 1, 1)) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	return l


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(D.PANEL_X, 8)
	panel.custom_minimum_size = Vector2(1272 - D.PANEL_X, 704)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.06, 0.11), Color(0.3, 0.22, 0.4)))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	act_label = UI.label("", 15, Color(0.75, 0.55, 1.0))
	v.add_child(act_label)
	day_label = UI.label("", 12)
	v.add_child(day_label)
	day_bar = _bar(D.DAY_LENGTH, Color(0.85, 0.75, 0.4), 8)
	v.add_child(day_bar)

	# the Warden
	warden_label = UI.label("", 15, Color(0.6, 0.9, 1.0))
	v.add_child(warden_label)
	hp_bar = _bar(100, Color(0.4, 0.85, 1.0), 14)
	v.add_child(hp_bar)
	xp_bar = _bar(100, Color(0.75, 0.55, 1.0), 6)
	v.add_child(xp_bar)
	warden_stats = _small("", 12, Color(1, 1, 1, 0.85))
	v.add_child(warden_stats)
	gear_label = _small("", 11, Color(1, 0.85, 0.55))
	v.add_child(gear_label)

	# the dungeon
	v.add_child(UI.label("Order's attention (champion at 100%)", 12, Color(1, 0.9, 0.6)))
	attention_bar = _bar(D.BOSS_THREAT, Color(1.0, 0.85, 0.5), 8)
	v.add_child(attention_bar)
	v.add_child(UI.label("Lure: who answers the call tomorrow", 12, Color(1, 0.8, 0.5)))
	lure_box = GridContainer.new()
	lure_box.columns = 2
	lure_box.add_theme_constant_override("h_separation", 4)
	lure_box.add_theme_constant_override("v_separation", 4)
	v.add_child(lure_box)
	stance_btn = UI.button("", Vector2(304, 28))
	stance_btn.pressed.connect(func(): run.souls.toggle_stance())
	v.add_child(stance_btn)
	harvest_label = _small("", 12, Color(1, 1, 1, 0.85))
	v.add_child(harvest_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	pause_btn = UI.button("Pause", Vector2(70, 28))
	pause_btn.pressed.connect(func(): run.toggle_pause())
	row.add_child(pause_btn)
	speed_btn = UI.button("x1", Vector2(60, 28))
	speed_btn.pressed.connect(func(): run.cycle_speed())
	row.add_child(speed_btn)
	sleep_btn = UI.button("Sleep", Vector2(166, 28))
	sleep_btn.tooltip_text = "End the run and keep the harvest. 100% at the end of each week (every 5th day), 60% otherwise."
	sleep_btn.pressed.connect(func(): run.sleep())
	row.add_child(sleep_btn)

	trophy_title = _small("", 11, Color(1, 0.85, 0.5))
	v.add_child(trophy_title)
	trophy_box = VBoxContainer.new()
	trophy_box.add_theme_constant_override("separation", 2)
	v.add_child(trophy_box)

	log_label = UI.label("", 11, Color(1, 1, 1, 0.75))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.clip_text = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(300, 40)
	v.add_child(log_label)


func _modal(width: float, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.04, 0.11, 0.97), border))
	p.custom_minimum_size = Vector2(width, 0)
	p.position = Vector2(MAP_CENTER.x - width / 2.0, 120)
	p.visible = false
	add_child(p)
	return p


func _build_level_panel() -> void:
	level_panel = _modal(640, Color(0.4, 0.85, 1.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	level_panel.add_child(v)
	var title := UI.label("THE WARDEN GROWS", 22, Color(0.6, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UI.label("Choose an ability", 13, Color(1, 1, 1, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	level_box = HBoxContainer.new()
	level_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_box.add_theme_constant_override("separation", 10)
	v.add_child(level_box)


func _build_end_panel() -> void:
	end_panel = _modal(460, Color(0.9, 0.8, 0.4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	end_panel.add_child(v)
	end_label = UI.label("", 18)
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

	banner = UI.label("", 28, Color(1, 0.8, 0.3))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(D.MAP_OFFSET.x, 60)
	banner.size = Vector2(D.GRID_W * D.CELL, 50)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	add_child(banner)

	# story narration over the bottom of the map
	narration = PanelContainer.new()
	narration.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.01, 0.04, 0.88), Color(0.55, 0.45, 0.7, 0.6), 4))
	narration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narration.position = Vector2(D.MAP_OFFSET.x + 60, 452)
	narration.custom_minimum_size = Vector2(D.GRID_W * D.CELL - 120, 0)
	narration.modulate.a = 0.0
	add_child(narration)
	narration_label = UI.label("", 15, Color(0.92, 0.88, 1.0))
	narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration_label.custom_minimum_size = Vector2(D.GRID_W * D.CELL - 140, 0)
	narration.add_child(narration_label)


func _on_narrate(text: String) -> void:
	narration_queue.append(text)
	if narration_time <= 0.0:
		_next_narration()


func _next_narration() -> void:
	if narration_queue.is_empty():
		narration_time = 0.0
		create_tween().tween_property(narration, "modulate:a", 0.0, 0.6)
		return
	var text: String = narration_queue.pop_front()
	narration_label.text = text
	narration.reset_size()
	narration.position.y = D.MAP_OFFSET.y + D.GRID_H * D.CELL - narration.size.y - 8
	narration.modulate.a = 1.0
	narration_time = 3.0 + text.length() / 25.0


## Narration runs on real time, so it also reads fine while the game is paused.
func _process(delta: float) -> void:
	if narration_time > 0.0:
		narration_time -= delta
		if narration_time <= 0.0:
			_next_narration()


# ============================================================ cards & choices

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


func rebuild_hand() -> void:
	var s = run.state
	for c in hand_box.get_children():
		c.queue_free()
	for i in s.hand.size():
		var btn := _card_button(s.hand[i], i == s.selected, Vector2(126, 140))
		btn.pressed.connect(func(): run.cards.use_card(i))
		hand_box.add_child(btn)


func rebuild_lures() -> void:
	var s = run.state
	for c in lure_box.get_children():
		c.queue_free()
	var available: Array = Meta.available_lures()
	for id in D.LURES:
		var def: Dictionary = D.LURES[id]
		var btn := UI.button(def["name"], Vector2(150, 26))
		btn.add_theme_font_size_override("font_size", 11)
		var lure_id: String = id
		if not available.has(lure_id):
			btn.disabled = true
			btn.tooltip_text = "Locked. Build it in the Lair."
		else:
			btn.tooltip_text = def["desc"]
			if lure_id == s.lure:
				btn.add_theme_stylebox_override("normal", UI.box(Color(0.35, 0.22, 0.08), Color(1, 0.8, 0.4)))
			btn.pressed.connect(func():
				run.set_lure(lure_id)
				rebuild_lures()
			)
		lure_box.add_child(btn)


func show_level_up() -> void:
	var s = run.state
	for c in level_box.get_children():
		c.queue_free()
	if s.level_choices.is_empty() or s.game_over:
		level_panel.visible = false
		return
	for i in s.level_choices.size():
		var def: Dictionary = D.ABILITIES[s.level_choices[i]]
		var btn := Button.new()
		btn.text = "%s\n\n%s" % [def["name"], def["desc"]]
		btn.custom_minimum_size = Vector2(190, 150)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_stylebox_override("normal", UI.box(Color(0.08, 0.16, 0.24), Color(0.4, 0.85, 1.0)))
		btn.add_theme_stylebox_override("hover", UI.box(Color(0.12, 0.24, 0.34), Color(1, 1, 1)))
		btn.pressed.connect(func(): run.warden.pick_ability(i))
		level_box.add_child(btn)
	level_panel.visible = true


# ============================================================ update

func refresh() -> void:
	var s = run.state
	day_label.text = "Day %d   ·   week ends on day %d" % [s.day, (s.day + D.SEAL_EVERY - 1) / D.SEAL_EVERY * D.SEAL_EVERY]
	day_bar.value = s.day_timer

	var w: Dictionary = s.warden
	warden_label.text = "%s   Lv %d" % [w["name"], w["level"]]
	hp_bar.max_value = w["max_hp"]
	hp_bar.value = w["hp"]
	var need: int = run.warden.xp_to_next()
	xp_bar.max_value = maxf(1.0, float(need))
	xp_bar.value = float(w["xp"]) if need > 0 else xp_bar.max_value
	var abil: Array = []
	for a in w["abilities"]:
		abil.append(D.ABILITIES[a]["name"])
	warden_stats.text = "HP %d/%d   DMG %.1f   XP %d/%s\n%s" % [
		int(w["hp"]), int(w["max_hp"]), w["dmg"], int(w["xp"]), str(need) if need > 0 else "max",
		"Abilities: " + (", ".join(abil) if not abil.is_empty() else "none yet")]
	var gear_lines: Array = []
	var gear: Dictionary = w["gear"]
	for slot in D.GEAR_SLOTS:
		if gear.has(slot):
			gear_lines.append("%s: %s" % [slot.capitalize(), gear[slot]["name"]])
		else:
			gear_lines.append("%s: -" % slot.capitalize())
	gear_label.text = "\n".join(gear_lines)

	attention_bar.value = s.threat
	stance_btn.text = ("Souls: RAISE as servants (%d/%d)" % [s.undead_count(), s.jar_cap]) if s.raise_souls else "Souls: the Warden DEVOURS them"
	stance_btn.tooltip_text = "Devour heals the Warden and gives XP. Raise makes an undead servant where the traveler fell. Hotkey: R"
	var pct: float = s.seal_pct()
	var relic_names: Array = []
	for r in s.relics:
		relic_names.append(D.RELICS[r]["name"])
	var found: Array = []
	for r in s.found_relics:
		found.append(D.RELICS[r]["name"])
	var txt := "Harvest: %d Bones  %d Blood  %d Gold" % [s.pouch["bones"], s.pouch["blood"], s.pouch["gold"]]
	if not relic_names.is_empty():
		txt += "\nRelics: " + ", ".join(relic_names)
	if not found.is_empty():
		txt += "\nFound (survive to keep): " + ", ".join(found)
	harvest_label.text = txt

	pause_btn.text = "Play" if s.paused else "Pause"
	speed_btn.text = "x%d" % int(s.time_scale)
	sleep_btn.text = "Sleep (keep %d%%)" % int(pct * 100.0)
	sleep_btn.disabled = s.game_over
	sleep_btn.modulate = Color(1, 0.9, 0.4) if pct >= 1.0 else Color(1, 1, 1)
	_update_tooltip()


func show_end(outcome: String, payout: Dictionary, pct: float, kept: Array, lost: Array) -> void:
	level_panel.visible = false
	tooltip.visible = false
	var s = run.state
	var head := ""
	match outcome:
		"victory":
			head = "ACT CLEARED\n%s has been devoured." % D.ACTS[s.act]["boss"]
		"sleep":
			head = "THE DUNGEON SLEEPS\nYou keep %d%% of the harvest." % int(pct * 100.0)
		_:
			head = "THE WARDEN FALLS\nOnly %d%% of the harvest remains." % int(pct * 100.0)
	var gains: Array = []
	for k in payout:
		gains.append("+%d %s" % [int(payout[k]), D.RESOURCES[k]["name"]])
	var text := "%s\n\nDays: %d   Travelers taken: %d\n%s" % [head, s.day, s.kills, "   ".join(gains)]
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
	trophy_title.text = "Trophies %d/%d   (click: the Warden wears it · RMB: grind to bones)" % [s.inventory.size(), D.INVENTORY_MAX]
	for c in trophy_box.get_children():
		c.queue_free()
	for i in s.inventory.size():
		var item: Dictionary = s.inventory[i]
		var rar: Dictionary = D.RARITIES[item["rarity"]]
		var col: Color = rar["color"]
		var btn := Button.new()
		btn.text = "%s  (%s)" % [item["name"], LootSystem.describe(item)]
		btn.tooltip_text = "%s slot: %s" % [str(item["slot"]).capitalize(), btn.text]
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(300, 20)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", col.lightened(0.3))
		var border := Color(col, 0.4)
		btn.add_theme_stylebox_override("normal", UI.box(Color(0.07, 0.05, 0.1, 0.9), border, 3))
		btn.add_theme_stylebox_override("hover", UI.box(Color(0.12, 0.09, 0.16, 0.95), Color(1, 1, 1), 3))
		btn.pressed.connect(func(): run.loot.equip(i))
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
	if s.game_over or level_panel.visible:
		tooltip.visible = false
		return
	var cell: Vector2i = run.view.mouse_cell()
	var lines: Array = []
	if s.path_lookup.has(cell):
		var t: int = s.path_lookup[cell]
		var card: String = s.card_at(t)
		if t == 0:
			lines.append("The door: travelers come in here. Three laps and they find the way out.")
		elif card != "":
			lines.append("%s: %s" % [D.CARDS[card]["name"], D.CARDS[card]["desc"]])
		elif t >= s.loop_size:
			lines.append("Side passage (the Warden never walks here)")
		if s.forks.has(t):
			lines.append("Fork: each traveler picks a branch by personality.")
		if s.warden_at(t):
			lines.append("The Warden  %d/%d HP  %.1f dmg" % [int(s.warden["hp"]), int(s.warden["max_hp"]), s.warden["dmg"]])
		for u in s.alive_units(t):
			lines.append("%s  %d/%d HP  %.1f dmg" % [u["name"], int(u["hp"]), int(u["max_hp"]), u["dmg"]])
		for h in s.travelers_at(t):
			var trait_id: String = h["trait"]
			var tr_txt := "" if trait_id == "" else "  [%s]" % D.TRAITS[trait_id]["name"]
			lines.append("%s (%s)%s  %d/%d HP  lap %d/%d" % [s.hero_name(h), D.HERO_CLASSES[h["cls"]]["name"], tr_txt,
				int(h["hp"]), int(h["max_hp"]), int(h["laps"]), D.ESCAPE_LAPS])
	elif s.scenery.has(cell):
		var id: String = s.scenery[cell]
		lines.append("%s: %s" % [D.CARDS[id]["name"], D.CARDS[id]["desc"]])
	elif cell == s.heart_cell:
		lines.append("The dungeon's heart. It hungers.")
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
