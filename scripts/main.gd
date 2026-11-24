extends Node2D
## Fallen Below — prototype M0.
## Heroes walk a loop through your dungeon. Place cards, kill heroes,
## and decide the fate of their souls. All graphics are primitives for now.

const CELL := 48
const MAP_OFFSET := Vector2(40, 70)
const LOOP_MIN := Vector2i(1, 0)
const LOOP_MAX := Vector2i(23, 9)
const DAY_LENGTH := 18.0
const COMBAT_TICK := 0.6
const HAND_MAX := 7
const HEART_MAX := 20
const BOSS_THREAT := 100.0
const FLEE_LOOT := 3
const BETRAY_CHANCE := 0.08
const RESTORE_COST := 10

const CARDS := {
	"crypt": {"name": "Crypt", "kind": "path", "color": Color(0.55, 0.5, 0.7), "desc": "Room. 2 Skeletons, respawn daily."},
	"spider": {"name": "Spider Nest", "kind": "path", "color": Color(0.4, 0.6, 0.35), "desc": "Room. 3 Spiders, +1 daily."},
	"spikes": {"name": "Spikes", "kind": "path", "color": Color(0.7, 0.35, 0.3), "desc": "Trap. 5 dmg to each hero passing."},
	"altar": {"name": "Dark Altar", "kind": "scenery", "color": Color(0.6, 0.2, 0.55), "desc": "Beside path. Nearby units +2 dmg."},
	"jar": {"name": "Soul Jar", "kind": "instant", "color": Color(0.3, 0.55, 0.8), "desc": "Instant. +1 undead capacity."},
}
const CARD_WEIGHTS := {"crypt": 3, "spider": 3, "spikes": 3, "altar": 2, "jar": 1}

const HERO_CLASSES := {
	"warrior": {"name": "Warrior", "hp": 30, "dmg": 4.0, "speed": 1.8, "greed": 1, "color": Color(0.9, 0.6, 0.3), "dark": "Death Knight"},
	"mage": {"name": "Mage", "hp": 18, "dmg": 7.0, "speed": 1.8, "greed": 1, "color": Color(0.35, 0.55, 1.0), "dark": "Lich"},
	"rogue": {"name": "Rogue", "hp": 20, "dmg": 5.0, "speed": 2.6, "greed": 2, "color": Color(0.4, 0.85, 0.45), "dark": "Shade"},
	"paladin": {"name": "Paladin", "hp": 38, "dmg": 3.0, "speed": 1.6, "greed": 1, "color": Color(1.0, 0.92, 0.5), "dark": "Fallen Paladin"},
}
const MONSTERS := {
	"skeleton": {"name": "Skeleton", "hp": 12, "dmg": 3.0, "color": Color(0.85, 0.85, 0.78)},
	"spider": {"name": "Spider", "hp": 7, "dmg": 3.0, "color": Color(0.35, 0.3, 0.3)},
}
const FIRST_NAMES := ["Alric", "Brann", "Cedric", "Dara", "Elowen", "Finn", "Greta", "Hector",
	"Isolde", "Jorah", "Kael", "Lyra", "Mira", "Nolan", "Orin", "Petra", "Quinn", "Rowan",
	"Sable", "Tamsin", "Ulric", "Vera", "Wren", "Yorick"]

var rng := RandomNumberGenerator.new()

# --- world state ---
var path: Array[Vector2i] = []
var path_lookup := {}      # Vector2i -> path index
var tiles := []            # path index -> {"card": String, "units": Array}
var scenery := {}          # Vector2i -> card id
var heroes := []
var hand := []
var selected := -1

var day := 1
var day_timer := 0.0
var combat_timer := 0.0
var heart_hp := HEART_MAX
var essence := 0
var jar_cap := 2
var threat := 0.0
var boss_spawned := false
var next_hero_id := 0
var next_party_id := 0
var nemesis_pool := []
var pending_souls := []
var game_over := false
var log_lines := []

# --- ui ---
var ui: CanvasLayer
var info_label: Label
var day_bar: ProgressBar
var threat_bar: ProgressBar
var restore_btn: Button
var log_label: Label
var hand_box: HBoxContainer
var soul_panel: PanelContainer
var soul_label: Label
var raise_btn: Button
var end_panel: PanelContainer
var end_label: Label


