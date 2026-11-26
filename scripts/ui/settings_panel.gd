extends Control
## Settings overlay: volume sliders, language, planning auto-pause, fullscreen.
## Used from the main menu and from a run (Esc). Emits `closed` when dismissed.

signal closed

const UI = preload("res://scripts/ui/ui_style.gd")

var allow_language := true  # changing language mid-run would leave half the screen untranslated
var language_changed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = Vector2(1280, 720)
	add_child(shade)

	var panel := UI.panel()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.position = Vector2(380, 120)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UI.title(Loc.t("SETTINGS"), 28, true))

	v.add_child(_slider_row(Loc.t("Music"), Meta.music_volume, func(x: float):
		Meta.music_volume = x
	))
	v.add_child(_slider_row(Loc.t("Sound"), Meta.sfx_volume, func(x: float):
		Meta.sfx_volume = x
	, true))

	if allow_language:
		var lang_row := HBoxContainer.new()
		lang_row.add_theme_constant_override("separation", 8)
		var ll := UI.label(Loc.t("Language"), 16)
		ll.custom_minimum_size.x = 150
		lang_row.add_child(ll)
		for code in Loc.LANGUAGES:
			var b := UI.button(str(Loc.LANGUAGES[code]), Vector2(140, 38))
			b.add_theme_font_size_override("font_size", 15)
			if code == Loc.lang:
				b.add_theme_stylebox_override("normal", UI.frame(Color(0.25, 0.14, 0.34), UI.ACCENT))
			var c: String = code
			b.pressed.connect(func():
				if Loc.lang != c:
					Loc.set_language(c)
					language_changed = true
					_close()
			)
			lang_row.add_child(b)
		v.add_child(lang_row)

	v.add_child(_check(Loc.t("Planning mode: time stops while you hold a card or an item"), Meta.auto_pause, func(on: bool):
		Meta.auto_pause = on
	))
	v.add_child(_check(Loc.t("Fullscreen"), Meta.fullscreen, func(on: bool):
		Meta.fullscreen = on
		Meta.apply_window()
	))

	var done := UI.primary(Loc.t("Done"), Vector2(220, 46))
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close)
	v.add_child(done)


func _slider_row(text: String, value: float, on_change: Callable, click_preview: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UI.label(text, 16)
	l.custom_minimum_size.x = 150
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(250, 28)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	var track := UI.frame(Color(0.12, 0.09, 0.16), Color(0.35, 0.26, 0.45), 1, 4, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	sl.add_theme_stylebox_override("slider", track)
	var fill := UI.frame(Color(0.6, 0.42, 0.85), Color(0, 0, 0, 0), 0, 4, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(sl)
	var pct := UI.label("%d%%" % int(round(value * 100.0)), 15, Color(1, 1, 1, 0.7))
	pct.custom_minimum_size.x = 50
	row.add_child(pct)
	sl.value_changed.connect(func(x: float):
		on_change.call(x)
		pct.text = "%d%%" % int(round(x * 100.0))
	)
	sl.drag_ended.connect(func(_changed: bool):
		Meta.save_game()
		if click_preview:
			Sfx.play("click")
	)
	return row


func _check(text: String, on: bool, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 15)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size.x = 480
	c.toggled.connect(func(x: bool):
		Sfx.play("click")
		on_toggle.call(x)
		Meta.save_game()
	)
	return c


func _close() -> void:
	Meta.save_game()
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
