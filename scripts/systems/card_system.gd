extends Node
## Drawing, selecting and placing cards, room respawns and secret combos.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func draw_card() -> void:
	_add_to_hand(_random_card())


func _add_to_hand(id: String) -> void:
	if id == "":
		return
	if s.hand.size() >= D.HAND_MAX:
		return  # hand full: the memory is lost
	s.hand.append(id)


func _random_card(exclude: Array = []) -> String:
	var total := 0
	for k in s.card_weights:
		if not exclude.has(k):
			total += int(s.card_weights[k])
	if total <= 0:
		return ""
	var roll := s.rng.randi() % total
	for k in s.card_weights:
		if exclude.has(k):
			continue
		roll -= int(s.card_weights[k])
		if roll < 0:
			return k
	return ""


## Click on a card in hand: instants resolve, others toggle selection.
func use_card(i: int) -> void:
	if s.is_blocked() or i < 0 or i >= s.hand.size():
		return
	var id: String = s.hand[i]
	if D.CARDS[id]["kind"] == "instant":
		if id == "jar":
			s.jar_cap += 1
			s.add_log("Undead servant slots: %d." % s.jar_cap)
		s.hand.remove_at(i)
		s.selected = -1
	else:
		s.selected = -1 if s.selected == i else i
	s.hand_changed.emit()


func selected_id() -> String:
	if s.selected < 0 or s.selected >= s.hand.size():
		return ""
	return s.hand[s.selected]


func can_place(id: String, cell: Vector2i) -> bool:
	if id == "":
		return false
	var kind: String = D.CARDS[id]["kind"]
	if kind == "path":
		if not s.path_lookup.has(cell):
			return false
		var idx: int = s.path_lookup[cell]
		return idx != 0 and s.card_at(idx) == ""
	if kind == "scenery":
		if s.path_lookup.has(cell) or s.scenery.has(cell):
			return false
		if not s.in_grid(cell) or cell == s.heart_cell:
			return false
		for nb in s.neighbors(cell):
			if s.path_lookup.has(nb):
				return true
	return false


func place_selected(cell: Vector2i) -> void:
	var id := selected_id()
	if not can_place(id, cell):
		return
	if D.CARDS[id]["kind"] == "path":
		var idx: int = s.path_lookup[cell]
		s.tiles[idx]["card"] = id
		if id == "crypt":
			_fill_skeletons(idx)
		elif id == "spider":
			for k in 3:
				_spawn(idx, "spider")
		_check_path_combos(idx, id)
	else:
		s.scenery[cell] = id
		_check_scenery_combos(cell, id)
	s.add_threat(D.THREAT_PER_CARD)
	s.hand.remove_at(s.selected)
	s.selected = -1
	s.hand_changed.emit()


func make_monster(id: String) -> Dictionary:
	var m: Dictionary = D.MONSTERS[id]
	return {"name": m["name"], "hp": float(m["hp"]), "max_hp": float(m["hp"]), "dmg": m["dmg"],
		"color": m["color"], "undead": false, "party": -1, "affixes": []}


func spawn_at(t: int, monster_id: String) -> void:
	_spawn(t, monster_id)


func _spawn(t: int, monster_id: String) -> void:
	s.tiles[t]["units"].append(make_monster(monster_id))


func _skeleton_cap(t: int) -> int:
	var card := s.card_at(t)
	if not D.SKELETON_CAP.has(card):
		return 0
	var base: int = D.SKELETON_CAP[card]
	return base + s.scenery_near(t, "graveyard")


func _fill_skeletons(t: int) -> void:
	var cap := _skeleton_cap(t)
	while s.count_units(t, "Skeleton") < cap:
		_spawn(t, "skeleton")


## Daily respawn of room monsters.
func respawn_rooms() -> void:
	for i in s.tiles.size():
		var card := s.card_at(i)
		if D.SKELETON_CAP.has(card):
			_fill_skeletons(i)
		if card == "necropolis" and s.count_units(i, "Bone Golem") == 0:
			_spawn(i, "golem")
		elif card == "mimic" and s.count_units(i, "Mimic") == 0:
			_spawn(i, "mimic")
		elif card == "spider" or card == "queen":
			var hatch := 2 if s.has_relic("brood_eye") else 1
			for k in hatch:
				if s.count_units(i, "Spider") < 4 + hatch:
					_spawn(i, "spider")


# ---------------------------------------------------------- combos

## Middle tile of a straight run of three `card` tiles through `t`, or -1.
func _line3(t: int, card: String) -> int:
	var candidates: Array = [t]
	candidates.append_array(s.path_neighbors(t))
	for m in candidates:
		if m == 0 or s.card_at(m) != card:
			continue
		var has_prev := false
		for p in s.tiles[m]["prev"]:
			if s.card_at(p) == card:
				has_prev = true
		var has_next := false
		for n in s.tiles[m]["next"]:
			if s.card_at(n) == card:
				has_next = true
		if has_prev and has_next:
			return m
	return -1


func _is_between(t: int, card: String) -> bool:
	var a := false
	for p in s.tiles[t]["prev"]:
		if s.card_at(p) == card:
			a = true
	var b := false
	for n in s.tiles[t]["next"]:
		if s.card_at(n) == card:
			b = true
	return a and b


func _check_path_combos(t: int, id: String) -> void:
	match id:
		"spider":
			var m := _line3(t, "spider")
			if m >= 0:
				s.tiles[m]["card"] = "queen"
				_spawn(m, "queen")
				s.add_threat(10.0)
				_found("queen")
		"spikes":
			var m := _line3(t, "spikes")
			if m >= 0:
				s.tiles[m]["card"] = "grinder"
				_found("grinder")
			for nb in s.path_neighbors(t):
				_try_mimic(nb)
		"chest":
			_try_mimic(t)
		"crypt":
			for nb in s.path_neighbors(t):
				if s.card_at(nb) == "crypt":
					s.tiles[t]["card"] = "catacomb"
					s.tiles[nb]["card"] = "catacomb"
					_fill_skeletons(t)
					_fill_skeletons(nb)
					_found("catacombs")
					break
			_try_necropolis(t)


func _try_mimic(t: int) -> void:
	if s.card_at(t) == "chest" and _is_between(t, "spikes"):
		s.tiles[t]["card"] = "mimic"
		_spawn(t, "mimic")
		_found("mimic")


func _try_necropolis(t: int) -> void:
	var card := s.card_at(t)
	if (card == "crypt" or card == "catacomb") and s.scenery_near(t, "graveyard") >= 2:
		s.tiles[t]["card"] = "necropolis"
		_fill_skeletons(t)
		_spawn(t, "golem")
		s.add_threat(10.0)
		_found("necropolis")


func _check_scenery_combos(cell: Vector2i, id: String) -> void:
	if id == "graveyard":
		for nb in s.neighbors(cell):
			if s.path_lookup.has(nb):
				var t: int = s.path_lookup[nb]
				_try_necropolis(t)
	elif id == "altar":
		if s.scenery_near_cell(cell, "altar") + s.scenery_near_cell(cell, "spire") >= 2:
			s.scenery[cell] = "spire"
			_found("spire")


func _found(combo_id: String) -> void:
	var def: Dictionary = D.COMBOS[combo_id]
	var combo_name: String = def["name"]
	if Meta.discover(combo_id):
		s.add_log("NEW COMBO DISCOVERED: %s!" % combo_name)
		s.combo_found.emit("NEW COMBO: %s" % combo_name)
	else:
		s.add_log("Combo: %s!" % combo_name)
		s.combo_found.emit(combo_name)