func _ready() -> void:
	rng.randomize()
	_build_path()
	_build_ui()
	for i in 4:
		_draw_card()
	_log("Heroes approach. Build your dungeon.")
	_spawn_party()
	_rebuild_hand()
	_refresh_ui()


# ============================================================ setup

func _build_path() -> void:
	for x in range(LOOP_MIN.x, LOOP_MAX.x + 1):
		path.append(Vector2i(x, LOOP_MIN.y))
	for y in range(LOOP_MIN.y + 1, LOOP_MAX.y + 1):
		path.append(Vector2i(LOOP_MAX.x, y))
	for x in range(LOOP_MAX.x - 1, LOOP_MIN.x - 1, -1):
		path.append(Vector2i(x, LOOP_MAX.y))
	for y in range(LOOP_MAX.y - 1, LOOP_MIN.y, -1):
		path.append(Vector2i(LOOP_MIN.x, y))
	for i in path.size():
		path_lookup[path[i]] = i
		tiles.append({"card": "", "units": []})


func _style(color: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(3)
	return sb


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var top := HBoxContainer.new()
	top.position = Vector2(40, 16)
	top.add_theme_constant_override("separation", 14)
	ui.add_child(top)

	info_label = Label.new()
	top.add_child(info_label)

	var dl := Label.new()
	dl.text = "Day"
	top.add_child(dl)
	day_bar = ProgressBar.new()
	day_bar.custom_minimum_size = Vector2(120, 20)
	day_bar.max_value = DAY_LENGTH
	day_bar.show_percentage = false
	top.add_child(day_bar)

	var tl := Label.new()
	tl.text = "Threat"
	top.add_child(tl)
	threat_bar = ProgressBar.new()
	threat_bar.custom_minimum_size = Vector2(160, 20)
	threat_bar.max_value = BOSS_THREAT
	threat_bar.show_percentage = false
	top.add_child(threat_bar)

	restore_btn = Button.new()
	restore_btn.text = "Restore Heart (%d essence)" % RESTORE_COST
	restore_btn.pressed.connect(_on_restore)
	top.add_child(restore_btn)

	log_label = Label.new()
	log_label.position = MAP_OFFSET + Vector2(2.3 * CELL, 1.2 * CELL)
	log_label.add_theme_font_size_override("font_size", 14)
	log_label.modulate = Color(1, 1, 1, 0.8)
	ui.add_child(log_label)

	var hint := Label.new()
	hint.text = "Click a card, then a tile. Right-click to cancel. Rooms/traps go on the path, altars beside it."
	hint.position = Vector2(40, 556)
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.6)
	ui.add_child(hint)

	hand_box = HBoxContainer.new()
	hand_box.position = Vector2(40, 584)
	hand_box.add_theme_constant_override("separation", 8)
	ui.add_child(hand_box)

	# soul choice
	soul_panel = PanelContainer.new()
	soul_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.05, 0.12, 0.96), Color(0.6, 0.4, 0.9)))
	soul_panel.position = Vector2(390, 200)
	soul_panel.custom_minimum_size = Vector2(500, 0)
	soul_panel.visible = false
	ui.add_child(soul_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	soul_panel.add_child(sv)
	soul_label = Label.new()
	soul_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	soul_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(soul_label)
	raise_btn = Button.new()
	raise_btn.pressed.connect(_on_soul_choice.bind("raise"))
	sv.add_child(raise_btn)
	var absorb_btn := Button.new()
	absorb_btn.text = "Absorb  (+5 essence)"
	absorb_btn.pressed.connect(_on_soul_choice.bind("absorb"))
	sv.add_child(absorb_btn)
	var inter_btn := Button.new()
	inter_btn.text = "Interrogate  (+2 cards, reveal next party)"
	inter_btn.pressed.connect(_on_soul_choice.bind("interrogate"))
	sv.add_child(inter_btn)

	# end screen
	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.03, 0.08, 0.97), Color(0.9, 0.8, 0.4)))
	end_panel.position = Vector2(440, 240)
	end_panel.custom_minimum_size = Vector2(400, 0)
	end_panel.visible = false
	ui.add_child(end_panel)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 12)
	end_panel.add_child(ev)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.add_theme_font_size_override("font_size", 22)
	ev.add_child(end_label)
	var again := Button.new()
	again.text = "New run"
	again.pressed.connect(func(): get_tree().reload_current_scene())
	ev.add_child(again)


