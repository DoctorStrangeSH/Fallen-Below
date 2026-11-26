extends CanvasLayer
## Run HUD, split by purpose so nothing competes for the same corner:
##   top bar    — time (act, loop, day), the Order's attention, pause/speed/sleep
##   right side — the Warden sheet: health, stats, gear, ability, loot bag,
##                then the dungeon's own levers: lure, souls, harvest, relics, a short log
##   bottom     — the hand of cards (picture + name, details on hover)
## Labels are replaced by icons wherever possible; every icon explains itself on hover.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const LootSystem = preload("res://scripts/systems/loot_system.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const MAP_CENTER := Vector2(D.MAP_OFFSET.x + D.GRID_W * D.CELL / 2.0, D.MAP_OFFSET.y + D.GRID_H * D.CELL / 2.0)
const PANEL_W := 1272.0 - D.PANEL_X
const INNER_W := PANEL_W - 20.0
const MUTED := Color(0.72, 0.66, 0.82, 0.75)
const PANEL_BG := Color(0.08, 0.06, 0.11)
const SLOT_BG := Color(0.11, 0.08, 0.15)

var run  # run.gd

# top bar
var act_label: Label
var day_label: Label
var day_bar: ProgressBar
var attention_bar: ProgressBar
var attention_label: Label
var pause_btn: Button
var pause_icon: Control
var speed_btn: Button
var sleep_btn: Button

# Warden sheet
var warden_label: Label
var level_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var xp_bar: ProgressBar
var stat_labels := {}
var gear_boxes: Array = []
var active_btn: Button
var night_btn: Button
var night_bar: ProgressBar
var loot_title: Label
var loot_boxes: Array = []

# dungeon levers
var lure_buttons := {}
var lure_name: Label
var loud_buttons: Array = []
var forecast_row: HBoxContainer
var forecast_key := ""
var devour_btn: Button
var raise_btn: Button
var pouch_labels := {}
var relic_box: HBoxContainer
var relic_count := -1
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

# hover hints: whichever control the mouse is over supplies the tooltip text
# drag & drop: loot -> gear slot, gear -> bag, card -> map
var drag_kind := ""       # "", "loot", "gear", "card"
var drag_index := -1
var drag_from := Vector2.ZERO
var drag_active := false
var drag_ghost: Control
var loot_row: HBoxContainer

var hint_owner: Control = null
var hint_text: Callable


func _ready() -> void:
	_build_top_bar()
	_build_panel()
	hand_box = HBoxContainer.new()
	hand_box.position = Vector2(D.MAP_OFFSET.x, D.HAND_Y)
	hand_box.add_theme_constant_override("separation", 6)
	add_child(hand_box)
	_build_end_panel()
	_build_level_panel()
	_build_overlays()

	var s = run.state
	s.log_added.connect(_on_log)
	s.hand_changed.connect(rebuild_hand)
	s.inventory_changed.connect(rebuild_trophies)
	s.combo_found.connect(show_banner)
	s.narrate.connect(_on_narrate)
	s.level_up.connect(show_level_up)
	act_label.text = Loc.t(D.ACTS[s.act]["name"])
	rebuild_hand()
	rebuild_trophies()
	rebuild_lures()
	_on_log()
	refresh()


# ============================================================ small builders

