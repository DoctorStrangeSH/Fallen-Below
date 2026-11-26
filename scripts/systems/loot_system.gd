extends Node
## Gear dropped by the dead, Loop Hero style: a slot, an item type with a main
## and a secondary stat, plus random extra stats by rarity. Item level = current loop.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func drop_from(h: Dictionary) -> void:
	var sure: bool = h["boss"] or h["trait"] == "veteran" or s.has_relic("grave_robber")
	if not sure and s.rng.randf() >= D.ITEM_DROP_CHANCE:
		return
	var item := make_item(h)
	if s.inventory.size() >= D.INVENTORY_MAX:
		var lost: Dictionary = s.inventory.pop_front()  # the oldest item is left behind
		s.add_log(Loc.t("No room: %s is left in the dark.") % lost["name"])
	s.inventory.append(item)
	s.add_log(Loc.t("%s dropped %s.") % [h["name"], item["name"]])
	run.beat("tut_loot")
	s.fx.emit("loot", h, 0.0)
	s.inventory_changed.emit()


func make_item(h: Dictionary) -> Dictionary:
	# travelers carry what suits them, but only what this Warden can wear drops
	var slots: Array = D.ITEM_SLOTS[h["cls"]].filter(func(x): return run.warden.can_wear(x))
	if slots.is_empty():
		slots = s.warden["slots"]
	var slot: String = slots[s.rng.randi() % slots.size()]
	var types: Array = D.ITEM_TYPES[slot]
	var type_def: Dictionary = types[s.rng.randi() % types.size()]
	var r := _roll_rarity(h["boss"])
	var rar: Dictionary = D.RARITIES[r]
	var level: int = s.loop * D.ITEM_LEVEL_PER_LOOP + int(s.act_def()["item_bonus"])
	var stats := {}
	var main_stat: String = type_def["main"]
	var second_stat: String = type_def["second"]
	stats[main_stat] = _roll(main_stat, level, 1.5 * rar["mult"])
	stats[second_stat] = float(stats.get(second_stat, 0.0)) + _roll(second_stat, level, 0.8 * rar["mult"])
	var pool: Array = D.STATS.keys().filter(func(k): return k != main_stat and k != second_stat)
	pool.shuffle()
	for i in int(rar["extras"]):
		if i >= pool.size():
			break
		var k: String = pool[i]
		stats[k] = _roll(k, level, 0.6 * rar["mult"])
	return {
		"name": Loc.t(str(type_def["name"])) + ("" if r == 0 else " [%s]" % Loc.t(rar["name"])),
		"slot": slot, "rarity": r, "level": level, "stats": stats,
	}


## One stat value with +-20% spread, rounded to something readable.
func _roll(k: String, level: int, mult: float) -> float:
	var roll: Array = D.STAT_ROLL[k]
	var v: float = (float(roll[0]) + float(roll[1]) * level) * mult * s.rng.randf_range(0.8, 1.2)
	if k == "hp" or k == "vamp" or k == "evade" or k == "counter":
		return maxf(1.0, round(v))
	return snappedf(v, 0.1)


func _roll_rarity(boss: bool) -> int:
	if boss:
		return D.RARITIES.size() - 1
	var weights: Array = []
	var total := 0.0
	for i in D.RARITIES.size():
		var w: float = D.RARITIES[i]["weight"]
		if i >= 1:
			w *= 1.0 + 0.25 * (s.loop - 1)  # deeper loops, better loot
		if i >= 2 and s.has_relic("gilded_cage"):
			w *= 2.0
		weights.append(w)
		total += w
	var roll := s.rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return 0


static func stat_text(k: String, v: float) -> String:
	var def: Dictionary = D.STATS[k]
	if def["pct"]:
		return "+%d%% %s" % [int(v), Loc.t(def["name"])]
	if k == "hp":
		return "+%d %s" % [int(v), Loc.t(def["name"])]
	return "+%s %s" % [str(snappedf(v, 0.1)), Loc.t(def["name"])]


static func describe(item: Dictionary) -> String:
	var parts: Array = []
	var stats: Dictionary = item["stats"]
	for k in stats:
		parts.append(stat_text(k, stats[k]))
	return ", ".join(parts)


# ---------------------------------------------------------- inventory actions

## Click a trophy: the Warden puts it on. Whatever it wore in that slot goes back to the bag.
func equip(i: int, at: int = -1) -> void:
	if s.game_over or i < 0 or i >= s.inventory.size():
		return
	var item: Dictionary = s.inventory[i]
	if not run.warden.can_wear(item["slot"]):
		s.add_log(Loc.t("%s cannot wear that.") % s.warden["name"])
		return
	if at >= 0 and str(s.warden["slots"][at]) != str(item["slot"]):
		return  # dropped on a slot of another kind
	s.inventory.remove_at(i)
	var old: Dictionary = run.warden.equip(item, at)
	if not old.is_empty():
		s.inventory.append(old)
	s.add_log(Loc.t("The Warden takes %s.") % item["name"])
	s.inventory_changed.emit()


## Drag a worn item back into the bag.
func unequip(idx: int) -> void:
	if s.game_over or s.inventory.size() >= D.INVENTORY_MAX:
		return
	var item: Dictionary = run.warden.unequip(idx)
	if item.is_empty():
		return
	s.inventory.append(item)
	s.inventory_changed.emit()


## Right-click a trophy: throw it away.
func discard(i: int) -> void:
	if i < 0 or i >= s.inventory.size():
		return
	s.inventory.remove_at(i)
	s.inventory_changed.emit()