# ============================================================ main loop

func _process(delta: float) -> void:
	queue_redraw()
	if game_over or not pending_souls.is_empty():
		return
	day_timer += delta
	if day_timer >= DAY_LENGTH:
		day_timer -= DAY_LENGTH
		_new_day()
	_move_heroes(delta)
	combat_timer += delta
	if combat_timer >= COMBAT_TICK:
		combat_timer -= COMBAT_TICK
		_combat_tick()
	if threat >= BOSS_THREAT and not boss_spawned and not game_over:
		_spawn_boss()
	_refresh_ui()


func _new_day() -> void:
	day += 1
	_draw_card()
	for i in tiles.size():
		var card: String = tiles[i]["card"]
		if card == "crypt":
			while _count_units(i, "Skeleton") < 2:
				tiles[i]["units"].append(_make_monster("skeleton"))
		elif card == "spider":
			if _count_units(i, "Spider") < 4:
				tiles[i]["units"].append(_make_monster("spider"))
	_spawn_party()
	_rebuild_hand()


func _move_heroes(delta: float) -> void:
	var n := path.size()
	for h in heroes.duplicate():
		if h["gone"]:
			continue
		if h["delay"] > 0.0:
			h["delay"] -= delta
			continue
		if not _alive_units(_tile_of(h)).is_empty():
			continue  # fighting
		var old_i: int = int(floor(h["pos"]))
		h["pos"] += h["speed"] * delta
		var new_i: int = int(floor(h["pos"]))
		if new_i == old_i:
			continue
		var t: int = posmod(new_i, n)
		if t == 0:
			_on_lap(h)
			if h["gone"]:
				continue
		_on_enter_tile(h, t)
		if not h["gone"] and not _alive_units(t).is_empty():
			h["pos"] = float(new_i)  # stop at the room entrance


func _on_lap(h: Dictionary) -> void:
	if h["boss"]:
		heart_hp -= 5
		_log("%s strikes your Heart!" % _hero_name(h))
	else:
		heart_hp -= h["greed"]
		h["loot"] += 1
		_log("%s stole gold (%d/%d)." % [_hero_name(h), h["loot"], FLEE_LOOT])
	if heart_hp <= 0:
		heart_hp = 0
		_end_game(false)
		return
	if not h["boss"] and h["loot"] >= FLEE_LOOT:
		_remove_hero(h)
		nemesis_pool.append({"name": h["name"], "cls": h["cls"], "level": h["level"] + 1})
		_log("%s escaped with your gold... They will return." % _hero_name(h))


func _on_enter_tile(h: Dictionary, t: int) -> void:
	if tiles[t]["card"] == "spikes":
		_damage_hero(h, 5.0)


func _combat_tick() -> void:
	var by_tile := {}
	for h in heroes:
		if h["gone"] or h["delay"] > 0.0:
			continue
		var t := _tile_of(h)
		if not by_tile.has(t):
			by_tile[t] = []
		by_tile[t].append(h)

	for t in by_tile.keys():
		var units := _alive_units(t)
		if units.is_empty():
			continue
		var hs: Array = by_tile[t]

		# heroes strike
		for h in hs:
			if h["gone"]:
				continue
			if h["cls"] == "paladin":
				_paladin_heal(hs)
			var target: Dictionary = units[rng.randi() % units.size()]
			var dmg: float = h["dmg"] * (1.3 if h["revenge"] else 1.0)
			if target["undead"] and h["cls"] == "paladin":
				dmg *= 2.0
			target["hp"] -= dmg
		units = _alive_units(t)
		tiles[t]["units"] = units

		# dungeon strikes back
		var bonus := _altar_bonus(t)
		for u in units:
			var alive_h := hs.filter(func(x): return not x["gone"])
			if alive_h.is_empty():
				break
			var target: Dictionary = alive_h[rng.randi() % alive_h.size()]
			var dmg: float = u["dmg"] + bonus
			if u["undead"] and u["party"] == target["party"]:
				if rng.randf() < BETRAY_CHANCE:
					u["hp"] = 0.0
					target["hp"] = minf(target["max_hp"], target["hp"] + 10.0)
					_log("%s remembers %s... and abandons you!" % [u["name"], target["name"]])
					continue
				dmg *= 1.5  # rage of the betrayed
			_damage_hero(target, dmg)
		tiles[t]["units"] = _alive_units(t)


