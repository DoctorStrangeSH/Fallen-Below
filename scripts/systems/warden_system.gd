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
	s.warden = {
		"name": Meta.warden_name(), "color": D.WARDEN["color"], "speed": D.WARDEN["speed"],
		"base": base, "diet": base.duplicate(), "stats": base.duplicate(),
		"hp": base_hp, "max_hp": base_hp, "dmg": base_dmg,
		"gear": {}, "eaten": {}, "cur": s.loop_size / 2, "prog": 0.0, "relic_used": false,
	}
	for k in s.warden["diet"]:
		s.warden["diet"][k] = 0.0
	recompute()


func stat(k: String) -> float:
	var st: Dictionary = s.warden["stats"]
	return float(st.get(k, 0.0))


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
	heal_by(s.warden["max_hp"] * D.LOOP_HEAL)
	s.add_log("Loop %d: the dungeon grows deeper. Travelers and their gear grow stronger." % s.loop)
	run.beat("first_loop")


# ---------------------------------------------------------- combat

## The Warden attacks travelers on its tile (one target).
func strike(targets: Array) -> void:
	if not alive() or targets.is_empty():
		return
	var h: Dictionary = targets[s.rng.randi() % targets.size()]
	var dmg: float = s.warden["dmg"]
	run.heroes_sys.damage(h, dmg)
	heal_by(dmg * stat("vamp") / 100.0)


## A traveler hits the Warden: evasion, then defense; counter-attack chance.
func take_hit(amount: float, attacker: Dictionary) -> void:
	if not alive():
		return
	if s.rng.randf() * 100.0 < stat("evade"):
		return
	var dmg := maxf(amount - stat("def"), amount * 0.2)
	s.warden["hp"] -= dmg
	if s.rng.randf() * 100.0 < stat("counter"):
		run.heroes_sys.damage(attacker, s.warden["dmg"])
	if s.warden["hp"] > 0.0:
		return
	if s.has_relic("second_heartbeat") and not s.warden["relic_used"]:
		s.warden["relic_used"] = true
		s.warden["hp"] = s.warden["max_hp"] * 0.5
		s.add_log("Second Heartbeat! The Warden rises again.")
		s.combo_found.emit("SECOND HEARTBEAT")
	else:
		s.warden["hp"] = 0.0
		s.add_log("The Warden falls...")
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
	w["diet"][diet["stat"]] += float(diet["amount"]) * mult
	recompute()
	var heal: float = w["max_hp"] * D.DEVOUR_HEAL
	if s.has_relic("hungry_dark"):
		heal *= 1.5
		s.gain("blood", 2)
	heal_by(heal)
	run.beat("first_devour")


# ---------------------------------------------------------- gear

## Puts an item on the Warden. Returns the item it replaced (or {}).
func equip(item: Dictionary) -> Dictionary:
	var gear: Dictionary = s.warden["gear"]
	var slot: String = item["slot"]
	var old: Dictionary = gear.get(slot, {})
	gear[slot] = item
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
	w["stats"] = st
	var gain: float = st["hp"] - w["max_hp"]
	w["max_hp"] = st["hp"]
	w["hp"] = clampf(w["hp"] + maxf(gain, 0.0), 0.0, w["max_hp"])
	w["dmg"] = st["dmg"]
