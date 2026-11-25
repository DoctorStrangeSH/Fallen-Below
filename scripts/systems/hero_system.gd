extends Node
## Travelers lured into the dungeon: spawning, movement, fork decisions (bait AI),
## traits, damage, death, harvest and escape.
## (Called "heroes" internally; in the game they are travelers.)

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
		"speed": base["speed"], "color": base["color"],
		"party": party, "cur": 0, "nxt": 0, "prog": 0.0, "delay": idx * 0.8, "stun": 0.0,
		"laps": 0, "revenge": false, "boss": false, "gone": false, "death_tile": 0,
		"trait": "", "baited": false,
	}
	if s.rng.randf() < D.TRAIT_CHANCE:
		set_trait(h, D.TRAITS.keys()[s.rng.randi() % D.TRAITS.size()])
	h["nxt"] = choose_next(h, 0)
	s.next_hero_id += 1
	s.heroes.append(h)
	return h


func set_trait(h: Dictionary, trait_id: String) -> void:
	h["trait"] = trait_id
	if trait_id == "greedy":
		h["speed"] *= 1.2
	elif trait_id == "veteran":
		h["max_hp"] = round(h["max_hp"] * 1.3)
		h["hp"] = h["max_hp"]


static func party_size(day: int) -> int:
	return clampi(1 + day / 3, 1, 4)


## Most of each party answers your lure; the rest are random wanderers.
func spawn_party() -> void:
	var pid := s.next_party_id
	s.next_party_id += 1
	var size := party_size(s.day)
	var mult := 1.0 + 0.12 * (s.day - 1)
	var lured: String = D.LURES[s.lure]["traveler"]
	var names: Array = []
	for i in size:
		var cls := lured
		if s.rng.randf() >= D.LURE_SHARE:
			cls = D.HERO_CLASSES.keys()[s.rng.randi() % D.HERO_CLASSES.size()]
		var hero_name: String = D.FIRST_NAMES[s.rng.randi() % D.FIRST_NAMES.size()]
		make_hero(cls, hero_name, mult, pid, i)
		names.append(D.HERO_CLASSES[cls]["name"])
	s.add_log("Day %d: lured below: %s." % [s.day, ", ".join(names)])


func spawn_boss() -> void:
	s.boss_spawned = true
	var act: Dictionary = D.ACTS[s.act]
	var h := make_hero("pilgrim", act["boss"], 1.0, s.next_party_id, 0)
	s.next_party_id += 1
	h["trait"] = ""
	h["boss"] = true
	h["title"] = act["boss_title"]
	h["hp"] = 140.0 + s.day * 10.0
	h["max_hp"] = h["hp"]
	h["dmg"] = 7.0 + s.day * 0.5
	h["speed"] = 1.3
	h["color"] = Color(1, 1, 1)
	s.add_log("%s descends: %s" % [s.hero_name(h), act["boss_intro"]])
	s.add_log("Her radiance burns undead nearby. Meet her with the Warden and the living.")
	s.combo_found.emit("%s DESCENDS" % s.hero_name(h).to_upper())


# ---------------------------------------------------------- movement

func _blocked(t: int) -> bool:
	return not s.alive_units(t).is_empty() or s.warden_at(t)


func move(delta: float) -> void:
	for h in s.heroes.duplicate():
		if h["gone"]:
			continue
		if h["delay"] > 0.0:
			h["delay"] -= delta
			continue
		if h["stun"] > 0.0:
			h["stun"] -= delta
			continue
		if _blocked(h["cur"]):
			continue  # fighting
		h["prog"] += h["speed"] * delta
		while h["prog"] >= 1.0 and not h["gone"] and not s.game_over:
			h["prog"] -= 1.0
			var t: int = h["nxt"]
			h["cur"] = t
			if t == 0:
				_on_lap(h)
				if h["gone"] or s.game_over:
					break
			_on_enter_tile(h, t)
			if h["gone"]:
				break
			h["nxt"] = choose_next(h, t)
			if h["stun"] > 0.0 or _blocked(t):
				h["prog"] = 0.0  # stop on this tile
				break


## Picks the next tile. At forks each traveler scores both branches by personality.
func choose_next(h: Dictionary, t: int) -> int:
	var opts: Array = s.tiles[t]["next"]
	if opts.size() == 1 or not s.forks.has(t):
		return opts[0]
	var fork: Dictionary = s.forks[t]
	var best: int = opts[0]
	var best_score := -INF
	for o in opts:
		var seg: Array = fork[o]
		var sc := _score_segment(h, seg) + s.rng.randf() * 1.5
		if sc > best_score:
			best_score = sc
			best = o
	if best != opts[0] and not h["boss"]:
		var reason := _lure_reason(h, fork[best])
		if reason != "":
			s.add_log("%s %s" % [s.hero_name(h), reason])
	return best


func _is_greedy(h: Dictionary) -> bool:
	return h["trait"] == "greedy" or h["cls"] == "seeker"


func _is_holy(h: Dictionary) -> bool:
	return h["trait"] == "zealot" or h["cls"] == "pilgrim"