func _bar(max_value: float, color: Color, height: float = 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := UI.box(Color(0.12, 0.1, 0.15), Color(0, 0, 0, 0), 3)
	bg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", bg)
	var fill := UI.box(color, Color(0, 0, 0, 0), 3)
	fill.set_content_margin_all(0)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _header(text: String) -> Label:
	var l := UI.label(text.to_upper(), 10, MUTED)
	l.add_theme_constant_override("outline_size", 0)
	return l


## A flat square button with an icon inside (no text).
func _icon_button(kind: String, sz: Vector2, icon_px: float = 18.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click"))
	_style_slot(b, SLOT_BG, Color(0.35, 0.26, 0.45))
	var ic := Icon.make(kind, icon_px)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(ic)
	return b


func _style_slot(b: Control, bg: Color, border: Color) -> void:
	var n := UI.box(bg, border, 4)
	n.set_border_width_all(2)
	n.set_content_margin_all(2)
	var h := UI.box(bg.lightened(0.12), Color(1, 1, 1, 0.8), 4)
	h.set_border_width_all(2)
	h.set_content_margin_all(2)
	if b is Button:
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", h)
		b.add_theme_stylebox_override("disabled", n)
	else:
		b.add_theme_stylebox_override("panel", n)


func _hint(c: Control, text: Callable) -> void:
	c.mouse_entered.connect(func():
		hint_owner = c
		hint_text = text
	)
	c.mouse_exited.connect(func():
		if hint_owner == c:
			hint_owner = null
	)


func _small_button(text: String, w: float) -> Button:
	var b := UI.button(text, Vector2(w, 30))
	b.add_theme_font_size_override("font_size", 13)
	b.clip_text = true
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.set_content_margin_all(4)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(st, sb)
	return b


# ============================================================ top bar

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(D.MAP_OFFSET.x, 8)
	bar.custom_minimum_size = Vector2(D.GRID_W * D.CELL, 38)
	var sb := UI.box(PANEL_BG, Color(0.3, 0.22, 0.4), 6)
	sb.set_border_width_all(2)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	act_label = UI.label("", 14, Color(0.78, 0.6, 1.0))
	act_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(act_label)
	day_label = UI.label("", 13, Color(1, 1, 1, 0.85))
	day_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(day_label)
	day_bar = _bar(D.DAY_LENGTH, Color(0.85, 0.75, 0.4), 6)
	day_bar.custom_minimum_size.x = 70
	day_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(day_bar)
	day_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint(day_label, func():
		var s = run.state
		var week_end: int = (s.day + D.SEAL_EVERY - 1) / D.SEAL_EVERY * D.SEAL_EVERY
		return Loc.t("Loop %d, day %d.\nThe week ends on day %d: sleeping then keeps the whole harvest.") % [s.loop, s.day, week_end])

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var att := HBoxContainer.new()
	att.add_theme_constant_override("separation", 6)
	att.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(att)
	att.add_child(Icon.make("sun", 18))
	attention_bar = _bar(D.BOSS_THREAT, Color(1.0, 0.8, 0.4), 10)
	attention_bar.custom_minimum_size.x = 190
	att.add_child(attention_bar)
	attention_label = UI.label("", 12, Color(1, 0.85, 0.55))
	attention_label.custom_minimum_size.x = 36
	attention_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	att.add_child(attention_label)
	_hint(att, func():
		var s = run.state
		var act: Dictionary = D.ACTS[s.act]
		return Loc.t("The Order's attention.\nKills, escapes and new halls raise it. At 100%% the champion comes: %s, %s.") % [Loc.t(act["boss"]), Loc.t(act["boss_title"])])

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)

	pause_btn = _small_button("", 36)
	pause_icon = Icon.make("pause", 14, Color(1, 1, 1, 0.9))
	pause_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_btn.add_child(pause_icon)
	pause_btn.pressed.connect(func(): run.toggle_pause())
	_hint(pause_btn, func(): return Loc.t("Planning pause (Space): time stops, everything else still works.\nEsc: settings."))
	row.add_child(pause_btn)
	speed_btn = _small_button("x1", 40)
	speed_btn.pressed.connect(func(): run.cycle_speed())
	_hint(speed_btn, func(): return Loc.t("Speed (1, 2, 3)"))
	row.add_child(speed_btn)
	sleep_btn = _small_button("", 96)
	sleep_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var moon := Icon.make("moon", 14)
	moon.position = Vector2(6, 4)
	moon.size = Vector2(20, 22)
	sleep_btn.add_child(moon)
	sleep_btn.pressed.connect(func(): run.sleep())
	_hint(sleep_btn, func(): return Loc.t("Sleep: end the run and keep the harvest.\n100% at the end of each week, 60% otherwise."))
	row.add_child(sleep_btn)


# ============================================================ right panel

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(D.PANEL_X, 8)
	panel.custom_minimum_size = Vector2(PANEL_W, 704)
	panel.size = Vector2(PANEL_W, 704)
	panel.add_theme_stylebox_override("panel", UI.box(PANEL_BG, Color(0.3, 0.22, 0.4)))
	panel.clip_contents = true
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(INNER_W, 0)
	panel.add_child(v)

	_build_warden(v)
	v.add_child(HSeparator.new())
	_build_dungeon(v)


func _build_warden(v: VBoxContainer) -> void:
	# name + level
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(head)
	warden_label = UI.label("", 16, Color(0.6, 0.9, 1.0))
	warden_label.clip_text = true
	warden_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(warden_label)
	level_label = UI.label("", 13, Color(0.8, 0.65, 1.0))
	head.add_child(level_label)
	_hint(head, _warden_hint)

	# health bar with the numbers inside it, thin XP bar under it
	hp_bar = _bar(100, Color(0.3, 0.75, 0.95), 20)
	v.add_child(hp_bar)
	hp_text = UI.label("", 12, Color(1, 1, 1))
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_text.add_theme_constant_override("outline_size", 3)
	hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_bar.add_child(hp_text)
	xp_bar = _bar(100, Color(0.75, 0.55, 1.0), 4)
	v.add_child(xp_bar)

	# stats: icon + number, name on hover
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	v.add_child(grid)
	for k in ["dmg", "def", "regen", "vamp", "evade", "counter"]:
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(INNER_W / 3.0 - 6, 22)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(Icon.make(k, 15))
		var l := UI.label("", 14)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(l)
		stat_labels[k] = l
		var stat_id: String = k
		_hint(cell, func(): return _stat_hint(stat_id))
		grid.add_child(cell)

	# gear slots
	v.add_child(_header(Loc.t("Gear")))
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 6)
	v.add_child(gear_row)
	var slots: Array = run.state.warden["slots"]
	for i in slots.size():
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(54, 50)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_slot(box, SLOT_BG, Color(0.3, 0.25, 0.38))
		var ic := Icon.make(str(slots[i]), 24, Color(1, 1, 1, 0.15))
		box.add_child(ic)
		gear_row.add_child(box)
		gear_boxes.append(box)
		var idx: int = i
		box.gui_input.connect(func(ev: InputEvent): _press(ev, "gear", idx))
		_hint(box, func(): return _gear_hint(idx))

	# active ability
	active_btn = _small_button("", INNER_W)
	active_btn.custom_minimum_size.y = 34
	active_btn.pressed.connect(func(): run.warden.use_active())
	_hint(active_btn, func():
		var wdef: Dictionary = Meta.warden_def()
		return Loc.t("%s\n%s\n\nPassive, %s: %s") % [Loc.t(wdef["active"]), Loc.t(wdef["active_desc"]), Loc.t(wdef["passive"]), Loc.t(wdef["passive_desc"])])
	v.add_child(active_btn)

	# Act IV: the Night, filled by deaths and released with N or a click on the heart
	if run.state.act == 4:
		var night_row := HBoxContainer.new()
		night_row.add_theme_constant_override("separation", 6)
		v.add_child(night_row)
		night_btn = _small_button("", 150)
		night_btn.custom_minimum_size.y = 30
		night_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var moon := Icon.make("moon", 14)
		moon.position = Vector2(8, 4)
		moon.size = Vector2(20, 22)
		night_btn.add_child(moon)
		night_btn.pressed.connect(func(): run.nightfall())
		night_row.add_child(night_btn)
		night_bar = _bar(D.NIGHT_MAX, Color(0.45, 0.4, 0.95), 10)
		night_row.add_child(night_bar)
		_hint(night_btn, func(): return Loc.t("Nightfall [N]\nEvery death wakes the Night. When it is full, let it fall: for %d s travelers move at half speed and take 50%% more damage, the Archon takes double and his sunbursts fall silent.") % int(D.NIGHTFALL_TIME))

	# loot bag
	loot_title = _header("")
	v.add_child(loot_title)
	loot_row = HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 4)
	v.add_child(loot_row)
	for i in D.INVENTORY_MAX:
		var b := _icon_button("", Vector2(47, 44), 22)
		var idx: int = i
		b.button_down.connect(func(): _begin("loot", idx))
		b.gui_input.connect(func(ev: InputEvent):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				run.loot.discard(idx)
		)
		_hint(b, func(): return _loot_hint(idx))
		loot_row.add_child(b)
		loot_boxes.append(b)


