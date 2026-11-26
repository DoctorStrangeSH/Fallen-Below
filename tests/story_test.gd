extends Node
## Story pages advance on a mouse click. godot --headless res://tests/story_test.tscn

var story
var step := 0


func _ready() -> void:
	Meta.no_save = true
	Meta.pending_story = "intro"
	story = load("res://scenes/story.tscn").instantiate()
	add_child(story)


func _process(_d: float) -> void:
	step += 1
	if step == 5 or step == 7:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = Vector2(640, 300)
		get_viewport().push_input(e)
	if step == 10:
		print("STORY TEST: page index after 2 clicks = %d (%s)" % [story.index, "PASS" if story.index == 2 else "FAIL"])
		get_tree().quit()
