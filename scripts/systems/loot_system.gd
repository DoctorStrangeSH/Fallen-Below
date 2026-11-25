extends Node
## Trophies: fallen heroes drop gear that only your undead can wear.

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
		s.essence += D.MELT_ESSENCE
		s.add_log("No room for %s, melted into essence." % item["name"])
		return
	s.inventory.append(item)
	s.add_log("%s dropped %s." % [h["name"], item["name"]])
	s.inventory_changed.emit()


func make_item(h: Dictionary) -> Dictionary:
	var options: Array = D.ITEM_SLOTS[h["cls"]]
	var pick: Array = options[s.rng.randi() % options.size()]
	var slot: String = pick[0]
	var noun: String = pick[1]
	var r := _roll_rarity(h["boss"])
	var rar: Dictionary = D.RARITIES[r]
	var mult: float = rar["mult"] * (1.0 + 0.1 * s.day)
	var item := {
		"name": "%s %s of %s" % [rar["name"], noun, h["name"]],
		"slot": slot, "rarity": r, "dmg": 0.0, "hp": 0.0, "affix": "",
	}
	match slot:
		"weapon":
			item["dmg"] = snappedf(2.0 * mult, 0.5)
		"armor":
			item["hp"] = round(8.0 * mult)
		"amulet":
			item["hp"] = round(3.0 * mult)
			item["affix"] = _random_affix()
	if slot != "amulet" and r >= 2:
		item["affix"] = _random_affix()
	return item


func _random_affix() -> String:
	var keys: Array = D.AFFIXES.keys()
	return keys[s.rng.randi() % keys.size()]


func _roll_rarity(boss: bool) -> int:
	if boss:
		return D.RARITIES.size() - 1
	var weights: Array = []
	var total := 0.0
	for i in D.RARITIES.size():
		var w: float = D.RARITIES[i]["weight"]
		if i >= 2:
			w += s.day * 0.5  # better loot later in the run
		weights.append(w)
		total += w
	var roll := s.rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return 0


static func describe(item: Dictionary) -> String:
	var parts: Array = []
	if item["dmg"] > 0.0:
		parts.append("+%s dmg" % str(item["dmg"]))
	if item["hp"] > 0.0:
		parts.append("+%d HP" % int(item["hp"]))
	var affix: String = item["affix"]
	if affix != "":
		parts.append(D.AFFIXES[affix]["name"])
	return ", ".join(parts)


# ---------------------------------------------------------- inventory actions

func select_item(i: int) -> void:
	if s.game_over or i < 0 or i >= s.inventory.size():
		return
	s.selected_item = -1 if s.selected_item == i else i
	s.selected = -1
	s.inventory_changed.emit()
	s.hand_changed.emit()


func melt(i: int) -> void:
	if i < 0 or i >= s.inventory.size():
		return
	s.inventory.remove_at(i)
	s.essence += D.MELT_ESSENCE
	s.selected_item = -1
	s.inventory_changed.emit()


func can_equip_at(cell: Vector2i) -> bool:
	if not s.path_lookup.has(cell):
		return false
	var t: int = s.path_lookup[cell]
	return not s.undead_at(t).is_empty()


func equip_at(cell: Vector2i) -> void:
	if s.selected_item < 0 or s.selected_item >= s.inventory.size():
		return
	if not can_equip_at(cell):
		s.add_log("Only your undead can wear trophies.")
		return
	var t: int = s.path_lookup[cell]
	var item: Dictionary = s.inventory[s.selected_item]
	var slot: String = item["slot"]
	var undead := s.undead_at(t)
	var target: Dictionary = undead[0]
	for u in undead:
		var g: Dictionary = u["gear"]
		if not g.has(slot):
			target = u
			break
	var gear: Dictionary = target["gear"]
	var old = gear.get(slot)
	gear[slot] = item
	s.inventory.remove_at(s.selected_item)
	if old != null:
		s.inventory.append(old)
	_recompute(target)
	s.selected_item = -1
	s.add_log("%s equips %s." % [target["name"], item["name"]])
	s.inventory_changed.emit()


func _recompute(u: Dictionary) -> void:
	var dmg: float = u["base_dmg"]
	var max_hp: float = u["base_hp"]
	var affixes: Array = []
	var gear: Dictionary = u["gear"]
	for slot in gear:
		var it: Dictionary = gear[slot]
		dmg += it["dmg"]
		max_hp += it["hp"]
		if it["affix"] != "":
			affixes.append(it["affix"])
	var gain: float = max_hp - u["max_hp"]
	u["max_hp"] = max_hp
	u["hp"] = clampf(u["hp"] + maxf(gain, 0.0), 0.0, max_hp)
	u["dmg"] = dmg
	u["affixes"] = affixes