func _build_dungeon(v: VBoxContainer) -> void:
	# lure: one icon per traveler kind
	var lure_head := HBoxContainer.new()
	v.add_child(lure_head)
	lure_head.add_child(_header(Loc.t("Lure")))
	lure_name = UI.label("", 11, Color(1, 0.8, 0.5))
	lure_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lure_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lure_name.clip_text = true
	lure_head.add_child(lure_name)
	var lure_row := HBoxContainer.new()
	lure_row.add_theme_constant_override("separation", 4)
	v.add_child(lure_row)
	for id in D.LURES:
		var lure_act := int(D.LURES[id].get("act", 0))
		if lure_act != 0 and lure_act != run.state.act:
			continue  # other acts' lures never show up here
		var lure_id: String = id
		var b := _icon_button(lure_id, Vector2(47, 36), 18)
		b.pressed.connect(func():
			run.set_lure(lure_id)
			rebuild_lures()
		)
		_hint(b, func(): return _lure_hint(lure_id))
		lure_row.add_child(b)
		lure_buttons[lure_id] = b

	# how loudly to call: Whisper (free), Call, Feast (paid from the harvest each day)
	var loud_row := HBoxContainer.new()
	loud_row.add_theme_constant_override("separation", 4)
	v.add_child(loud_row)
	for i in D.LURE_LEVELS.size():
		var lv_i: int = i
		var b := _small_button("", INNER_W / 3.0 - 3)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): run.set_lure_level(lv_i))
		_hint(b, func(): return _loud_hint(lv_i))
		loud_row.add_child(b)
		loud_buttons.append(b)
	# tomorrow's party
	forecast_row = HBoxContainer.new()
	forecast_row.add_theme_constant_override("separation", 2)
	forecast_row.mouse_filter = Control.MOUSE_FILTER_STOP
	forecast_row.custom_minimum_size.y = 22
	v.add_child(forecast_row)
	_hint(forecast_row, _forecast_hint)

	# souls: two halves of one switch
	v.add_child(_header(Loc.t("Souls of the fallen  [R]")))
	var souls := HBoxContainer.new()
	souls.add_theme_constant_override("separation", 4)
	v.add_child(souls)
	devour_btn = _small_button(Loc.t("Devour"), INNER_W / 2.0 - 2)
	raise_btn = _small_button("", INNER_W / 2.0 - 2)
	for pair in [[devour_btn, "devour", false], [raise_btn, "raise", true]]:
		var b: Button = pair[0]
		var want: bool = pair[2]
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var ic := Icon.make(pair[1], 15)
		ic.position = Vector2(8, 6)
		ic.size = Vector2(20, 20)
		b.add_child(ic)
		b.pressed.connect(func():
			if run.state.raise_souls != want:
				run.souls.toggle_stance()
		)
		souls.add_child(b)
	_hint(devour_btn, func(): return Loc.t("Devour: the Warden eats the fallen, heals, gains XP and grows by its diet."))
	_hint(raise_btn, func(): return Loc.t("Raise: the fallen stand up as your servants, and whisper pages of the Book of the Fallen."))

	# harvest and relics on one line
	v.add_child(_header(Loc.t("Harvest and relics")))
	var pouch := HBoxContainer.new()
	pouch.add_theme_constant_override("separation", 4)
	v.add_child(pouch)
	for r in ["bones", "blood", "gold"]:
		var cell := HBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(Icon.make(r, 15))
		var l := UI.label("0", 14, Icons.color_of(r))
		l.custom_minimum_size.x = 34
		cell.add_child(l)
		pouch_labels[r] = l
		var res: String = r
		_hint(cell, func(): return Loc.t("%s in this run's harvest. Kept when you sleep; lost in part if the Warden falls.") % Loc.t(D.RESOURCES[res]["name"]))
		pouch.add_child(cell)
	relic_box = HBoxContainer.new()
	relic_box.add_theme_constant_override("separation", 2)
	pouch.add_child(relic_box)

	# a short log at the bottom
	log_label = UI.label("", 11, Color(1, 1, 1, 0.55))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.clip_text = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(INNER_W, 40)
	v.add_child(log_label)


