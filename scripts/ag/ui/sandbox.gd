extends Node
## Stage 03 anatomy sandbox: generate a sprout, grow organs, lay and cut channels.
## godot res://scenes/ag/sandbox.tscn [-- --seed=N --shot=/path.png]
## Keys: 1-5 organs, C channel (Shift+click: auto-route to the network), X cut, D debug damage,
##       R new map, Space pause, Esc / right click: drop the tool.
##       Over an organ: S sleep/wake, P priority, A reabsorb. B drops a pilgrim's body into the Stomach queue.
##       Click an Incubator (no tool) to breed. Z embody Zero, Q Bone Storm, E send one invader, W send a wave.
##       G over a creature or an organ: genetics of its line. Adaptation offers appear bottom right.

const SproutRoot = preload("res://scripts/ag/run/sprout.gd")
const View = preload("res://scripts/ag/ui/anatomy_view.gd")
const Reg = preload("res://scripts/ag/core/registry.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const ResourceBar = preload("res://scripts/ag/ui/resource_bar.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

const TOOLS := ["organ.stomach", "organ.incubator", "organ.nerve_node", "organ.sensor", "organ.regen_tissue", "channel", "cut"]
const STATE_NAMES := {
	"normal": "Working", "disabled": "Cut off from the Heart", "recovering": "Waking up",
	"damaged": "Damaged", "critical": "Critical", "asleep": "Asleep: not enough energy",
	"dormant": "Put to sleep",
}
const PRIORITY_NAMES := ["Low priority", "Normal priority", "High priority"]
const BREEDABLE := ["species.bone_crawler", "species.blood_tick", "species.devourer", "species.nerve_stalker", "species.lymphatic"]
const INVADERS := ["enemy.pilgrim", "enemy.knight", "enemy.burner"]
const UNIT_STATES := {
	"idle": "Waiting", "engage": "Fighting", "protect": "Guarding an organ", "return": "Returning to its post",
	"retreat": "Retreating to heal", "recover": "Healing", "heal": "Mending an ally",
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
var hover_at := Vector2(-1, -1)
var bar: ResourceBar
var breed_panel: PanelContainer
var breed_box: VBoxContainer
var invader_i := 0
var gene_panel: PanelContainer
var gene_box: VBoxContainer
var gene_line := ""
var offer_box: VBoxContainer
var offer_sig := ""
var cam: Camera2D
var shot_zoom := 1.0
var panning := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--zoom="):
			shot_zoom = float(a.substr(7))
		elif a.begins_with("--hover="):
			var xy := a.substr(8).split(",")
			hover_at = Vector2(float(xy[0]), float(xy[1]))
	RenderingServer.set_default_clear_color(Color(0.02, 0.015, 0.025))
	sp = SproutRoot.new()
	add_child(sp)
	view = View.new()
	view.sp = sp
	add_child(view)
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	_build_hud()
	_new_map(seed_value)
	if shot_path != "":
		_demo_layout()
		if shot_zoom != 1.0:
			cam.zoom = Vector2(shot_zoom, shot_zoom)
			cam.position = view.cell_center(sp.organs.cells_of(sp.organs.heart_uid())[0]) + Vector2(60, 0)
		if hover_at.x >= 0.0:
			var m := InputEventMouseMotion.new()
			m.position = hover_at
			m.global_position = hover_at
			get_viewport().push_input(m)
			Input.warp_mouse(hover_at)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("SHOT ", shot_path)
		get_tree().quit()


func _new_map(sd: int) -> void:
	seed_value = sd
	sp.start(sd)
	bar.economy = sp.economy


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	bar = ResourceBar.new()
	bar.position = Vector2(80, 5)
	layer.add_child(bar)
	var tools := HBoxContainer.new()
	tools.position = Vector2(80, 648)
	tools.add_theme_constant_override("separation", 6)
	layer.add_child(tools)
	for i in TOOLS.size():
		var id: String = TOOLS[i]
		var label := ""
		match id:
			"channel": label = Loc.t("Channel")
			"cut": label = Loc.t("Cut")
			_: label = Loc.t(str(Reg.get_def(id).get("name", id)))
		if id.begins_with("organ."):
			label += "  " + _cost_text(Reg.get_def(id).get("cost", {}))
		elif id == "channel":
			label += "  " + _cost_text(Defs.ECONOMY["channel_cost"])
		var b := UI.button("%d  %s" % [i + 1, label], Vector2(120, 40))
		b.add_theme_font_size_override("font_size", 14)
		b.toggle_mode = true
		b.pressed.connect(_select.bind(id))
		tools.add_child(b)
		buttons[id] = b
	breed_panel = UI.panel()
	breed_panel.position = Vector2(1010, 50)
	breed_panel.visible = false
	layer.add_child(breed_panel)
	breed_box = VBoxContainer.new()
	breed_panel.add_child(breed_box)
	gene_panel = UI.panel()
	gene_panel.position = Vector2(90, 50)
	gene_panel.visible = false
	layer.add_child(gene_panel)
	gene_box = VBoxContainer.new()
	gene_panel.add_child(gene_box)
	offer_box = VBoxContainer.new()
	offer_box.position = Vector2(860, 420)
	offer_box.add_theme_constant_override("separation", 6)
	layer.add_child(offer_box)
	info = UI.label("", 14, UI.MUTED)
	info.position = Vector2(80, 698)
	info.size = Vector2(1120, 18)
	layer.add_child(info)
	tip = UI.label("", 14, Color(0.95, 0.92, 1.0))
	tip.add_theme_stylebox_override("normal", UI.box(Color(0.04, 0.03, 0.06, 0.94), Color(0.5, 0.38, 0.65), 4))
	tip.visible = false
	layer.add_child(tip)


func _open_breeding(uid: int) -> void:
	view.selected_uid = uid
	breed_panel.visible = uid >= 0
	for ch in breed_box.get_children():
		ch.queue_free()
	if uid < 0:
		return
	breed_box.add_child(UI.label(Loc.t("Incubator: grow a creature"), 15, UI.GOLD))
	for id in BREEDABLE:
		var d := Reg.get_def(id)
		var row := HBoxContainer.new()
		var b := UI.button("%s  %s" % [Loc.t(str(d["name"])), _cost_text(sp.creatures.breed_cost(id))], Vector2(240, 34))
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func():
			sp.creatures.queue_breed(uid, id))
		tip_bind(b, id)
		row.add_child(b)
		var gb := UI.button(Loc.t("Genes"), Vector2(64, 34))
		gb.add_theme_font_size_override("font_size", 13)
		gb.pressed.connect(func(): _open_genes(id))
		row.add_child(gb)
		breed_box.add_child(row)


func tip_bind(b: Control, species_id: String) -> void:
	b.mouse_entered.connect(func():
		var d := Reg.get_def(species_id)
		var st: Dictionary = d["stats"]
		hover_text = "%s\n%s\n%s\n%s" % [Loc.t(str(d["desc"])),
			Loc.t("Health %d · attack %d · armour %d · speed %.1f") % [int(st["hp"]), int(st["atk"]), int(st["armor"]), float(st["speed"])],
			Loc.t("Grows in %d s · upkeep %s") % [int(d["breed"]["time"]), _cost_text({"resource.energy": st["upkeep"]}, true)],
			_forecast_text(species_id)])
	b.mouse_exited.connect(func(): hover_text = "")


var hover_text := ""


func _forecast_text(species_id: String) -> String:
	var f: Dictionary = sp.genetics.forecast(species_id)
	if f["mutations"].is_empty():
		return Loc.t("Offspring: no mutations in this line yet.")
	var parts: Array = []
	for e in f["mutations"]:
		parts.append("%s %d%%" % [Loc.t(str(Reg.get_def(str(e[0]))["name"])), roundi(float(e[1]) * 100.0)])
	var t := Loc.t("Offspring: %s") % ", ".join(parts)
	for e in f["results"]:
		var rd := Reg.get_def(str(e[0]))
		t += "\n" + (Loc.t("Defect risk: %s %d%%") if Reg.kind_of(str(e[0])) == "defect" else Loc.t("Rare trait chance: %s %d%%")) % [Loc.t(str(rd["name"])), roundi(float(e[1]) * 100.0)]
	return t


## Genetics of a line (species strain or organ type): current mutations and what can grow next.
func _open_genes(line: String) -> void:
	gene_line = line
	gene_panel.visible = line != ""
	for ch in gene_box.get_children():
		ch.queue_free()
	if line == "":
		return
	var is_organ := Reg.kind_of(line) == "organ"
	var present: Array = sp.genetics.line_mutations(line)
	gene_box.add_child(UI.label(Loc.t("Genetics: %s") % Loc.t(str(Reg.get_def(line)["name"])), 15, UI.GOLD))
	gene_box.add_child(UI.label(Loc.t("Mutation slots: %d of %d") % [present.size(), sp.genetics.slots(line)], 13, UI.MUTED))
	for m in present:
		gene_box.add_child(UI.label("• " + Loc.t(str(Reg.get_def(str(m))["name"])), 13, Color(0.75, 0.55, 1.0)))
	var ids: Array = Reg.ids("mutation")
	for m in ids:
		var md := Reg.get_def(m)
		if not (md["targets"] as Array).has("organ" if is_organ else "species") or present.has(m):
			continue
		var ok: Dictionary = sp.genetics.can_mutate(line, m)
		var b := UI.button("%s  %s" % [Loc.t(str(md["name"])), _cost_text(md["cost"])], Vector2(250, 30))
		b.add_theme_font_size_override("font_size", 13)
		b.disabled = not ok["ok"]
		b.pressed.connect(func():
			sp.genetics.mutate(line, m)
			_open_genes(line))
		var desc := str(md.get("organ_desc", md["desc"])) if is_organ else str(md["desc"])
		var drawback := str(md.get("organ_drawback", md["drawback"])) if is_organ else str(md["drawback"])
		var inh := "" if is_organ else "\n" + (Loc.t("Dominant: every offspring inherits it.") if md["inherit"] == "dominant" else Loc.t("Recessive: half of the offspring inherit it."))
		var why := "" if ok["ok"] else "\n" + _reason(ok)
		var tip := "%s\n%s %s%s%s" % [Loc.t(desc), Loc.t("Drawback:"), Loc.t(drawback), inh, why]
		b.mouse_entered.connect(func(): hover_text = tip)
		b.mouse_exited.connect(func(): hover_text = "")
		gene_box.add_child(b)
	var close := UI.button(Loc.t("Close"), Vector2(250, 28))
	close.pressed.connect(func(): _open_genes(""))
	gene_box.add_child(close)


## Adaptation offers: rebuilt only when the set of offers changes.
func _refresh_offers() -> void:
	var sig := ""
	for p in sp.state.proposals:
		sig += str(p["id"]) + ","
	if sig != offer_sig:
		offer_sig = sig
		for ch in offer_box.get_children():
			ch.queue_free()
		for p in sp.state.proposals:
			offer_box.add_child(_offer_card(p))
	offer_box.reset_size()
	offer_box.position = Vector2(1272.0 - offer_box.size.x, 640.0 - offer_box.size.y)
	for card in offer_box.get_children():
		var pid: int = card.get_meta("pid")
		var p: Dictionary = sp.evolution.find(pid)
		if not p.is_empty():
			(card.get_meta("timer") as Label).text = Loc.t("%d s to decide") % ceili(float(p["left"]))


func _offer_card(p: Dictionary) -> PanelContainer:
	var card := UI.panel()
	card.set_meta("pid", int(p["id"]))
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	card.add_child(box)
	var md := Reg.get_def(str(p["mutation"]))
	var line_name := Loc.t(str(Reg.get_def(str(p["line"]))["name"]))
	var title := UI.label(Loc.t("Adaptation: %s for %s") % [Loc.t(str(md["name"])), line_name], 15, UI.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(360, 0)
	box.add_child(title)
	var why: Array = sp.evolution.reason(p)
	var args: Array = []
	for a in why[1]:
		args.append(Loc.t(a) if a is String else a)
	var reason_l := UI.label(Loc.t(str(why[0])) % args, 13, Color(0.95, 0.9, 1.0))
	reason_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_l.custom_minimum_size = Vector2(360, 0)
	box.add_child(reason_l)
	var is_organ := Reg.kind_of(str(p["line"])) == "organ"
	var desc := str(md.get("organ_desc", md["desc"])) if is_organ else str(md["desc"])
	var drawback := str(md.get("organ_drawback", md["drawback"])) if is_organ else str(md["drawback"])
	var eff := UI.label("%s  %s %s" % [Loc.t(desc), Loc.t("Drawback:"), Loc.t(drawback)], 13, UI.MUTED)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.custom_minimum_size = Vector2(360, 0)
	box.add_child(eff)
	var row := HBoxContainer.new()
	var yes := UI.button(Loc.t("Accept · %s") % _cost_text(p["cost"]), Vector2(190, 30))
	yes.add_theme_font_size_override("font_size", 13)
	yes.pressed.connect(func(): sp.evolution.accept(int(p["id"])))
	var no := UI.button(Loc.t("Reject"), Vector2(110, 30))
	no.add_theme_font_size_override("font_size", 13)
	no.pressed.connect(func(): sp.evolution.reject(int(p["id"])))
	row.add_child(yes)
	row.add_child(no)
	var timer := UI.label("", 12, UI.MUTED)
	row.add_child(timer)
	card.set_meta("timer", timer)
	box.add_child(row)
	return card


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
			KEY_S:
				if view.hover_uid >= 0:
					sp.organs.set_dormant(view.hover_uid, not bool(sp.state.organs[view.hover_uid].get("dormant", false)))
			KEY_P:
				if view.hover_uid >= 0:
					sp.organs.cycle_priority(view.hover_uid)
			KEY_A:
				if view.hover_uid >= 0:
					sp.organs.reabsorb(view.hover_uid)
			KEY_B:
				sp.economy.add_body("body.pilgrim")
			KEY_Z:
				sp.creatures.embody_zero()
			KEY_Q:
				sp.creatures.zero_storm()
			KEY_E:
				_send_invader()
			KEY_W:
				for i in 3:
					_send_invader()
			KEY_G:
				var near := _unit_under(view.get_global_mouse_position())
				if near >= 0 and str(sp.state.units[near]["team"]) == "abyss":
					_open_genes(str(sp.state.units[near]["def"]))
				elif view.hover_uid >= 0:
					_open_genes(str(sp.state.organs[view.hover_uid]["def"]))
	elif e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and e.pressed:
		var before := view.get_global_mouse_position()
		var z := clampf(cam.zoom.x * (1.15 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 1.0, 3.5)
		cam.zoom = Vector2(z, z)
		cam.position += before - view.get_global_mouse_position()
		_clamp_cam()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_MIDDLE:
		panning = e.pressed
	elif e is InputEventMouseMotion and panning:
		cam.position -= e.relative / cam.zoom.x
		_clamp_cam()
	elif e is InputEventMouseButton:
		var c := view.cell_at(view.get_global_mouse_position())
		if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if tool != "":
				_select("")
			else:
				sp.organs.cut_channel(c)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			painting = e.pressed
			if e.pressed:
				if tool == "":
					var ou: int = sp.state.grid.organ_at(c) if sp.state.grid.in_bounds(c) else -1
					_open_breeding(ou if ou >= 0 and str(sp.state.organs[ou]["def"]) == "organ.incubator" else -1)
				_apply(c, e.shift_pressed)
	elif e is InputEventMouseMotion:
		var c := view.cell_at(view.get_global_mouse_position())
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


func _clamp_cam() -> void:
	var half := Vector2(640, 360) / cam.zoom.x
	cam.position = cam.position.clamp(half, Vector2(1280, 720) - half)


func _process(delta: float) -> void:
	if sp.state == null:
		return
	var pan := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if pan != Vector2.ZERO:
		cam.position += pan * 600.0 * delta / cam.zoom.x
		_clamp_cam()
	var mouse := get_viewport().get_mouse_position()
	var world := view.get_global_mouse_position()
	var c := view.cell_at(world)
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
		text = Loc.t("Lay a living channel. Shift+click grows the shortest route to the network.") if ok["ok"] else _reason(ok)
	elif tool != "" and tool != "cut":
		var ok: Dictionary = sp.organs.can_place(tool, c)
		view.ghost_ok = ok["ok"]
		var d := Reg.get_def(tool)
		text = Loc.t(str(d["desc"])) + "\n" + Loc.t("Cost: %s · upkeep: %s") % [_cost_text(d.get("cost", {})), _cost_text(d.get("upkeep", {}), true)] if ok["ok"] else _reason(ok)
	elif view.hover_uid >= 0:
		var o: Dictionary = sp.state.organs[view.hover_uid]
		var d := Reg.get_def(str(o["def"]))
		text = "%s — %s  (%d/%d)\n%s\n%s · %s\n%s" % [Loc.t(str(d["name"])), Loc.t(str(STATE_NAMES.get(str(o["state"]), o["state"]))),
			int(ceil(float(o["hp"]))), int(o["max_hp"]), Loc.t(str(d["desc"])),
			Loc.t("Upkeep: %s") % _cost_text(d.get("upkeep", {}), true), Loc.t(PRIORITY_NAMES[int(o.get("priority", 1))]),
			Loc.t("[S] sleep / wake  [P] priority  [A] reabsorb (half the cost back)") if str(o["def"]) != "organ.heart" else ""]
		var og: Array = []
		for m in o.get("mutations", []):
			og.append(Loc.t(str(Reg.get_def(str(m)).get("name", m))))
		if not og.is_empty():
			text += "\n" + Loc.t("Genes: %s") % ", ".join(og)
		text += "\n" + Loc.t("[G] genetics of this organ type")
	elif g.is_entrance(c):
		text = Loc.t("Entrance. Invaders come down here.")
	if text == "" and tool == "":
		var near := _unit_under(world)
		if near >= 0:
			var u: Dictionary = sp.state.units[near]
			var d := Reg.get_def(str(u["def"]))
			text = "%s — %s  (%d/%d)" % [Loc.t(str(d["name"])), Loc.t(str(UNIT_STATES.get(str(u["state"]), u["state"]))), int(ceil(float(u["hp"]))), int(float(u["max_hp"]))]
			var genes: Array = []
			for m in u.get("mutations", []):
				genes.append(Loc.t(str(Reg.get_def(str(m)).get("name", m))))
			for x in u.get("defects", []):
				genes.append(Loc.t(str(Reg.get_def(str(x)).get("name", x))))
			for tr in u.get("traits", []):
				if bool(Reg.get_def(str(tr)).get("rare", false)):
					genes.append(Loc.t(str(Reg.get_def(str(tr)).get("name", tr))))
			if not genes.is_empty():
				text += "\n" + Loc.t("Genes: %s") % ", ".join(genes)
			if str(u["team"]) == "abyss":
				text += "\n" + Loc.t("[G] genetics of this line")
			if str(u["def"]) == "species.zero":
				text += "\n" + Loc.t("Level %d · [Q] Bone Storm %s") % [int(u["level"]), Loc.t("ready") if float(u["storm_cd"]) <= 0.0 else "%d s" % ceili(float(u["storm_cd"]))]
	if hover_text != "":
		text = hover_text
	tip.text = text
	tip.visible = text != ""
	tip.reset_size()
	tip.position = (mouse + Vector2(16, 18)).clamp(Vector2.ZERO, Vector2(1280, 720) - tip.size)
	var working := 0
	for uid in sp.state.organs:
		if sp.economy.is_working(int(uid)):
			working += 1
	info.text = Loc.t("Seed %d · creatures %d · invaders %d · bodies %d · %s · [Z] Zero [Q] storm [E] invader [W] wave [B] body [R] new map [Space] pause") % [
		seed_value, sp.creatures.team_units("abyss").size(), sp.creatures.team_units("order").size(), sp.state.bodies.size(),
		Loc.t("Paused") if sp.state.paused else Loc.t("Running")]
	if view.selected_uid >= 0 and not sp.state.organs.has(view.selected_uid):
		_open_breeding(-1)
	_refresh_offers()
	if sp.state.lost:
		info.text = Loc.t("The Heart Bud is dead. The sprout burns out. [R] new map")


func _unit_under(p: Vector2) -> int:
	var best := -1
	var bd := 12.0
	for uid in sp.state.units:
		var d: float = view.unit_screen_pos(sp.state.units[uid]).distance_to(p)
		if d < bd:
			bd = d
			best = int(uid)
	return best


func _send_invader() -> void:
	var g = sp.state.grid
	var e: Vector2i = g.entrances[invader_i % g.entrances.size()]
	sp.creatures.spawn_enemy(INVADERS[invader_i % INVADERS.size()], e)
	invader_i += 1


func _reason(ok: Dictionary) -> String:
	var r := Loc.t(str(ok["reason"]))
	return r % Loc.t(str(ok["arg"])) if ok.has("arg") else r


static func _short(res: String) -> String:
	match res:
		"resource.biomass": return Loc.t("bio")
		"resource.energy": return Loc.t("en")
		"resource.genome": return Loc.t("gen")
	return res


func _cost_text(cost: Dictionary, per_second: bool = false) -> String:
	if cost.is_empty():
		return Loc.t("none")
	var parts: Array = []
	var keys: Array = cost.keys()
	keys.sort()
	for r in keys:
		parts.append(("%s %s" % [str(snappedf(float(cost[r]), 0.1)).trim_suffix(".0"), _short(str(r))]) + (Loc.t("/s") if per_second else ""))
	return ", ".join(parts)


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
	# sensor in the nearest other hall where it can grow, routed back with a channel
	var rooms: Array = range(g.rooms.size())
	var hcen: Vector2i = g.room_center(g.heart_room)
	rooms.erase(g.heart_room)
	rooms.sort_custom(func(a, b): return (g.room_center(a) - hcen).length_squared() < (g.room_center(b) - hcen).length_squared())
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
	sp.economy.add_body("body.pilgrim")
	for i in 40:
		sp.step()
	# a small garrison and Zero, then an invasion in progress
	sp.economy.apply("resource.biomass", 150.0, "Test")
	sp.economy.apply("resource.genome", 40.0, "Test")
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	var k := 0
	for id in ["species.bone_crawler", "species.devourer", "species.lymphatic", "species.blood_tick", "species.nerve_stalker"]:
		sp.creatures.spawn_creature(id, stand[(k * 3) % stand.size()])
		k += 1
	sp.creatures.embody_zero()
	for i in 4:
		_send_invader()
	for i in 90:
		sp.step()
	for uid in sp.state.organs:
		if str(sp.state.organs[uid]["def"]) == "organ.incubator":
			sp.creatures.queue_breed(int(uid), "species.devourer")
	sp.economy.apply("resource.genome", 60.0, "Test")
	sp.genetics.mutate("species.devourer", "mutation.bone_plate")
	sp.genetics.mutate("species.lymphatic", "mutation.regenerative_tissue")
	# a Burner Priest scorched the Stomach: the organism offers an answer
	for uid in sp.state.organs.keys():
		if str(sp.state.organs[uid]["def"]) == "organ.stomach":
			for i in 14:
				sp.organs.damage(int(uid), 10.0, "fire", "enemy.burner")
				sp.organs.heal(int(uid), 999.0)
	for i in 10:
		sp.step()
	_open_genes("species.devourer")
