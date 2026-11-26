extends Node
## The Warden: your monster. Patrols the main loop against the travelers' direction,
## fights whoever it meets, wears what the dead leave behind, and grows on what it eats.
## Every patrol loop it completes makes the dungeon deeper: new travelers and their gear
## get stronger (like loops in Loop Hero). If the Warden dies, the run is over.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func setup(base_hp: float, base_dmg: float) -> void:
	var base := {}
	for k in D.STATS:
		base[k] = 0.0
	base["hp"] = base_hp
	base["dmg"] = base_dmg
	base["def"] = float(Meta.warden_def().get("def", 0.0)) + Meta.warden_def_bonus()
	var def: Dictionary = Meta.warden_def()
	s.warden = {
		"id": Meta.warden_id, "name": Meta.warden_name(), "color": def["color"], "speed": def["speed"],
		"slots": def["slots"].duplicate(),
		"base": base, "diet": base.duplicate(), "stats": base.duplicate(),
		"hp": base_hp, "max_hp": base_hp, "dmg": base_dmg,
		"gear": {}, "eaten": {}, "cur": s.loop_size / 2, "prog": 0.0, "relic_used": false,
		"cooldown": 0.0, "title": Meta.warden_title(),
		"level": 1, "xp": 0, "abilities": [], "growth": Meta.growth_unlocked(), "unbroken_used": false,
		"bonus_dmg": 0.0,
	}
	for k in s.warden["diet"]:
		s.warden["diet"][k] = 0.0
	recompute()


func stat(k: String) -> float:
	var st: Dictionary = s.warden["stats"]
	return float(st.get(k, 0.0))


var pending_levels := 0


func has(ability: String) -> bool:
	var list: Array = s.warden.get("abilities", [])
	return list.has(ability)


func is_kind(id: String) -> bool:
	return s.warden.get("id", "") == id


func alive() -> bool:
	return not s.warden.is_empty() and s.warden["hp"] > 0.0


# ---------------------------------------------------------- movement

## The Warden walks the main loop backwards, so it meets travelers head-on.
## It stops while any traveler shares its tile. Passing the door completes a loop.
func move(delta: float) -> void:
	if not alive():
		return
	var w := s.warden
	if not s.travelers_at(w["cur"]).is_empty():
		return
	w["prog"] += float(w["speed"]) * delta
	while w["prog"] >= 1.0:
		w["prog"] -= 1.0
		var prev_tile: int = w["cur"]
		w["cur"] = posmod(prev_tile - 1, s.loop_size)
		if prev_tile == 0:
			_complete_loop()
		if not s.travelers_at(w["cur"]).is_empty():
			w["prog"] = 0.0
			break


func next_tile() -> int:
	return posmod(int(s.warden["cur"]) - 1, s.loop_size)


func _complete_loop() -> void:
	s.loop += 1
	if s.has_relic("deep_roots"):
		s.warden["base"]["hp"] += 3.0
		recompute()
	heal_by(s.warden["max_hp"] * D.LOOP_HEAL)
	s.add_log(Loc.t("Loop %d: the dungeon grows deeper. Travelers and their gear grow stronger.") % s.loop)
	run.beat("first_loop")


# ---------------------------------------------------------- combat

## The Warden attacks travelers on its tile (one target).
func strike(targets: Array) -> void:
	if not alive() or targets.is_empty():
		return
	var dmg: float = s.warden["dmg"]
	if has("wrath"):
		dmg += s.count_units(s.warden["cur"], "Spider")
	var hit: Array = targets.duplicate() if has("cleaving_arm") else [targets[s.rng.randi() % targets.size()]]
	var dealt := 0.0
	for h in hit:
		run.heroes_sys.damage(h, dmg)
		dealt += dmg
		if has("venom") and not h["gone"]:
			h["poison"] = 3
		if h["gone"] and is_kind("brood"):
			run.cards.spawn_at(s.warden["cur"], "spider")
	if has("second_mouth"):
		var others: Array = targets.filter(func(x): return not x["gone"] and not hit.has(x))
		if not others.is_empty():
			run.heroes_sys.damage(others[0], dmg * 0.5)
			dealt += dmg * 0.5
	heal_by(dealt * stat("vamp") / 100.0)


## A traveler hits the Warden: evasion, then defense; counter-attack chance.
func take_hit(amount: float, attacker: Dictionary) -> void:
	if not alive():
		return
	if s.rng.randf() * 100.0 < stat("evade"):
		s.fx.emit("evade", s.warden, 0.0)
		return
	if has("halo"):
		amount *= 0.75
	var dmg := maxf(amount - stat("def"), amount * 0.2)
	s.warden["hp"] -= dmg
	s.fx.emit("hit_warden", s.warden, dmg)
	if not attacker.is_empty():
		if s.rng.randf() * 100.0 < stat("counter"):
			run.heroes_sys.damage(attacker, s.warden["dmg"])
		if has("bone_spurs"):
			run.heroes_sys.damage(attacker, 3.0)
	if s.warden["hp"] > 0.0:
		return
	if has("unbroken") and not s.warden["unbroken_used"]:
		s.warden["unbroken_used"] = true
		s.warden["hp"] = s.warden["max_hp"] * 0.4
		s.add_log(Loc.t("%s refuses to break!") % s.warden["name"])
		s.combo_found.emit(Loc.t("UNBROKEN"))
	elif s.has_relic("second_heartbeat") and not s.warden["relic_used"]:
		s.warden["relic_used"] = true
		s.warden["hp"] = s.warden["max_hp"] * 0.5
		s.add_log(Loc.t("Second Heartbeat! The Warden rises again."))
		s.combo_found.emit(Loc.t("SECOND HEARTBEAT"))
	else:
		s.warden["hp"] = 0.0
		s.add_log(Loc.t("The Warden falls..."))
		run.end_game(false)