# ============================================================ modals & overlays

func _modal(width: float, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.04, 0.11, 0.97), border))
	p.custom_minimum_size = Vector2(width, 0)
	p.position = Vector2(MAP_CENTER.x - width / 2.0, 140)
	p.visible = false
	add_child(p)
	return p


func _build_level_panel() -> void:
	level_panel = _modal(640, Color(0.75, 0.55, 1.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	level_panel.add_child(v)
	var title := UI.label(Loc.t("THE WARDEN REMEMBERS"), 22, Color(0.8, 0.65, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UI.label(Loc.t("Choose an ability"), 13, Color(1, 1, 1, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	level_box = HBoxContainer.new()
	level_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_box.add_theme_constant_override("separation", 10)
	v.add_child(level_box)


func show_level_up() -> void:
	var s = run.state
	for c in level_box.get_children():
		c.queue_free()
	if s.level_choices.is_empty() or s.game_over:
		level_panel.visible = false
		return
	for i in s.level_choices.size():
		var def: Dictionary = run.warden.ability_def(s.level_choices[i])
		var btn := Button.new()
		btn.text = "%s\n\n%s" % [Loc.t(def["name"]), Loc.t(def["desc"])]
		btn.custom_minimum_size = Vector2(190, 150)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_stylebox_override("normal", UI.box(Color(0.14, 0.08, 0.22), Color(0.75, 0.55, 1.0)))
		btn.add_theme_stylebox_override("hover", UI.box(Color(0.22, 0.13, 0.32), Color(1, 1, 1)))
		btn.pressed.connect(func(): run.warden.pick_ability(i))
		level_box.add_child(btn)
	level_panel.visible = true


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
	tooltip.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.03, 0.06, 0.95), Color(0.45, 0.35, 0.58), 4))
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	add_child(tooltip)
	tooltip_label = UI.label("", 13)
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.add_child(tooltip_label)

	banner = UI.label("", 28, Color(1, 0.8, 0.3))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(D.MAP_OFFSET.x, D.MAP_OFFSET.y + 40)
	banner.size = Vector2(D.GRID_W * D.CELL, 50)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("outline_size", 6)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.modulate.a = 0.0
	add_child(banner)

	# story narration over the bottom of the map
	narration = PanelContainer.new()
	narration.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.01, 0.04, 0.9), Color(0.55, 0.45, 0.7, 0.6), 4))
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
## Mouse down on a gear slot (not a Button, so it needs gui_input).
func _press(ev: InputEvent, kind: String, idx: int) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_begin(kind, idx)


func _begin(kind: String, idx: int) -> void:
	if run.state.is_blocked():
		return
	drag_kind = kind
	drag_index = idx
	drag_from = get_viewport().get_mouse_position()
	drag_active = false


## Follows the mouse once it has moved far enough; a short press stays a plain click.
func _input(event: InputEvent) -> void:
	if drag_kind == "":
		return
	var s = run.state
	var mm := event as InputEventMouseMotion
	if mm != null and not drag_active and mm.position.distance_to(drag_from) > 8.0:
		_start_drag()
	if mm != null and drag_active and drag_ghost != null:
		drag_ghost.position = mm.position - drag_ghost.size / 2.0
	var mb := event as InputEventMouseButton
	if mb == null or mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var kind := drag_kind
	var idx := drag_index
	var was_drag := drag_active
	_end_drag()
	if not was_drag:
		match kind:  # plain clicks keep their old meaning
			"loot":
				run.loot.equip(idx)
			"card":
				run.cards.use_card(idx)
		return
	get_viewport().set_input_as_handled()
	var at := mb.position
	match kind:
		"loot":
			for g in gear_boxes.size():
				if (gear_boxes[g] as Control).get_global_rect().has_point(at):
					run.loot.equip(idx, g)
					return
		"gear":
			if loot_row.get_global_rect().grow(6).has_point(at):
				run.loot.unequip(idx)
		"card":
			var cell: Vector2i = run.view.mouse_cell()
			if s.in_grid(cell) and Rect2(D.MAP_OFFSET, Vector2(D.GRID_W, D.GRID_H) * D.CELL).has_point(at):
				s.selected = idx
				run.cards.place_selected(cell)
			s.selected = -1
			s.hand_changed.emit()


func _start_drag() -> void:
	var s = run.state
	var kind := "card:" + str(s.hand[drag_index]) if drag_kind == "card" else ""
	var col := Color(1, 1, 1)
	if drag_kind == "loot":
		if drag_index >= s.inventory.size():
			drag_kind = ""
			return
		var item: Dictionary = s.inventory[drag_index]
		kind = str(item["slot"])
		col = D.RARITIES[item["rarity"]]["color"]
	elif drag_kind == "gear":
		var gear: Dictionary = s.warden["gear"]
		if not gear.has(drag_index):
			drag_kind = ""
			return
		kind = str(gear[drag_index]["slot"])
		col = D.RARITIES[gear[drag_index]["rarity"]]["color"]
	drag_active = true
	s.holding = true
	if drag_kind == "card":
		s.selected = drag_index  # the map shows where it would go
	drag_ghost = Icon.make(kind, 40 if drag_kind == "card" else 28, col)
	drag_ghost.size = Vector2(80, 60) if drag_kind == "card" else Vector2(44, 44)
	drag_ghost.modulate.a = 0.85
	drag_ghost.animated = true
	add_child(drag_ghost)


