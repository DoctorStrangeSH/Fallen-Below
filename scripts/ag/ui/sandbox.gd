extends Node
## Stage 03 anatomy sandbox: generate a sprout, grow organs, lay and cut channels.
## godot res://scenes/ag/sandbox.tscn [-- --seed=N --shot=/path.png]
## Keys: 1-5 organs, C channel (Shift+click: auto-route to the network), X cut, D debug damage,
##       R new map, Space pause, Esc / right click: drop the tool.

const SproutRoot = preload("res://scripts/ag/run/sprout.gd")
const View = preload("res://scripts/ag/ui/anatomy_view.gd")
const Reg = preload("res://scripts/ag/core/registry.gd")
const UI = preload("res://scripts/ui/ui_style.gd")

const TOOLS := ["organ.stomach", "organ.incubator", "organ.nerve_node", "organ.sensor", "organ.regen_tissue", "channel", "cut"]
const STATE_NAMES := {
	"normal": "Working", "disabled": "Cut off from the Heart", "recovering": "Waking up",
	"damaged": "Damaged", "critical": "Critical",
}

var sp: SproutRoot
var view: View
var tool := ""
var info: Label
var tip: Label
var buttons := {}
var seed_value := 1
var painting := false
var shot_path := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
	RenderingServer.set_default_clear_color(Color(0.02, 0.015, 0.025))
	sp = SproutRoot.new()
	add_child(sp)
	view = View.new()
	view.sp = sp
	add_child(view)
	_build_hud()
	_new_map(seed_value)
	if shot_path != "":
		_demo_layout()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("SHOT ", shot_path)
		get_tree().quit()


func _new_map(sd: int) -> void:
	seed_value = sd
	sp.start(sd)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.position = Vector2(80, 656)
	bar.add_theme_constant_override("separation", 6)
	layer.add_child(bar)
	for i in TOOLS.size():
		var id: String = TOOLS[i]
		var label := ""
		match id:
			"channel": label = Loc.t("Channel")
			"cut": label = Loc.t("Cut")
			_: label = Loc.t(str(Reg.get_def(id).get("name", id)))
		var b := UI.button("%d  %s" % [i + 1, label], Vector2(140, 40))
		b.toggle_mode = true
		b.pressed.connect(_select.bind(id))
		bar.add_child(b)
		buttons[id] = b
	info = UI.label("", 14, UI.MUTED)
	info.position = Vector2(80, 702)
	info.size = Vector2(1120, 18)
	layer.add_child(info)
	tip = UI.label("", 14, Color(0.95, 0.92, 1.0))
	tip.add_theme_stylebox_override("normal", UI.box(Color(0.04, 0.03, 0.06, 0.94), Color(0.5, 0.38, 0.65), 4))
	tip.visible = false
	layer.add_child(tip)


func _select(id: String) -> void:
	tool = "" if tool == id else id
	for k in buttons:
		(buttons[k] as Button).set_pressed_no_signal(k == tool)
	view.ghost_def = tool if tool != "" and tool != "cut" else ""


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k >= KEY_1 and k <= KEY_7:
			_select(TOOLS[k - KEY_1])
		match k:
			KEY_C: _select("channel")
			KEY_X: _select("cut")
			KEY_ESCAPE: _select("")
			KEY_SPACE: sp.state.paused = not sp.state.paused
			KEY_R: _new_map(randi() % 100000)
			KEY_D:
				if view.hover_uid >= 0:
					sp.organs.damage(view.hover_uid, 25.0, "physical")
	elif e is InputEventMouseButton:
		var c := view.cell_at(e.position)
		if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if tool != "":
				_select("")
			else:
				sp.organs.cut_channel(c)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			painting = e.pressed
			if e.pressed:
				_apply(c, e.shift_pressed)
	elif e is InputEventMouseMotion:
		var c := view.cell_at(e.position)
		if painting and (tool == "channel" or tool == "cut"):
			_apply(c, false)


func _apply(c: Vector2i, shift: bool) -> void:
	match tool:
		"":
			pass
		"channel":
			if shift:
				for p in sp.organs.channel_route(c):
					sp.organs.lay_channel(p)
			else:
				sp.organs.lay_channel(c)
		"cut":
			sp.organs.cut_channel(c)
		_:
			sp.organs.place(tool, c)