func _paladin_heal(hs: Array) -> void:
	var lowest = null
	for x in hs:
		if x["gone"]:
			continue
		if lowest == null or x["hp"] / x["max_hp"] < lowest["hp"] / lowest["max_hp"]:
			lowest = x
	if lowest != null:
		lowest["hp"] = minf(lowest["max_hp"], lowest["hp"] + 2.0)


func _damage_hero(h: Dictionary, amount: float) -> void:
	if h["gone"]:
		return
	h["hp"] -= amount
	if h["hp"] <= 0.0:
		_kill_hero(h)


func _kill_hero(h: Dictionary) -> void:
	h["death_tile"] = _tile_of(h)
	_remove_hero(h)
	essence += 2
	threat += 5.0
	_draw_card()
	_rebuild_hand()
	if h["boss"]:
		_log("%s has fallen!" % _hero_name(h))
		_end_game(true)
		return
	pending_souls.append(h)
	_show_soul_choice()


func _remove_hero(h: Dictionary) -> void:
	h["gone"] = true
	heroes = heroes.filter(func(x): return x["id"] != h["id"])


# ============================================================ spawning

func _make_hero(cls: String, hero_name: String, mult: float, party: int, idx: int) -> Dictionary:
	var base: Dictionary = HERO_CLASSES[cls]
	var hp: float = round(base["hp"] * mult)
	var h := {
		"id": next_hero_id, "name": hero_name, "cls": cls, "title": "",
		"hp": hp, "max_hp": hp, "dmg": base["dmg"] * mult,
		"speed": base["speed"], "greed": base["greed"], "color": base["color"],
		"party": party, "pos": 0.0, "delay": idx * 0.8, "loot": 0, "level": 0,
		"revenge": false, "nemesis": false, "boss": false, "gone": false, "death_tile": 0,
	}
	next_hero_id += 1
	heroes.append(h)
	return h


func _spawn_party() -> void:
	var pid := next_party_id
	next_party_id += 1
	var size := clampi(1 + day / 3, 1, 4)
	var mult := 1.0 + 0.12 * (day - 1)
	for i in size:
		var cls: String = HERO_CLASSES.keys()[rng.randi() % HERO_CLASSES.size()]
		_make_hero(cls, FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], mult, pid, i)
	if not nemesis_pool.is_empty() and rng.randf() < 0.6:
		var nem: Dictionary = nemesis_pool.pop_front()
		var h := _make_hero(nem["cls"], nem["name"], mult * (1.2 + 0.25 * nem["level"]), pid, size)
		h["nemesis"] = true
		h["level"] = nem["level"]
		h["title"] = "the Vengeful"
		_log("NEMESIS: %s has returned (lvl %d)!" % [_hero_name(h), h["level"]])
	_log("Day %d: a party of %d enters." % [day, size])


func _spawn_boss() -> void:
	boss_spawned = true
	var h := _make_hero("paladin", "Aurelia", 1.0, next_party_id, 0)
	next_party_id += 1
	h["boss"] = true
	h["title"] = "the Lightbringer"
	h["hp"] = 120.0 + day * 10.0
	h["max_hp"] = h["hp"]
	h["dmg"] = 6.0 + day * 0.5
	h["speed"] = 1.2
	h["color"] = Color(1, 1, 1)
	_log("THE LIGHTBRINGER COMES. Kill her to win.")


func _make_monster(id: String) -> Dictionary:
	var m: Dictionary = MONSTERS[id]
	return {"name": m["name"], "hp": float(m["hp"]), "max_hp": float(m["hp"]), "dmg": m["dmg"],
		"color": m["color"], "undead": false, "party": -1}