func _end_drag() -> void:
	drag_kind = ""
	drag_active = false
	run.state.holding = false
	if drag_ghost != null:
		drag_ghost.queue_free()
		drag_ghost = null


func _process(delta: float) -> void:
	if narration_time > 0.0:
		narration_time -= delta
		if narration_time <= 0.0:
			_next_narration()


# ============================================================ cards

func _card_button(id: String, highlighted: bool) -> Button:
	var def: Dictionary = D.CARDS[id]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(112, 120)
	btn.focus_mode = Control.FOCUS_NONE
	var base: Color = def["color"]
	var col := base.darkened(0.55)
	var border := Color(1, 1, 1) if highlighted else base.darkened(0.1)
	for st in ["normal", "hover", "pressed"]:
		var sb := UI.box(col if st == "normal" else col.lightened(0.12), border if st == "normal" else Color(1, 1, 1, 0.85), 6)
		sb.set_border_width_all(3 if highlighted else 2)
		btn.add_theme_stylebox_override(st, sb)
	var glyph := Icon.make("card:" + id, 40)
	glyph.position = Vector2(16, 10)
	glyph.size = Vector2(80, 56)
	glyph.animated = id == "grinder" or id == "drowned" or id == "jar"
	btn.add_child(glyph)
	var name := UI.label(Loc.t(def["name"]), 13, Color(1, 1, 1, 0.95))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.position = Vector2(4, 70)
	name.size = Vector2(104, 44)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	_hint(btn, func(): return "%s\n%s" % [Loc.t(def["name"]), Loc.t(def["desc"])])
	return btn


func rebuild_hand() -> void:
	var s = run.state
	for c in hand_box.get_children():
		c.queue_free()
	for i in s.hand.size():
		var btn := _card_button(s.hand[i], i == s.selected)
		btn.button_down.connect(func(): _begin("card", i))
		hand_box.add_child(btn)


# ============================================================ lures, loot, relics

func rebuild_lures() -> void:
	var s = run.state
	var available: Array = Meta.available_lures(s.act)
	for id in lure_buttons:
		var b: Button = lure_buttons[id]
		var open: bool = available.has(id)
		var picked: bool = id == s.lure
		b.disabled = not open
		var ic: Control = b.get_child(0)
		if not open:
			ic.set_icon("lock", Color(1, 1, 1, 0.25))
		else:
			ic.set_icon(id, Icons.color_of(id) if picked else Color(0.85, 0.8, 0.95, 0.65))
		_style_slot(b, Color(0.3, 0.2, 0.08) if picked else SLOT_BG, Color(1, 0.8, 0.4) if picked else Color(0.3, 0.25, 0.38))
	lure_name.text = Loc.t(D.LURES[s.lure]["name"]) if D.LURES.has(s.lure) else ""
	_refresh_loudness()


func _refresh_loudness() -> void:
	var s = run.state
	var price: String = D.LURES[s.lure]["price"]
	for i in loud_buttons.size():
		var b: Button = loud_buttons[i]
		var locked: bool = i > Meta.max_lure_level()
		var cost: int = Meta.lure_cost(i)
		var name: String = Loc.t(D.LURE_LEVELS[i]["name"])
		b.text = name if cost == 0 else "%s %d" % [name, cost]
		if locked:
			b.text = name
		b.disabled = locked
		var on: bool = i == s.lure_level
		_style_slot(b, Color(0.3, 0.2, 0.08) if on else SLOT_BG, Color(1, 0.8, 0.4) if on else Color(0.3, 0.25, 0.38))
		var ic: Control = b.get_node_or_null("Price")
		if ic == null:
			ic = Icon.make(price, 12)
			ic.name = "Price"
			ic.position = Vector2(4, 7)
			ic.size = Vector2(16, 16)
			b.add_child(ic)
		ic.visible = cost > 0 and not locked
		ic.set_icon(price, Icons.color_of(price))
		if locked:
			var lk: Control = b.get_node_or_null("Lock")
			if lk == null:
				lk = Icon.make("lock", 11, Color(1, 1, 1, 0.35))
				lk.name = "Lock"
				lk.position = Vector2(4, 7)
				lk.size = Vector2(16, 16)
				b.add_child(lk)


func _loud_hint(i: int) -> String:
	var s = run.state
	var def: Dictionary = D.LURE_LEVELS[i]
	if i > Meta.max_lure_level():
		return Loc.t("%s\nLocked: Bait Workshop level 2 in the Lair.") % Loc.t(def["name"])
	var price: String = D.LURES[s.lure]["price"]
	var t := "%s\n%s" % [Loc.t(def["name"]), Loc.t(def["desc"])]
	var cost: int = Meta.lure_cost(i)
	if cost > 0:
		t += Loc.t("\n\nCosts %d %s from this run's harvest at the start of each day.") % [cost, Loc.t(D.RESOURCES[price]["name"])]
	return t


func _forecast_hint() -> String:
	var s = run.state
	var lines: Array = [Loc.t("Tomorrow's party:")]
	var show_traits: bool = Meta.level("bait_workshop") >= 3
	for f in s.forecast:
		var cls: Dictionary = D.HERO_CLASSES[f["cls"]]
		var drop: Dictionary = cls["drop"]
		var carry: Array = []
		for k in drop:
			carry.append("%d %s" % [int(drop[k]), Loc.t(D.RESOURCES[k]["name"])])
		var tr := ""
		if show_traits and f["trait"] != "":
			tr = " [%s]" % Loc.t(D.TRAITS[f["trait"]]["name"])
		lines.append("• %s%s: %s" % [Loc.t(cls["name"]), tr, ", ".join(carry)])
	if D.LURES[s.lure].get("wounded", false):
		lines.append(Loc.t("They come wounded and carry half as much."))
	return "\n".join(lines)


