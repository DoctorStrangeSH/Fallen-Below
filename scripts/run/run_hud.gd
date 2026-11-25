extends CanvasLayer
## Run HUD: top bar, log, hand of cards, soul choice and end-of-run panel.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")

var run  # run.gd

var info_label: Label
var day_bar: ProgressBar
var threat_bar: ProgressBar
var restore_btn: Button
var pause_btn: Button
var speed_btn: Button
var log_label: Label
var hand_box: HBoxContainer
var soul_panel: PanelContainer
var soul_label: Label
var raise_btn: Button
var end_panel: PanelContainer
var end_label: Label


func _ready() -> void:
	_build_top_bar()
	_build_log_and_hand()
	_build_soul_panel()
	_build_end_panel()
	var s = run.state
	s.log_added.connect(_on_log)
	s.hand_changed.connect(rebuild_hand)
	s.souls_changed.connect(show_souls)
	rebuild_hand()
	refresh()


# ---------------------------------------------------------- build

func _build_top_bar() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(40, 16)
	top.add_theme_constant_override("separation", 12)
	add_child(top)

	info_label = Label.new()
	top.add_child(info_label)

	top.add_child(UI.label("Day"))
	day_bar = ProgressBar.new()
	day_bar.custom_minimum_size = Vector2(110, 20)
	day_bar.max_value = D.DAY_LENGTH
	day_bar.show_percentage = false
	top.add_child(day_bar)

	top.add_child(UI.label("Threat"))
	threat_bar = ProgressBar.new()
	threat_bar.custom_minimum_size = Vector2(140, 20)
	threat_bar.max_value = D.BOSS_THREAT
	threat_bar.show_percentage = false
	top.add_child(threat_bar)

	restore_btn = UI.button("Heal Heart (%d ess.)" % D.RESTORE_COST, Vector2(0, 30))
	restore_btn.pressed.connect(func(): run.heal_heart())
	top.add_child(restore_btn)
	pause_btn = UI.button("Pause", Vector2(70, 30))
	pause_btn.pressed.connect(func(): run.toggle_pause())
	top.add_child(pause_btn)
	speed_btn = UI.button("x1", Vector2(50, 30))
	speed_btn.pressed.connect(func(): run.cycle_speed())
	top.add_child(speed_btn)


func _build_log_and_hand() -> void:
	log_label = UI.label("", 14, Color(1, 1, 1, 0.8))
	log_label.position = D.MAP_OFFSET + Vector2(2.3 * D.CELL, 1.2 * D.CELL)
	add_child(log_label)

	var hint := UI.label("Click a card, then a tile. Right-click: cancel. Space: pause. 1/2/3: speed. Rooms/traps on the path, scenery beside it.", 13, Color(1, 1, 1, 0.6))
	hint.position = Vector2(40, 556)
	add_child(hint)

	hand_box = HBoxContainer.new()
	hand_box.position = Vector2(40, 584)
	hand_box.add_theme_constant_override("separation", 8)
	add_child(hand_box)


func _build_soul_panel() -> void:
	soul_panel = PanelContainer.new()
	soul_panel.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.05, 0.12, 0.96), Color(0.6, 0.4, 0.9)))
	soul_panel.position = Vector2(390, 200)
	soul_panel.custom_minimum_size = Vector2(500, 0)
	soul_panel.visible = false
	add_child(soul_panel)
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
	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.03, 0.08, 0.97), Color(0.9, 0.8, 0.4)))
	end_panel.position = Vector2(440, 200)
	end_panel.custom_minimum_size = Vector2(400, 0)
	end_panel.visible = false
	add_child(end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	end_panel.add_child(v)
	end_label = UI.label("", 20)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(end_label)
	var lair := UI.button("Return to the Lair")
	lair.pressed.connect(func(): run.go_to("res://scenes/lair.tscn"))
	v.add_child(lair)
	var again := UI.button("New run")
	again.pressed.connect(func(): run.go_to("res://scenes/run.tscn"))
	v.add_child(again)
	var menu := UI.button("Main menu")
	menu.pressed.connect(func(): run.go_to("res://scenes/main_menu.tscn"))
	v.add_child(menu)


# ---------------------------------------------------------- update

func refresh() -> void:
	var s = run.state
	info_label.text = "Day %d   Heart %d/%d   Essence %d   Undead %d/%d" % [
		s.day, s.heart_hp, s.heart_max, s.essence, s.undead_count(), s.jar_cap]
	day_bar.value = s.day_timer
	threat_bar.value = s.threat
	restore_btn.disabled = s.essence < D.RESTORE_COST or s.heart_hp >= s.heart_max or s.game_over
	pause_btn.text = "Play" if s.paused else "Pause"
	speed_btn.text = "x%d" % int(s.time_scale)


func rebuild_hand() -> void:
	var s = run.state
	for c in hand_box.get_children():
		c.queue_free()
	for i in s.hand.size():
		var id: String = s.hand[i]
		var def: Dictionary = D.CARDS[id]
		var btn := Button.new()
		btn.text = "%s\n\n%s" % [def["name"], def["desc"]]
		btn.custom_minimum_size = Vector2(160, 110)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		var base: Color = def["color"]
		var col := base.darkened(0.45)
		var border := Color(1, 1, 1) if i == s.selected else col.lightened(0.3)
		btn.add_theme_stylebox_override("normal", UI.box(col, border))
		btn.add_theme_stylebox_override("hover", UI.box(col.lightened(0.15), border))
		btn.add_theme_stylebox_override("pressed", UI.box(col.lightened(0.25), Color(1, 1, 1)))
		btn.pressed.connect(func(): run.cards.use_card(i))
		hand_box.add_child(btn)


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


func show_end(win: bool, bones: int) -> void:
	soul_panel.visible = false
	var s = run.state
	var head := "VICTORY\nThe Lightbringer is dead." if win else "DEFEAT\nYour treasury is empty."
	end_label.text = "%s\nDays survived: %d   Heroes slain: %d\n+%d Bones" % [head, s.day, s.kills, bones]
	end_panel.visible = true


func _on_log() -> void:
	log_label.text = "\n".join(run.state.log_lines)
