extends Node
## UI smoke test with simulated mouse: drag loot onto a gear slot, gear back to the bag,
## a card onto the map, Esc settings. godot --headless res://tests/ui_test.tscn

const D = preload("res://scripts/data/game_data.gd")

var run
var step := 0
var fails := 0


func _ready() -> void:
	Meta.no_save = true
	Meta.auto_pause = true
	run = load("res://scenes/run.tscn").instantiate()
	add_child(run)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e)
	Input.warp_mouse(pos)


func _check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> void:
	step += 1
	var s = run.state
	var hud = run.hud
	match step:
		5:
			s.inventory.clear()
			var item: Dictionary = run.loot.make_item({"cls": "seeker", "boss": false})
			while not run.warden.can_wear(item["slot"]):
				item = run.loot.make_item({"cls": "seeker", "boss": false})
			s.inventory.append(item)
			s.inventory_changed.emit()
			set_meta("item", item)
		8:
			var from: Vector2 = (hud.loot_boxes[0] as Control).get_global_rect().get_center()
			_mouse(from, true)
			_move(from + Vector2(20, 5))
		9:
			_check("auto-pause while dragging", s.time_stopped())
			var item: Dictionary = get_meta("item")
			var slot_idx: int = s.warden["slots"].find(item["slot"])
			set_meta("slot", slot_idx)
			var to: Vector2 = (hud.gear_boxes[slot_idx] as Control).get_global_rect().get_center()
			_move(to)
			_mouse(to, false)
		11:
			var gear: Dictionary = s.warden["gear"]
			_check("loot dragged onto gear slot", gear.get(get_meta("slot"), {}) == get_meta("item"))
			_check("time runs again", not s.time_stopped())
			var from: Vector2 = (hud.gear_boxes[get_meta("slot")] as Control).get_global_rect().get_center()
			_mouse(from, true)
			_move(from + Vector2(0, 30))
		12:
			var to: Vector2 = (hud.loot_boxes[2] as Control).get_global_rect().get_center()
			_move(to)
			_mouse(to, false)
		14:
			_check("gear dragged back into the bag", s.inventory.has(get_meta("item")))
			s.hand = ["crypt"]
			s.hand_changed.emit()
		16:
			var from: Vector2 = (hud.hand_box.get_child(0) as Control).get_global_rect().get_center()
			_mouse(from, true)
			_move(from + Vector2(0, -40))
			var free := -1
			for t in range(1, s.loop_size):
				if s.card_at(t) == "":
					free = t
					break
			set_meta("tile", free)
			var to: Vector2 = run.view.cell_center(s.cell_of(free))
			_move(to)
		17:
			_mouse(run.view.cell_center(s.cell_of(get_meta("tile"))), false)
		19:
			_check("card dragged onto the map", s.card_at(get_meta("tile")) == "crypt")
			var k := InputEventKey.new()
			k.keycode = KEY_ESCAPE
			k.pressed = true
			get_viewport().push_input(k)
		21:
			_check("Esc opens settings and pauses", hud.has_node("Settings") and s.paused)
			print("UI TEST: %d failed" % fails)
			get_tree().quit()
