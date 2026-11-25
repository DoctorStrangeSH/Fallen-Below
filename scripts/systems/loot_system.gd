extends Node
## Trophies: fallen travelers drop gear for the Warden.

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
		s.gain("bones", 1)
		s.add_log("No room for %s, ground into bones." % item["name"])
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
			item["hp"] = round(10.0 * mult)
		"amulet":
			item["hp"] = round(4.0 * mult)
			item["affix"] = _random_affix()
		"ring":
			item["dmg"] = snappedf(1.0 * mult, 0.5)
			item["hp"] = round(3.0 * mult)
	if (slot == "weapon" or slot == "armor") and r >= 2:
		item["affix"] = _random_affix()
	if slot == "ring" and r >= 1:
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

## Click a trophy: the Warden puts it on. Whatever it wore in that slot goes back to the bag.
func equip(i: int) -> void:
	if s.game_over or i < 0 or i >= s.inventory.size():
		return
	var item: Dictionary = s.inventory[i]
	s.inventory.remove_at(i)
	var old: Dictionary = run.warden.equip(item)
	if not old.is_empty():
		s.inventory.append(old)
	s.add_log("The Warden takes %s." % item["name"])
	s.inventory_changed.emit()


## Right-click a trophy: grind it into bones.
func melt(i: int) -> void:
	if i < 0 or i >= s.inventory.size():
		return
	s.inventory.remove_at(i)
	s.gain("bones", 1)
	s.inventory_changed.emit()
