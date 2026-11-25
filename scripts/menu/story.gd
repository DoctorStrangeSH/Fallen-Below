extends Control
## Story pages: text fades in, click or press any key to continue.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")

var pages: Array = []
var index := 0
var text_label: Label
var hint: Label


func _ready() -> void:
	Music.play("story")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.background(self)
	pages = D.STORY.get(Meta.pending_story, [])

	text_label = UI.label("", 24, Color(0.92, 0.88, 0.95))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.position = Vector2(190, 160)
	text_label.size = Vector2(900, 360)
	add_child(text_label)

	hint = UI.label("click to continue   ·   Esc to skip", 14, Color(1, 1, 1, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 640)
	hint.size = Vector2(1280, 30)
	add_child(hint)

	if pages.is_empty():
		_finish.call_deferred()
	else:
		_show_page()


func _show_page() -> void:
	text_label.text = pages[index]
	text_label.modulate.a = 0.0
	create_tween().tween_property(text_label, "modulate:a", 1.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			_finish()
		else:
			_next()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_next()


func _next() -> void:
	index += 1
	if index >= pages.size():
		_finish()
	else:
		_show_page()


var finished := false


func _finish() -> void:
	if finished:
		return
	finished = true
	var next_scene: String = Meta.story_next
	if next_scene == "":
		next_scene = "res://scenes/main_menu.tscn"
	Meta.pending_story = ""
	Meta.story_next = ""
	get_tree().change_scene_to_file(next_scene)