# ============================================================ cards

func _draw_card() -> void:
	if hand.size() >= HAND_MAX:
		essence += 1
		return
	var total := 0
	for k in CARD_WEIGHTS:
		total += CARD_WEIGHTS[k]
	var roll := rng.randi() % total
	for k in CARD_WEIGHTS:
		roll -= CARD_WEIGHTS[k]
		if roll < 0:
			hand.append(k)
			return


func _rebuild_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	for i in hand.size():
		var id: String = hand[i]
		var def: Dictionary = CARDS[id]
		var btn := Button.new()
		btn.text = "%s\n\n%s" % [def["name"], def["desc"]]
		btn.custom_minimum_size = Vector2(160, 110)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 13)
		var col: Color = def["color"].darkened(0.45)
		var border := Color(1, 1, 1) if i == selected else col.lightened(0.3)
		btn.add_theme_stylebox_override("normal", _style(col, border))
		btn.add_theme_stylebox_override("hover", _style(col.lightened(0.15), border))
		btn.add_theme_stylebox_override("pressed", _style(col.lightened(0.25), Color(1, 1, 1)))
		btn.pressed.connect(_on_card_pressed.bind(i))
		hand_box.add_child(btn)


func _on_card_pressed(i: int) -> void:
	if game_over or not pending_souls.is_empty():
		return
	var id: String = hand[i]
	if CARDS[id]["kind"] == "instant":
		if id == "jar":
			jar_cap += 1
			_log("Soul capacity: %d." % jar_cap)
		hand.remove_at(i)
		selected = -1
	else:
		selected = -1 if selected == i else i
	_rebuild_hand()
	_refresh_ui()


func _can_place(id: String, cell: Vector2i) -> bool:
	var kind: String = CARDS[id]["kind"]
	if kind == "path":
		if not path_lookup.has(cell):
			return false
		var idx: int = path_lookup[cell]
		return idx != 0 and tiles[idx]["card"] == ""
	if kind == "scenery":
		if path_lookup.has(cell) or scenery.has(cell):
			return false
		if cell.x < 0 or cell.y < 0 or cell.x > LOOP_MAX.x + 1 or cell.y > LOOP_MAX.y:
			return false
		for nb in _neighbors(cell):
			if path_lookup.has(nb):
				return true
	return false


func _place(id: String, cell: Vector2i) -> void:
	if CARDS[id]["kind"] == "path":
		var idx: int = path_lookup[cell]
		tiles[idx]["card"] = id
		if id == "crypt":
			for k in 2:
				tiles[idx]["units"].append(_make_monster("skeleton"))
		elif id == "spider":
			for k in 3:
				tiles[idx]["units"].append(_make_monster("spider"))
	else:
		scenery[cell] = id
	threat += 8.0
	hand.remove_at(selected)
	selected = -1
	_rebuild_hand()
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		selected = -1
		_rebuild_hand()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if game_over or not pending_souls.is_empty() or selected < 0 or selected >= hand.size():
		return
	var cell := _mouse_cell()
	if _can_place(hand[selected], cell):
		_place(hand[selected], cell)


# ============================================================ souls

func _show_soul_choice() -> void:
	if pending_souls.is_empty():
		soul_panel.visible = false
		return
	var h: Dictionary = pending_souls[0]
	var dark: String = HERO_CLASSES[h["cls"]]["dark"]
	var used := _undead_count()
	soul_label.text = "%s the %s has fallen.\nTheir soul is yours." % [_hero_name(h), HERO_CLASSES[h["cls"]]["name"]]
	raise_btn.text = "Raise as %s  (undead %d/%d)" % [dark, used, jar_cap]
	raise_btn.disabled = used >= jar_cap
	soul_panel.visible = true