func heal_by(amount: float) -> void:
	if not alive() or amount <= 0.0:
		return
	s.warden["hp"] = minf(s.warden["max_hp"], s.warden["hp"] + amount)


func tick_regen(seconds: float) -> void:
	heal_by(stat("regen") * seconds)


# ---------------------------------------------------------- growth: you are what you eat

func devour(h: Dictionary) -> void:
	var w := s.warden
	var kind: String = h["cls"]
	var eaten: Dictionary = w["eaten"]
	eaten[kind] = int(eaten.get(kind, 0)) + 1
	var diet: Dictionary = D.DIET[kind]
	var mult := 3.0 if h["boss"] else 1.0
	if s.has_relic("ravenous_maw"):
		mult *= 1.5
	w["diet"][diet["stat"]] += float(diet["amount"]) * mult
	recompute()
	var heal: float = w["max_hp"] * (D.DEVOUR_HEAL + Meta.devour_bonus())
	if is_kind("bone"):
		heal = w["max_hp"] * (0.4 + Meta.devour_bonus())
	elif is_kind("saint"):
		heal *= 0.5
	if has("gnaw"):
		heal += w["max_hp"] * 0.1
		w["bonus_dmg"] += 0.5
		recompute()
	if s.has_relic("hungry_dark"):
		heal *= 1.5
		s.gain("blood", 2)
	heal_by(heal)
	s.fx.emit("devour", s.warden, heal)
	run.beat("first_devour")
	gain_xp(int(D.XP_DEVOUR.get(w["id"], 4)) * (3 if h["boss"] else 1))


# ---------------------------------------------------------- gear

## Can this Warden wear items of this slot type at all?
func can_wear(slot_type: String) -> bool:
	var slots: Array = s.warden["slots"]
	return slots.has(slot_type)


## Index of the gear slot an item goes to: the first free matching slot,
## otherwise the first matching one (swap). -1 if the Warden has no such slot.
func slot_for(slot_type: String) -> int:
	var slots: Array = s.warden["slots"]
	var gear: Dictionary = s.warden["gear"]
	var first := -1
	for i in slots.size():
		if slots[i] != slot_type:
			continue
		if first < 0:
			first = i
		if not gear.has(i):
			return i
	return first


## Puts an item on the Warden. Returns the item it replaced (or {}).
func equip(item: Dictionary) -> Dictionary:
	var idx := slot_for(item["slot"])
	if idx < 0:
		return item  # cannot wear it: hand it straight back
	var gear: Dictionary = s.warden["gear"]
	var old: Dictionary = gear.get(idx, {})
	gear[idx] = item
	recompute()
	return old


## stats = base + diet + gear, with caps on chance stats.
func recompute() -> void:
	var w := s.warden
	var st: Dictionary = {}
	var base: Dictionary = w["base"]
	var diet: Dictionary = w["diet"]
	for k in D.STATS:
		st[k] = float(base.get(k, 0.0)) + float(diet.get(k, 0.0))
	var gear: Dictionary = w["gear"]
	for slot in gear:
		var it: Dictionary = gear[slot]
		var item_stats: Dictionary = it["stats"]
		for k in item_stats:
			st[k] = float(st.get(k, 0.0)) + float(item_stats[k])
	for k in D.STATS:
		var def: Dictionary = D.STATS[k]
		if def.has("cap"):
			st[k] = minf(st[k], float(def["cap"]))
	# the hoard counts gold as Act I would: richer acts do not snowball the Mimic
	var gold: float = float(s.pouch.get("gold", 0)) / float(s.act_def()["harvest"])
	if is_kind("mimic"):
		st["dmg"] += (0.05 if has("gilded_teeth") else 0.03) * gold
	st["dmg"] += float(w.get("bonus_dmg", 0.0))
	if has("thick_marrow"):
		st["hp"] *= 1.25
	if has("reliquary_bones"):
		st["hp"] *= 1.2
		st["def"] += 1.0
	if has("ossified") or has("chitin"):
		st["def"] += 2.0
	if has("coin_armor"):
		st["def"] += float(gold / 20)
	if has("sharp_hinges"):
		st["counter"] = minf(st["counter"] + 15.0, 50.0)
	w["stats"] = st
	var gain: float = st["hp"] - w["max_hp"]
	w["max_hp"] = st["hp"]
	w["hp"] = clampf(w["hp"] + maxf(gain, 0.0), 0.0, w["max_hp"])
	w["dmg"] = st["dmg"]