func _refresh_forecast() -> void:
	var s = run.state
	var key := str(s.forecast) + str(s.lure_level)
	if key == forecast_key:
		return
	forecast_key = key
	for c in forecast_row.get_children():
		c.queue_free()
	forecast_row.add_child(_header(Loc.t("Tomorrow")))
	var sp := Control.new()
	sp.custom_minimum_size.x = 6
	forecast_row.add_child(sp)
	for f in s.forecast:
		var col: Color = D.HERO_CLASSES[f["cls"]]["color"]
		forecast_row.add_child(Icon.make("person", 15, col))


func _lure_hint(id: String) -> String:
	var def: Dictionary = D.LURES[id]
	if not Meta.available_lures(run.state.act).has(id):
		if def.has("act") and int(def["act"]) != run.state.act:
			return Loc.t("%s\nOnly in %s.") % [Loc.t(def["name"]), Loc.t(D.ACTS[int(def["act"])]["name"])]
		return Loc.t("%s\nLocked. Build it in the Lair.") % Loc.t(def["name"])
	return Loc.t("%s\n%s\n\nDecides who comes down tomorrow.") % [Loc.t(def["name"]), Loc.t(def["desc"])]


func rebuild_trophies() -> void:
	var s = run.state
	loot_title.text = (Loc.t("Loot %d/%d  ·  click: wear  ·  RMB: throw away") % [s.inventory.size(), D.INVENTORY_MAX]).to_upper()
	for i in loot_boxes.size():
		var b: Button = loot_boxes[i]
		var ic: Control = b.get_child(0)
		if i < s.inventory.size():
			var item: Dictionary = s.inventory[i]
			var col: Color = D.RARITIES[item["rarity"]]["color"]
			var wearable: bool = run.warden.can_wear(item["slot"])
			ic.set_icon(item["slot"], col if wearable else Color(col, 0.35))
			_style_slot(b, Color(col, 0.12), Color(col, 0.7))
		else:
			ic.set_icon("", Color(1, 1, 1))
			_style_slot(b, Color(0.07, 0.05, 0.1), Color(0.2, 0.17, 0.26))


func _loot_hint(i: int) -> String:
	var s = run.state
	if i >= s.inventory.size():
		return Loc.t("Empty. Gear drops from the travelers you kill.")
	var item: Dictionary = s.inventory[i]
	return Loc.t("%s  (%s, level %d)\n%s\n\nWearing now: %s\n\nClick or drag onto a slot: wear  ·  RMB: throw away") % [item["name"], Loc.t(str(item["slot"]).capitalize()),
		int(item["level"]), LootSystem.describe(item).replace(", ", "\n"), _worn_text(item["slot"])]


func _rebuild_relics() -> void:
	var s = run.state
	for c in relic_box.get_children():
		c.queue_free()
	var all: Array = []
	for r in s.relics:
		all.append([r, false])
	for r in s.found_relics:
		all.append([r, true])
	for pair in all:
		var id: String = pair[0]
		var found: bool = pair[1]
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(18, 22)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var ic := Icon.make("relic", 13, Color(0.6, 1.0, 0.8) if found else Color(0.85, 0.6, 1.0))
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell.add_child(ic)
		_hint(cell, func():
			var t := "%s\n%s" % [Loc.t(D.RELICS[id]["name"]), Loc.t(D.RELICS[id]["desc"])]
			return t + (Loc.t("\n\nFound in this run: survive to keep it.") if found else ""))
		relic_box.add_child(cell)


# ============================================================ update