func _on_soul_choice(choice: String) -> void:
	if pending_souls.is_empty():
		return
	var h: Dictionary = pending_souls.pop_front()
	match choice:
		"raise":
			var dark: String = HERO_CLASSES[h["cls"]]["dark"]
			var hp: float = round(h["max_hp"] * 0.8)
			var unit := {
				"name": "%s %s" % [dark, h["name"]], "hp": hp, "max_hp": hp,
				"dmg": h["dmg"] * 1.1, "color": h["color"].darkened(0.55),
				"undead": true, "party": h["party"],
			}
			tiles[h["death_tile"]]["units"].append(unit)
			var avengers := 0
			for x in heroes:
				if x["party"] == h["party"]:
					x["revenge"] = true
					avengers += 1
			_log("%s rises to serve you." % unit["name"])
			if avengers > 0:
				_log("Their friends swear revenge!")
		"absorb":
			essence += 5
		"interrogate":
			_draw_card()
			_draw_card()
			_log("%s talks: tomorrow brings %d heroes." % [h["name"], clampi(1 + (day + 1) / 3, 1, 4)])
	_rebuild_hand()
	_show_soul_choice()
	_refresh_ui()


func _on_restore() -> void:
	if essence >= RESTORE_COST and heart_hp < HEART_MAX:
		essence -= RESTORE_COST
		heart_hp = mini(HEART_MAX, heart_hp + 5)
		_refresh_ui()


func _end_game(win: bool) -> void:
	game_over = true
	soul_panel.visible = false
	if win:
		end_label.text = "VICTORY\nThe Lightbringer is dead.\nSurvived %d days." % day
	else:
		end_label.text = "DEFEAT\nYour treasury is empty.\nSurvived %d days." % day
	end_panel.visible = true


# ============================================================ helpers

func _tile_of(h: Dictionary) -> int:
	return posmod(int(floor(h["pos"])), path.size())


func _alive_units(t: int) -> Array:
	return tiles[t]["units"].filter(func(u): return u["hp"] > 0.0)


func _count_units(t: int, unit_name: String) -> int:
	var c := 0
	for u in tiles[t]["units"]:
		if u["name"] == unit_name and u["hp"] > 0.0:
			c += 1
	return c


func _undead_count() -> int:
	var c := 0
	for tile in tiles:
		for u in tile["units"]:
			if u["undead"] and u["hp"] > 0.0:
				c += 1
	return c


func _altar_bonus(t: int) -> float:
	var bonus := 0.0
	for nb in _neighbors(path[t]):
		if scenery.get(nb, "") == "altar":
			bonus += 2.0
	return bonus


func _neighbors(c: Vector2i) -> Array:
	var out := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				out.append(c + Vector2i(dx, dy))
	return out


func _hero_name(h: Dictionary) -> String:
	return h["name"] if h["title"] == "" else "%s %s" % [h["name"], h["title"]]


func _cell_center(c: Vector2i) -> Vector2:
	return MAP_OFFSET + Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5


func _mouse_cell() -> Vector2i:
	var p := (get_global_mouse_position() - MAP_OFFSET) / CELL
	return Vector2i(floori(p.x), floori(p.y))


func _hero_world_pos(h: Dictionary) -> Vector2:
	var n := path.size()
	var p: float = h["pos"]
	var i := int(floor(p))
	var a := _cell_center(path[posmod(i, n)])
	var b := _cell_center(path[posmod(i + 1, n)])
	return a.lerp(b, p - i)


func _log(msg: String) -> void:
	log_lines.append(msg)
	while log_lines.size() > 8:
		log_lines.pop_front()
	if log_label:
		log_label.text = "\n".join(log_lines)


func _refresh_ui() -> void:
	info_label.text = "Day %d    Heart %d/%d    Essence %d    Undead %d/%d    Nemeses %d" % [
		day, heart_hp, HEART_MAX, essence, _undead_count(), jar_cap, nemesis_pool.size()]
	day_bar.value = day_timer
	threat_bar.value = threat
	restore_btn.disabled = essence < RESTORE_COST or heart_hp >= HEART_MAX or game_over


