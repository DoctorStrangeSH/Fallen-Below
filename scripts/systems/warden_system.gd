extends Node
## The Warden: your monster. Patrols the loop against the travelers' direction,
## fights whoever it meets, devours the dead to heal and grow, wears their gear.
## If the Warden dies, the run is over.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState
var pending_levels := 0


func setup(base_hp: float, base_dmg: float) -> void:
	s.warden = {
		"name": D.WARDEN["name"], "hp": base_hp, "max_hp": base_hp,
		"base_hp": base_hp, "base_dmg": base_dmg, "dmg": base_dmg,
		"speed": D.WARDEN["speed"], "color": D.WARDEN["color"],
		"level": 1, "xp": 0, "abilities": [], "gear": {}, "affixes": [],
		"cur": s.loop_size / 2, "prog": 0.0, "undying_used": false, "relic_used": false,
	}


func has(ability: String) -> bool:
	var list: Array = s.warden["abilities"]
	return list.has(ability)


func has_affix(affix: String) -> bool:
	var list: Array = s.warden["affixes"]
	return list.has(affix)


func alive() -> bool:
	return not s.warden.is_empty() and s.warden["hp"] > 0.0


# ---------------------------------------------------------- movement

## The Warden walks the main loop backwards, so it meets travelers head-on.
## It stops while any traveler shares its tile.
func move(delta: float) -> void:
	if not alive():
		return
	var w := s.warden
	if not s.travelers_at(w["cur"]).is_empty():
		return
	var speed: float = w["speed"] * (1.4 if has("swift") else 1.0)
	w["prog"] += speed * delta
	while w["prog"] >= 1.0:
		w["prog"] -= 1.0
		w["cur"] = posmod(int(w["cur"]) - 1, s.loop_size)
		if not s.travelers_at(w["cur"]).is_empty():
			w["prog"] = 0.0
			break


func next_tile() -> int:
	return posmod(int(s.warden["cur"]) - 1, s.loop_size)


# ---------------------------------------------------------- combat

func strike(targets: Array) -> void:
	if not alive() or targets.is_empty():
		return
	var w := s.warden
	var hit: Array = targets if has("cleave") else [targets[s.rng.randi() % targets.size()]]
	var dealt := 0.0
	for h in hit:
		var dmg: float = w["dmg"]
		if has_affix("crit") and s.rng.randf() < 0.2:
			dmg *= 2.0
		run.heroes_sys.damage(h, dmg)
		dealt += dmg
	var heal := 0.0
	if has("vampiric"):
		heal += dealt * 0.2
	if has_affix("lifesteal"):
		heal += dealt * 0.15
	heal_by(heal)


func take_damage(amount: float, attacker: Dictionary) -> void:
	if not alive():
		return
	var w := s.warden
	w["hp"] -= amount
	var reflect := 0.0
	if has("spiked_bones"):
		reflect += 3.0
	if has_affix("thorns"):
		reflect += 3.0
	if reflect > 0.0:
		run.heroes_sys.damage(attacker, reflect)
	if w["hp"] > 0.0:
		return
	if has("undying") and not w["undying_used"]:
		w["undying_used"] = true
		w["hp"] = w["max_hp"] * 0.4
		s.add_log("The Warden refuses to die!")
		s.combo_found.emit("UNDYING")
	elif s.has_relic("second_heartbeat") and not w["relic_used"]:
		w["relic_used"] = true
		w["hp"] = w["max_hp"] * 0.5
		s.add_log("Second Heartbeat! The Warden rises again.")
		s.combo_found.emit("SECOND HEARTBEAT")
	else:
		w["hp"] = 0.0
		s.add_log("The Warden falls...")
		run.end_game(false)


func heal_by(amount: float) -> void:
	if not alive() or amount <= 0.0:
		return
	s.warden["hp"] = minf(s.warden["max_hp"], s.warden["hp"] + amount)


func tick_regen() -> void:
	if has_affix("regen"):
		heal_by(1.0)


# ---------------------------------------------------------- growth

## The Warden eats a fallen traveler: heals and gains experience.
func devour(h: Dictionary) -> void:
	var w := s.warden
	var heal: float = w["max_hp"] * D.DEVOUR_HEAL
	var xp := D.XP_PER_KILL
	if has("glutton"):
		heal *= 2.0
		xp += 5
	if s.has_relic("hungry_dark"):
		heal *= 1.5
		s.gain("blood", 2)
	if h["boss"]:
		xp *= 3
	heal_by(heal)
	gain_xp(xp)


func xp_to_next() -> int:
	var lvl: int = s.warden["level"]
	if lvl - 1 >= D.XP_LEVELS.size():
		return -1
	return D.XP_LEVELS[lvl - 1]


func gain_xp(amount: int) -> void:
	var w := s.warden
	w["xp"] += amount
	while xp_to_next() > 0 and int(w["xp"]) >= xp_to_next():
		w["level"] += 1
		heal_by(w["max_hp"] * D.LEVEL_UP_HEAL)
		s.add_log("The Warden grows stronger: level %d." % w["level"])
		pending_levels += 1
	if s.level_choices.is_empty():
		_offer_ability()


func _offer_ability() -> void:
	if pending_levels <= 0 or s.game_over:
		return
	var pool: Array = []
	for id in D.ABILITIES:
		if not has(id):
			pool.append(id)
	pool.shuffle()
	if pool.is_empty():
		pending_levels = 0
		return
	s.level_choices = pool.slice(0, D.ABILITY_CHOICES)
	s.level_up.emit()


func pick_ability(i: int) -> void:
	if i < 0 or i >= s.level_choices.size():
		return
	var id: String = s.level_choices[i]
	s.warden["abilities"].append(id)
	s.add_log("New ability: %s." % D.ABILITIES[id]["name"])
	recompute()
	s.level_choices = []
	pending_levels -= 1
	_offer_ability()
	s.level_up.emit()


# ---------------------------------------------------------- gear

## Puts an item on the Warden. Returns the item it replaced (or {}).
func equip(item: Dictionary) -> Dictionary:
	var gear: Dictionary = s.warden["gear"]
	var slot: String = item["slot"]
	var old: Dictionary = gear.get(slot, {})
	gear[slot] = item
	recompute()
	return old


func recompute() -> void:
	var w := s.warden
	var max_hp: float = w["base_hp"]
	var dmg: float = w["base_dmg"]
	var affixes: Array = []
	var gear: Dictionary = w["gear"]
	for slot in gear:
		var it: Dictionary = gear[slot]
		max_hp += it["hp"]
		dmg += it["dmg"]
		if it["affix"] != "":
			affixes.append(it["affix"])
	if has("thick_hide"):
		max_hp *= 1.25
	if has("brutal"):
		dmg += 3.0
	var gain: float = max_hp - w["max_hp"]
	w["max_hp"] = max_hp
	w["hp"] = clampf(w["hp"] + maxf(gain, 0.0), 0.0, max_hp)
	w["dmg"] = dmg
	w["affixes"] = affixes