func refresh() -> void:
	var s = run.state
	day_label.text = Loc.t("Loop %d · Day %d") % [s.loop, s.day]
	day_bar.value = s.day_timer
	attention_bar.value = s.threat
	attention_label.text = "%d%%" % int(s.threat * 100.0 / D.BOSS_THREAT)
	pause_icon.set_icon("play" if s.paused else "pause", Color(1, 1, 1, 0.9))
	speed_btn.text = "x%d" % int(s.time_scale)
	var pct: float = s.seal_pct()
	sleep_btn.text = "%d%%" % int(pct * 100.0)
	sleep_btn.disabled = s.game_over
	sleep_btn.modulate = Color(1, 0.9, 0.4) if pct >= 1.0 else Color(1, 1, 1)

	var w: Dictionary = s.warden
	var growth: bool = w.get("growth", false)
	warden_label.text = "%s, %s" % [w["name"], w["title"]]
	level_label.text = (Loc.t("Lv %d") % int(w["level"])) if growth else ""
	xp_bar.visible = growth
	if growth:
		var need: int = run.warden.xp_to_next()
		xp_bar.max_value = maxf(1.0, float(need))
		xp_bar.value = float(w["xp"]) if need > 0 else xp_bar.max_value
	hp_bar.max_value = w["max_hp"]
	hp_bar.value = w["hp"]
	hp_text.text = "%d / %d" % [int(w["hp"]), int(w["max_hp"])]
	var st: Dictionary = w["stats"]
	for k in stat_labels:
		var val: float = st.get(k, 0.0)
		var l: Label = stat_labels[k]
		l.text = ("%d%%" % int(val)) if D.STATS[k]["pct"] else ("%.1f" % val)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95) if val > 0.0 else Color(1, 1, 1, 0.3))

	var gear: Dictionary = w["gear"]
	var slots: Array = w["slots"]
	for i in gear_boxes.size():
		var box: PanelContainer = gear_boxes[i]
		var ic: Control = box.get_child(0)
		if gear.has(i):
			var col: Color = D.RARITIES[gear[i]["rarity"]]["color"]
			ic.set_icon(str(slots[i]), col)
			_style_slot(box, Color(col, 0.12), Color(col, 0.6))
		else:
			ic.set_icon(str(slots[i]), Color(1, 1, 1, 0.15))
			_style_slot(box, SLOT_BG, Color(0.3, 0.25, 0.38))

	var wdef: Dictionary = Meta.warden_def()
	var cd: float = w["cooldown"]
	active_btn.text = (Loc.t("[Q] %s") % Loc.t(wdef["active"])) if cd <= 0.0 else (Loc.t("[Q] %s  %ds") % [Loc.t(wdef["active"]), int(ceil(cd))])
	active_btn.disabled = cd > 0.0 or s.game_over

	_refresh_forecast()
	_refresh_loudness()
	if night_btn != null:
		night_bar.value = s.night
		var full: bool = s.night >= D.NIGHT_MAX
		if s.nightfall > 0.0:
			night_btn.text = Loc.t("Night %ds") % int(ceil(s.nightfall))
		else:
			night_btn.text = Loc.t("[N] Nightfall") if full else "%d%%" % int(s.night)
		night_btn.disabled = not full or s.nightfall > 0.0
		night_btn.modulate = Color(1, 0.95, 0.6) if full and s.nightfall <= 0.0 else Color(1, 1, 1)
	_style_slot(devour_btn, Color(0.35, 0.1, 0.12) if not s.raise_souls else SLOT_BG, Color(1, 0.45, 0.4) if not s.raise_souls else Color(0.3, 0.25, 0.38))
	_style_slot(raise_btn, Color(0.12, 0.25, 0.2) if s.raise_souls else SLOT_BG, Color(0.5, 1, 0.75) if s.raise_souls else Color(0.3, 0.25, 0.38))
	raise_btn.text = Loc.t("Raise %d/%d") % [s.undead_count(), s.jar_cap]
	for r in pouch_labels:
		pouch_labels[r].text = str(int(s.pouch[r]))
	var rc: int = s.relics.size() * 100 + s.found_relics.size()
	if rc != relic_count:
		relic_count = rc
		_rebuild_relics()
	_update_tooltip()


func _warden_hint() -> String:
	var s = run.state
	var w: Dictionary = s.warden
	var eaten: Dictionary = w["eaten"]
	var diet: Array = []
	for kind in eaten:
		diet.append("%d %s" % [int(eaten[kind]), Loc.t(D.HERO_CLASSES[kind]["name"])])
	var abil: Array = []
	for a in w.get("abilities", []):
		abil.append(Loc.t(run.warden.ability_def(a)["name"]))
	var t := "%s, %s\n%s" % [w["name"], w["title"], Loc.t("If the Warden falls, the run is over.")]
	t += Loc.t("\n\nEaten: ") + (", ".join(diet) if not diet.is_empty() else Loc.t("nothing yet"))
	if not abil.is_empty():
		t += Loc.t("\nAbilities: ") + ", ".join(abil)
	if w.get("growth", false):
		t += Loc.t("\nXP: %d / %d") % [int(w["xp"]), run.warden.xp_to_next()]
	return t


func _stat_hint(k: String) -> String:
	const DESC := {
		"dmg": "Damage dealt with every blow.",
		"def": "Removed from every hit the Warden takes.",
		"regen": "Health restored every second.",
		"vamp": "Share of dealt damage returned as health.",
		"evade": "Chance to avoid a blow completely.",
		"counter": "Chance to strike back when hit.",
	}
	return "%s\n%s" % [Loc.t(D.STATS[k]["name"]), Loc.t(DESC[k])]


func _gear_hint(i: int) -> String:
	var w: Dictionary = run.state.warden
	var slot: String = str(w["slots"][i])
	var gear: Dictionary = w["gear"]
	if not gear.has(i):
		return Loc.t("%s: empty") % Loc.t(slot.capitalize())
	var it: Dictionary = gear[i]
	return "%s  (%s)\n%s\n\n%s" % [it["name"], Loc.t(slot.capitalize()), LootSystem.describe(it).replace(", ", "\n"),
		Loc.t("Drag into the bag to take it off.")]


func show_end(outcome: String, payout: Dictionary, pct: float, kept: Array, lost: Array) -> void:
	tooltip.visible = false
	level_panel.visible = false
	var s = run.state
	var head := ""
	match outcome:
		"victory":
			head = Loc.t("ACT CLEARED\n%s has been devoured.") % Loc.t(D.ACTS[s.act]["boss"])
		"sleep":
			head = Loc.t("THE DUNGEON SLEEPS\nYou keep %d%% of the harvest.") % int(pct * 100.0)
		_:
			head = Loc.t("THE WARDEN FALLS\nOnly %d%% of the harvest remains.") % int(pct * 100.0)
	var gains: Array = []
	for k in payout:
		gains.append("+%d %s" % [int(payout[k]), Loc.t(D.RESOURCES[k]["name"])])
	var text := Loc.t("%s\n\nDays: %d   Travelers taken: %d\n%s") % [head, s.day, s.kills, "   ".join(gains)]
	for r in kept:
		text += Loc.t("\nNew relic: %s") % Loc.t(D.RELICS[r]["name"])
	for r in lost:
		text += Loc.t("\nLost in the dark: %s") % Loc.t(D.RELICS[r]["name"])
	end_label.text = text
	for c in end_buttons.get_children():
		c.queue_free()
	if outcome == "victory":
		var cont := UI.button(Loc.t("Continue"))
		cont.pressed.connect(func(): run.continue_after_victory())
		end_buttons.add_child(cont)
	var lair := UI.button(Loc.t("Return to the Lair"))
	lair.pressed.connect(func(): run.go_to("res://scenes/lair.tscn"))
	end_buttons.add_child(lair)
	var again := UI.button(Loc.t("New run"))
	again.pressed.connect(func(): run.go_to("res://scenes/prepare.tscn"))
	end_buttons.add_child(again)
	end_panel.visible = true