# ============================================================ drawing

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(get_viewport_rect(), Color(0.06, 0.05, 0.08))

	# floor grid
	for x in range(0, LOOP_MAX.x + 2):
		for y in range(0, LOOP_MAX.y + 1):
			var r := Rect2(MAP_OFFSET + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			draw_rect(r, Color(0.1, 0.09, 0.12))
			draw_rect(r, Color(0.13, 0.12, 0.16), false, 1.0)

	# path tiles
	for i in path.size():
		var c := path[i]
		var r := Rect2(MAP_OFFSET + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-2)
		var col := Color(0.24, 0.21, 0.27)
		var card: String = tiles[i]["card"]
		if i == 0:
			col = Color(0.55, 0.45, 0.2)
		elif card != "":
			col = CARDS[card]["color"].darkened(0.35)
		draw_rect(r, col)
		if i == 0:
			draw_string(font, r.position + Vector2(0, 30), "GATE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12)
		elif card != "":
			draw_string(font, r.position + Vector2(0, 14), CARDS[card]["name"].substr(0, 6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(1, 1, 1, 0.7))

	# scenery
	for c in scenery:
		var r := Rect2(MAP_OFFSET + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-6)
		var id: String = scenery[c]
		draw_rect(r, CARDS[id]["color"])
		draw_string(font, r.position + Vector2(0, 24), "ALTAR", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10)

	# heart
	var center := (_cell_center(LOOP_MIN) + _cell_center(LOOP_MAX)) * 0.5 + Vector2(0, 40)
	var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() / 250.0)
	draw_circle(center, 34.0 * pulse, Color(0.5, 0.05, 0.12))
	draw_circle(center, 24.0 * pulse, Color(0.85, 0.15, 0.25))
	draw_string(font, center + Vector2(-60, 58), "HEART %d/%d" % [heart_hp, HEART_MAX], HORIZONTAL_ALIGNMENT_CENTER, 120, 14)

	# placement preview
	if selected >= 0 and selected < hand.size() and pending_souls.is_empty() and not game_over:
		var mc := _mouse_cell()
		var ok := _can_place(hand[selected], mc)
		var r := Rect2(MAP_OFFSET + Vector2(mc) * CELL, Vector2(CELL, CELL))
		draw_rect(r, Color(0.3, 1, 0.4, 0.25) if ok else Color(1, 0.2, 0.2, 0.2))
		draw_rect(r, Color(0.3, 1, 0.4) if ok else Color(1, 0.3, 0.3), false, 2.0)

	# dungeon units
	for i in tiles.size():
		var units: Array = tiles[i]["units"]
		var k := 0
		for u in units:
			if u["hp"] <= 0.0:
				continue
			var base := MAP_OFFSET + Vector2(path[i]) * CELL
			var p := base + Vector2(6 + (k % 3) * 13, 22 + (k / 3) * 13)
			var sz := 11.0
			if u["undead"]:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(sz + 2, sz + 2)), Color(0.5, 0.9, 1.0))
			draw_rect(Rect2(p, Vector2(sz, sz)), u["color"])
			var frac: float = clampf(u["hp"] / u["max_hp"], 0.0, 1.0)
			draw_rect(Rect2(p + Vector2(0, sz), Vector2(sz * frac, 2)), Color(0.4, 0.9, 1.0))
			k += 1

	# heroes
	var stack := {}
	for h in heroes:
		if h["gone"] or h["delay"] > 0.0:
			continue
		var t := _tile_of(h)
		var n: int = stack.get(t, 0)
		stack[t] = n + 1
		var p := _hero_world_pos(h) + Vector2((n % 2) * 14 - 7, (n / 2) * 14 - 10)
		var rad := 16.0 if h["boss"] else 10.0
		if h["nemesis"] or h["boss"]:
			draw_circle(p, rad + 3, Color(1, 0.2, 0.2))
		draw_circle(p, rad, h["color"])
		var letter: String = HERO_CLASSES[h["cls"]]["name"].substr(0, 1)
		draw_string(font, p + Vector2(-rad, 5), letter, HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 13, Color(0.1, 0.05, 0.05))
		var frac: float = clampf(h["hp"] / h["max_hp"], 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2, 3)), Color(0.2, 0, 0))
		draw_rect(Rect2(p + Vector2(-rad, -rad - 6), Vector2(rad * 2 * frac, 3)), Color(1, 0.3, 0.3))
		if h["revenge"]:
			draw_string(font, p + Vector2(rad, -rad), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.2))
