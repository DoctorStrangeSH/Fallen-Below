extends Node
## Hero spawning, movement along the loop, traits, damage, death and fleeing.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func make_hero(cls: String, hero_name: String, mult: float, party: int, idx: int) -> Dictionary:
	var base: Dictionary = D.HERO_CLASSES[cls]
	var hp: float = round(base["hp"] * mult)
	var h := {
		"id": s.next_hero_id, "name": hero_name, "cls": cls, "title": "",
		"hp": hp, "max_hp": hp, "dmg": base["dmg"] * mult,
		"speed": base["speed"], "greed": base["greed"], "color": base["color"],
		"party": party, "pos": 0.0, "delay": idx * 0.8, "loot": 0, "level": 0,
		"revenge": false, "boss": false, "gone": false, "death_tile": 0,
		"trait": "",
	}
	if s.rng.randf() < D.TRAIT_CHANCE:
		set_trait(h, D.TRAITS.keys()[s.rng.randi() % D.TRAITS.size()])
	s.next_hero_id += 1
	s.heroes.append(h)
	return h


func set_trait(h: Dictionary, trait_id: String) -> void:
	h["trait"] = trait_id
	if trait_id == "greedy":
		h["greed"] += 1
		h["speed"] *= 1.2
	elif trait_id == "veteran":
		h["max_hp"] = round(h["max_hp"] * 1.3)
		h["hp"] = h["max_hp"]


static func party_size(day: int) -> int:
	return clampi(1 + day / 3, 1, 4)


func spawn_party() -> void:
	var pid := s.next_party_id
	s.next_party_id += 1
	var size := party_size(s.day)
	var mult := 1.0 + 0.12 * (s.day - 1)
	for i in size:
		var cls: String = D.HERO_CLASSES.keys()[s.rng.randi() % D.HERO_CLASSES.size()]
		var hero_name: String = D.FIRST_NAMES[s.rng.randi() % D.FIRST_NAMES.size()]
		make_hero(cls, hero_name, mult, pid, i)
	s.add_log("Day %d: a party of %d enters." % [s.day, size])


func spawn_boss() -> void:
	s.boss_spawned = true
	var h := make_hero("paladin", "Aurelia", 1.0, s.next_party_id, 0)
	s.next_party_id += 1
	h["trait"] = ""
	h["boss"] = true
	h["title"] = "the Lightbringer"
	h["hp"] = 120.0 + s.day * 10.0
	h["max_hp"] = h["hp"]
	h["dmg"] = 6.0 + s.day * 0.5
	h["speed"] = 1.2
	h["color"] = Color(1, 1, 1)
	s.add_log("THE LIGHTBRINGER COMES. Kill her to win.")


func move(delta: float) -> void:
	var n := s.path.size()
	for h in s.heroes.duplicate():
		if h["gone"]:
			continue
		if h["delay"] > 0.0:
			h["delay"] -= delta
			continue
		if not s.alive_units(s.tile_of(h)).is_empty():
			continue  # fighting
		var old_i: int = int(floor(h["pos"]))
		h["pos"] += h["speed"] * delta
		var new_i: int = int(floor(h["pos"]))
		if new_i == old_i:
			continue
		var t: int = posmod(new_i, n)
		if t == 0:
			_on_lap(h)
			if h["gone"] or s.game_over:
				continue
		_on_enter_tile(h, t)
		if not h["gone"] and not s.alive_units(t).is_empty():
			h["pos"] = float(new_i)  # stop at the room entrance


func _on_lap(h: Dictionary) -> void:
	if h["boss"]:
		s.heart_hp -= 5
		s.add_log("%s strikes your Heart!" % s.hero_name(h))
	else:
		s.heart_hp -= int(h["greed"])
		h["loot"] += 1
		s.add_log("%s stole gold (%d/%d)." % [s.hero_name(h), h["loot"], D.FLEE_LOOT])
	if s.heart_hp <= 0:
		s.heart_hp = 0
		run.end_game(false)
		return
	if not h["boss"] and h["loot"] >= D.FLEE_LOOT:
		remove(h)
		s.add_log("%s escaped with your gold!" % s.hero_name(h))


func _on_enter_tile(h: Dictionary, t: int) -> void:
	if s.tiles[t]["card"] == "spikes":
		var n := s.path.size()
		var chain := 0
		for d in [-1, 1]:
			if s.tiles[posmod(t + d, n)]["card"] == "spikes":
				chain += 1
		damage(h, 5.0 + 2.0 * chain)


func damage(h: Dictionary, amount: float) -> void:
	if h["gone"]:
		return
	h["hp"] -= amount
	if h["hp"] <= 0.0:
		_kill(h)
	elif h["trait"] == "coward" and not h["boss"] and h["hp"] < h["max_hp"] * 0.3:
		remove(h)
		s.add_log("%s the Coward runs for their life!" % h["name"])


func heal(h: Dictionary, amount: float) -> void:
	h["hp"] = minf(h["max_hp"], h["hp"] + amount)


func _kill(h: Dictionary) -> void:
	h["death_tile"] = s.tile_of(h)
	remove(h)
	s.kills += 1
	s.essence += 2
	s.threat += 5.0
	run.cards.draw_card()
	if h["trait"] == "veteran":
		run.cards.draw_card()
	for x in s.heroes:
		if x["party"] == h["party"] and x["trait"] == "loyal":
			x["dmg"] += 2.0
			x["revenge"] = true
			s.add_log("%s the Loyal swears to avenge %s!" % [x["name"], h["name"]])
	s.hand_changed.emit()
	if h["boss"]:
		s.add_log("%s has fallen!" % s.hero_name(h))
		run.end_game(true)
		return
	s.pending_souls.append(h)
	s.souls_changed.emit()


func remove(h: Dictionary) -> void:
	h["gone"] = true
	var id: int = h["id"]
	s.heroes = s.heroes.filter(func(x): return x["id"] != id)