func _worn_text(slot: String) -> String:
	if not run.warden.can_wear(slot):
		return Loc.t("this Warden has no %s slot") % Loc.t(slot.capitalize())
	var idx: int = run.warden.slot_for(slot)
	var gear: Dictionary = run.state.warden["gear"]
	if not gear.has(idx):
		return Loc.t("nothing")
	var it: Dictionary = gear[idx]
	return "%s  %s" % [it["name"], LootSystem.describe(it)]


func show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(banner, "modulate:a", 0.0, 1.2)


func _on_log() -> void:
	var lines: Array = run.state.log_lines
	log_label.text = "\n".join(lines.slice(maxi(0, lines.size() - 5)))


# ============================================================ tooltip

func _update_tooltip() -> void:
	var s = run.state
	if s.game_over or level_panel.visible:
		tooltip.visible = false
		return
	var lines: Array = []
	if hint_owner != null and is_instance_valid(hint_owner) and hint_owner.is_visible_in_tree():
		lines.append(str(hint_text.call()))
	else:
		hint_owner = null
		_map_lines(s, lines)
	if lines.is_empty():
		tooltip.visible = false
		return
	var text := "\n".join(lines)
	if text != tooltip_label.text:
		# measure on one line first; wrap only long hints
		tooltip_label.text = text
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tooltip_label.custom_minimum_size.x = 0
		tooltip.size = Vector2.ZERO
		tooltip.reset_size()
		if tooltip.size.x > 360:
			tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tooltip_label.custom_minimum_size.x = 340
			tooltip.size = Vector2.ZERO
			tooltip.reset_size()
	tooltip.visible = true
	var mp: Vector2 = get_viewport().get_mouse_position() + Vector2(16, 16)
	var vp := get_viewport().get_visible_rect().size
	if mp.x + tooltip.size.x > vp.x - 4:
		mp.x = get_viewport().get_mouse_position().x - tooltip.size.x - 12
	if mp.y + tooltip.size.y > vp.y - 4:
		mp.y = get_viewport().get_mouse_position().y - tooltip.size.y - 12
	tooltip.position = mp


func _map_lines(s, lines: Array) -> void:
	var cell: Vector2i = run.view.mouse_cell()
	if s.path_lookup.has(cell):
		var t: int = s.path_lookup[cell]
		var card: String = s.card_at(t)
		if t == 0:
			lines.append(Loc.t("The door: travelers come in here. Three laps and they find the way out."))
		elif card != "":
			lines.append("%s: %s" % [Loc.t(D.CARDS[card]["name"]), Loc.t(D.CARDS[card]["desc"])])
		elif t >= s.loop_size:
			lines.append(Loc.t("Side passage (the Warden never walks here)"))
		if s.sanctified.has(t):
			lines.append(Loc.t("Sanctified by the Archon: its monsters cannot strike for %ds.") % int(ceil(s.sanctified[t])))
		if s.fires.has(t):
			lines.append(Loc.t("Burning: %ds left. Click to quench (%d Blood).") % [int(ceil(s.fires[t]["left"])), D.QUENCH_BLOOD])
		if s.forks.has(t):
			lines.append(Loc.t("Fork: each traveler picks a branch by personality."))
		if s.warden_at(t):
			lines.append(Loc.t("%s  %d/%d HP  %.1f dmg") % [s.warden["name"], int(s.warden["hp"]), int(s.warden["max_hp"]), s.warden["dmg"]])
		for u in s.alive_units(t):
			lines.append(Loc.t("%s  %d/%d HP  %.1f dmg") % [Loc.t(u["name"]), int(u["hp"]), int(u["max_hp"]), u["dmg"]])
		for h in s.travelers_at(t):
			var trait_id: String = h["trait"]
			var tr_txt := "" if trait_id == "" else "  [%s]" % Loc.t(D.TRAITS[trait_id]["name"])
			lines.append(Loc.t("%s (%s)%s  %d/%d HP  lap %d/%d") % [s.hero_name(h), Loc.t(D.HERO_CLASSES[h["cls"]]["name"]), tr_txt,
				int(h["hp"]), int(h["max_hp"]), int(h["laps"]), run.heroes_sys.escape_laps()])
	elif s.scenery.has(cell):
		var id: String = s.scenery[cell]
		lines.append("%s: %s" % [Loc.t(D.CARDS[id]["name"]), Loc.t(D.CARDS[id]["desc"])])
	elif cell == s.heart_cell:
		lines.append(Loc.t("The dungeon's heart. It hungers."))
		if s.act == 4:
			lines.append(Loc.t("Night: %d%%. Click when full to let it fall.") % int(s.night))
