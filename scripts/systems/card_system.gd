extends Node
## Drawing, selecting and placing cards, plus placement synergies.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func draw_card() -> void:
	if s.hand.size() >= D.HAND_MAX:
		s.essence += 1  # overflow burns into essence
		return
	var total := 0
	for k in s.card_weights:
		total += int(s.card_weights[k])
	if total <= 0:
		return
	var roll := s.rng.randi() % total
	for k in s.card_weights:
		roll -= int(s.card_weights[k])
		if roll < 0:
			s.hand.append(k)
			return


## Click on a card in hand: instants resolve, others toggle selection.
func use_card(i: int) -> void:
	if s.game_over or not s.pending_souls.is_empty() or i < 0 or i >= s.hand.size():
		return
	var id: String = s.hand[i]
	if D.CARDS[id]["kind"] == "instant":
		if id == "jar":
			s.jar_cap += 1
			s.add_log("Soul capacity: %d." % s.jar_cap)
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
		return idx != 0 and s.tiles[idx]["card"] == ""
	if kind == "scenery":
		if s.path_lookup.has(cell) or s.scenery.has(cell):
			return false
		if cell.x < 0 or cell.y < 0 or cell.x > D.LOOP_MAX.x + 1 or cell.y > D.LOOP_MAX.y:
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
			for k in 2:
				s.tiles[idx]["units"].append(make_monster("skeleton"))
		elif id == "spider":
			for k in 3:
				s.tiles[idx]["units"].append(make_monster("spider"))
			_check_queen(idx)
	else:
		s.scenery[cell] = id
	s.threat += 8.0
	s.hand.remove_at(s.selected)
	s.selected = -1
	s.hand_changed.emit()


func make_monster(id: String) -> Dictionary:
	var m: Dictionary = D.MONSTERS[id]
	return {"name": m["name"], "hp": float(m["hp"]), "max_hp": float(m["hp"]), "dmg": m["dmg"],
		"color": m["color"], "undead": false, "party": -1}


## Daily respawn of room monsters.
func respawn_rooms() -> void:
	for i in s.tiles.size():
		var card: String = s.tiles[i]["card"]
		if card == "crypt":
			var cap := 2 + s.scenery_near(i, "graveyard")
			while s.count_units(i, "Skeleton") < cap:
				s.tiles[i]["units"].append(make_monster("skeleton"))
		elif card == "spider" or card == "queen":
			if s.count_units(i, "Spider") < 4:
				s.tiles[i]["units"].append(make_monster("spider"))


func _check_queen(idx: int) -> void:
	var n := s.path.size()
	for start in [idx - 2, idx - 1, idx]:
		var ok := true
		for k in 3:
			if s.tiles[posmod(start + k, n)]["card"] != "spider":
				ok = false
		if ok:
			var mid := posmod(start + 1, n)
			s.tiles[mid]["card"] = "queen"
			s.tiles[mid]["units"].append(make_monster("queen"))
			s.threat += 10.0
			s.add_log("Three nests merge: the Spider Queen awakens!")
			return