# ---------------------------------------------------------- active ability

func cooldown_max() -> float:
	var cd: float = Meta.warden_def()["cooldown"]
	if s.has_relic("cracked_hourglass"):
		cd *= 0.7
	if has("quick_hunger"):
		cd *= 0.6
	return cd


func tick(delta: float) -> void:
	if alive() and s.warden["cooldown"] > 0.0:
		s.warden["cooldown"] = maxf(0.0, s.warden["cooldown"] - delta)


## Player-triggered ability. Not spent if there is nothing to use it on.
func use_active() -> void:
	if not alive() or s.is_blocked() or s.warden["cooldown"] > 0.0:
		return
	var used := false
	match s.warden["id"]:
		"bone":
			used = _bone_storm()
		"brood":
			for k in (5 if has("clutch") else 3):
				run.cards.spawn_at(s.warden["cur"], "spider")
			used = true
		"mimic":
			used = _swallow()
		"saint":
			used = _call_the_dead()
	if used:
		s.fx.emit("ability", s.warden, 0.0)
		s.warden["cooldown"] = cooldown_max()
		s.add_log(Loc.t("%s: %s!") % [s.warden["name"], Loc.t(Meta.warden_def()["active"])])


func _bone_storm() -> bool:
	var area: Array = [int(s.warden["cur"])]
	var reach := 3 if has("splinters") else 1
	for r in reach:
		var ring: Array = []
		for t in area:
			for nb in s.path_neighbors(t):
				if not area.has(nb) and not ring.has(nb):
					ring.append(nb)
		area.append_array(ring)
	var hit := false
	for t in area:
		for h in s.travelers_at(t):
			run.heroes_sys.damage(h, s.warden["dmg"] * 2.0)
			if has("splinters") and not h["gone"]:
				h["stun"] = maxf(h["stun"], 1.0)
			hit = true
	if not hit:
		s.add_log(Loc.t("Bone Storm: no travelers near the Warden."))
	return hit


func _swallow() -> bool:
	var best = null
	for h in s.travelers_at(s.warden["cur"]):
		if h["boss"] or h["hp"] >= h["max_hp"] * (0.6 if has("wide_jaw") else 0.4):
			continue
		if best == null or h["hp"] < best["hp"]:
			best = h
	if best == null:
		s.add_log(Loc.t("Swallow: no weakened traveler on the Mimic King's tile."))
		return false
	best["swallowed"] = true
	run.heroes_sys.damage(best, best["hp"] + 1.0)
	return true


func _call_the_dead() -> bool:
	var count := 0
	for t in s.tiles.size():
		for u in s.undead_at(t):
			u["hp"] = minf(u["max_hp"], u["hp"] + u["max_hp"] * 0.5)
			count += 1
	if count == 0:
		s.add_log(Loc.t("Call the Dead: you have no servants."))
		return false
	heal_by(s.warden["max_hp"] * 0.05 * count)
	if has("resurrection"):
		for k in 2:
			run.cards.spawn_at(s.warden["cur"], "skeleton")
	return true


# ---------------------------------------------------------- experience & abilities

func gain_xp(amount: int) -> void:
	var w := s.warden
	if not w.get("growth", false) or amount <= 0 or not alive():
		return
	w["xp"] += int(round(amount * Meta.xp_mult()))
	while xp_to_next() > 0 and int(w["xp"]) >= xp_to_next():
		w["level"] += 1
		heal_by(w["max_hp"] * D.LEVEL_UP_HEAL)
		s.add_log(Loc.t("%s reaches level %d.") % [w["name"], w["level"]])
		run.beat("first_level")
		s.fx.emit("level", w, 0.0)
		pending_levels += 1
	if s.level_choices.is_empty():
		_offer_ability()


func xp_to_next() -> int:
	var lvl: int = s.warden.get("level", 1)
	if lvl - 1 >= D.XP_LEVELS.size():
		return -1
	return D.XP_LEVELS[lvl - 1]


func _pool() -> Dictionary:
	return D.ABILITIES.get(s.warden["id"], {})


func _offer_ability() -> void:
	if pending_levels <= 0 or s.game_over:
		return
	var pool: Array = []
	for id in _pool():
		if not has(id):
			pool.append(id)
	pool.shuffle()
	if pool.is_empty():
		pending_levels = 0
		return
	s.level_choices = pool.slice(0, D.ABILITY_CHOICES)
	s.level_up.emit()


func ability_def(id: String) -> Dictionary:
	return _pool().get(id, {"name": id, "desc": ""})


func pick_ability(i: int) -> void:
	if i < 0 or i >= s.level_choices.size():
		return
	var id: String = s.level_choices[i]
	s.warden["abilities"].append(id)
	s.add_log(Loc.t("New ability: %s.") % Loc.t(ability_def(id)["name"]))
	if id == "mass":
		s.jar_cap += 2
	recompute()
	s.level_choices = []
	pending_levels -= 1
	_offer_ability()
	s.level_up.emit()