func _process(_d: float) -> void:
	if sp.state == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var c := view.cell_at(mouse)
	var g = sp.state.grid
	view.ghost_cell = c
	view.ghost_route = []
	view.hover_uid = g.organ_at(c) if g.in_bounds(c) else -1
	var text := ""
	if tool == "channel":
		var ok: Dictionary = sp.organs.can_lay_channel(c) if g.in_bounds(c) else {"ok": false, "reason": "Out of bounds."}
		view.ghost_ok = ok["ok"]
		if Input.is_key_pressed(KEY_SHIFT) and g.in_bounds(c):
			view.ghost_route = sp.organs.channel_route(c)
		text = Loc.t("Lay a living channel. Shift+click grows the shortest route to the network.") if ok["ok"] else Loc.t(str(ok["reason"]))
	elif tool != "" and tool != "cut":
		var ok: Dictionary = sp.organs.can_place(tool, c)
		view.ghost_ok = ok["ok"]
		var d := Reg.get_def(tool)
		text = Loc.t(str(d["desc"])) if ok["ok"] else Loc.t(str(ok["reason"]))
	elif view.hover_uid >= 0:
		var o: Dictionary = sp.state.organs[view.hover_uid]
		var d := Reg.get_def(str(o["def"]))
		text = "%s — %s  (%d/%d)\n%s" % [Loc.t(str(d["name"])), Loc.t(str(STATE_NAMES.get(str(o["state"]), o["state"]))),
			int(ceil(float(o["hp"]))), int(o["max_hp"]), Loc.t(str(d["desc"]))]
	elif g.is_entrance(c):
		text = Loc.t("Entrance. Invaders come down here.")
	tip.text = text
	tip.visible = text != ""
	tip.reset_size()
	tip.position = (mouse + Vector2(16, 18)).clamp(Vector2.ZERO, Vector2(1280, 720) - tip.size)
	var working := 0
	for uid in sp.state.organs:
		if str(sp.state.organs[uid]["state"]) != "disabled":
			working += 1
	info.text = Loc.t("Seed %d · organs linked to the Heart: %d of %d · %s · [R] new map  [Space] pause  [D] debug damage") % [
		seed_value, working, sp.state.organs.size(), Loc.t("Paused") if sp.state.paused else Loc.t("Running")]
	if sp.state.lost:
		info.text = Loc.t("The Heart Bud is dead. The sprout burns out. [R] new map")


## Screenshot layout: a working cluster around the Heart, a routed sensor, a cut-off and a damaged organ.
func _demo_layout() -> void:
	var g = sp.state.grid
	var hc: Array = sp.organs.cells_of(sp.organs.heart_uid())
	var order := ["organ.stomach", "organ.incubator", "organ.nerve_node", "organ.regen_tissue"]
	var placed := 0
	for c in hc:
		for d in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(2, 1)]:
			if placed < order.size() and sp.organs.place(order[placed], c + d) >= 0:
				placed += 1
	# sensor in the farthest hall where it can grow, routed back with a channel
	var rooms: Array = range(g.rooms.size())
	var hcen: Vector2i = g.room_center(g.heart_room)
	rooms.sort_custom(func(a, b): return (g.room_center(a) - hcen).length_squared() > (g.room_center(b) - hcen).length_squared())
	var far := -1
	for i in rooms:
		var rect: Rect2i = g.rooms[i]
		for y in range(rect.position.y + 1, rect.end.y - 1):
			for x in range(rect.position.x + 1, rect.end.x - 1):
				if far < 0 and sp.organs.place("organ.sensor", Vector2i(x, y)) >= 0:
					far = i
					for p in sp.organs.channel_route(Vector2i(x, y)):
						sp.organs.lay_channel(p)
		if far >= 0:
			break
	# a second sensor left without a channel (cut off)
	for i in g.rooms.size():
		if i != far and i != g.heart_room and sp.organs.place("organ.sensor", g.room_center(i)) >= 0:
			break
	# damage one organ
	for uid in sp.state.organs:
		if str(sp.state.organs[uid]["def"]) == "organ.stomach":
			sp.organs.damage(int(uid), 70.0)
	for i in 40:
		sp.step()