func _score_segment(h: Dictionary, seg: Array) -> float:
	var greedy := _is_greedy(h)
	var holy := _is_holy(h)
	var coward: bool = h["trait"] == "coward"
	var sc := 0.0
	for id in seg:
		var card := s.card_at(id)
		if D.BAIT_CARDS.has(card):
			sc += 8.0 if greedy else 1.5
		if D.TRAP_DMG.has(card) and card != "chest":
			sc -= 3.0 if coward else 1.0
		var units := s.alive_units(id)
		var undead := 0
		for u in units:
			if u["undead"]:
				undead += 1
		sc -= (2.0 if coward else 0.3) * units.size()
		if holy:
			sc += 3.0 * undead
			sc += 4.0 * (s.scenery_near(id, "altar") + s.scenery_near(id, "spire"))
	return sc


func _lure_reason(h: Dictionary, seg: Array) -> String:
	for id in seg:
		var card := s.card_at(id)
		if D.BAIT_CARDS.has(card) and _is_greedy(h):
			return "can't resist the chest..."
		if _is_holy(h) and (s.scenery_near(id, "altar") + s.scenery_near(id, "spire") > 0 or not s.undead_at(id).is_empty()):
			return "goes to purge the darkness."
	return ""


## Each lap brings a traveler closer to the way out.
func _on_lap(h: Dictionary) -> void:
	if h["boss"]:
		return  # the champion hunts the Warden, she does not leave
	h["laps"] += 1
	if h["laps"] >= D.ESCAPE_LAPS:
		escape(h, "found the way out")
	else:
		s.add_log("%s is getting closer to the exit (%d/%d)." % [s.hero_name(h), h["laps"], D.ESCAPE_LAPS])


func escape(h: Dictionary, how: String) -> void:
	remove(h)
	var t := D.THREAT_PER_ESCAPE * (0.5 if s.has_relic("whispering_skull") else 1.0)
	s.add_threat(t)
	s.add_log("%s %s and will tell the Order!" % [s.hero_name(h), how])


func _on_enter_tile(h: Dictionary, t: int) -> void:
	var card := s.card_at(t)
	if not D.TRAP_DMG.has(card):
		return
	var dmg: float = D.TRAP_DMG[card]
	if (card == "spikes" or card == "grinder") and s.has_relic("thorned_halls"):
		dmg += 3.0
	if card == "spikes":
		for nb in s.path_neighbors(t):
			var c := s.card_at(nb)
			if c == "spikes" or c == "grinder":
				dmg += 2.0
	elif card == "chest":
		h["stun"] = D.CHEST_STUN
		h["baited"] = true
	damage(h, dmg)


# ---------------------------------------------------------- health

func damage(h: Dictionary, amount: float) -> void:
	if h["gone"]:
		return
	h["hp"] -= amount
	if h["hp"] <= 0.0:
		_kill(h)
	elif h["trait"] == "coward" and not h["boss"] and h["hp"] < h["max_hp"] * 0.3:
		escape(h, "panics and flees for the surface")


func heal(h: Dictionary, amount: float) -> void:
	h["hp"] = minf(h["max_hp"], h["hp"] + amount)


func _kill(h: Dictionary) -> void:
	h["death_tile"] = h["cur"]
	remove(h)
	s.kills += 1
	s.add_threat(D.THREAT_PER_KILL)
	_harvest(h)
	run.cards.draw_card()
	run.loot.drop_from(h)
	for x in s.heroes:
		if x["party"] == h["party"] and x["trait"] == "loyal":
			x["dmg"] += 2.0
			x["revenge"] = true
			s.add_log("%s the Loyal swears to avenge %s!" % [x["name"], h["name"]])
	s.hand_changed.emit()
	run.souls.on_death(h)
	if h["boss"]:
		s.add_log("%s has fallen!" % s.hero_name(h))
		run.end_game(true)


## Every body is harvested according to who it was.
func _harvest(h: Dictionary) -> void:
	var drop: Dictionary = D.HERO_CLASSES[h["cls"]]["drop"]
	for k in drop:
		s.gain(k, int(drop[k]))
	if h["baited"] and s.has_relic("gilded_bait"):
		s.gain("gold", 2)
	if h["boss"]:
		for k in D.BOSS_DROP:
			s.gain(k, int(D.BOSS_DROP[k]))
	var relic_chance := 0.0
	if h["trait"] == "veteran":
		relic_chance = D.VETERAN_RELIC_CHANCE
	elif h["cls"] == "mage":
		relic_chance = D.MAGE_RELIC_CHANCE
	if h["boss"] or s.rng.randf() < relic_chance:
		_find_relic(h)


func _find_relic(h: Dictionary) -> void:
	var id: String = Meta.random_unowned_relic(s.rng, s.found_relics)
	if id == "":
		return
	s.found_relics.append(id)
	var relic_name: String = D.RELICS[id]["name"]
	s.add_log("%s carried a relic: %s! Survive to keep it." % [h["name"], relic_name])
	s.combo_found.emit("RELIC FOUND: %s" % relic_name)


func remove(h: Dictionary) -> void:
	h["gone"] = true
	var id: int = h["id"]
	s.heroes = s.heroes.filter(func(x): return x["id"] != id)
