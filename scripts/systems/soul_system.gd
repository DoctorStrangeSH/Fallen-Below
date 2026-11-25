extends Node
## What happens to the fallen. No pop-up: the player sets a stance.
##   Devour (default): the Warden eats the body, heals and gains experience.
##   Raise: the traveler rises as an undead servant on the tile where it died
##          (if a servant slot is free), and whispers what it knew.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func can_raise() -> bool:
	return s.undead_count() < s.jar_cap


func toggle_stance() -> void:
	s.raise_souls = not s.raise_souls


func on_death(h: Dictionary) -> void:
	if s.raise_souls and can_raise() and not h["boss"]:
		_raise(h)
	else:
		run.warden.devour(h)


func _raise(h: Dictionary) -> void:
	var hp: float = round(h["max_hp"] * 0.8)
	var col: Color = h["color"]
	var dark: String = D.HERO_CLASSES[h["cls"]]["dark"]
	var unit := {
		"name": "%s %s" % [dark, h["name"]], "hp": hp, "max_hp": hp,
		"dmg": h["dmg"] * 1.1, "color": col.darkened(0.55),
		"undead": true, "party": h["party"], "cls": h["cls"],
	}
	var t: int = h["death_tile"]
	s.tiles[t]["units"].append(unit)
	var avengers := 0
	for x in s.heroes:
		if x["party"] == h["party"]:
			x["revenge"] = true
			avengers += 1
	s.add_log("%s rises to serve you." % unit["name"])
	var lines: Array = D.WHISPERS[h["cls"]]
	s.add_log("\"%s\"" % lines[s.rng.randi() % lines.size()])
	if avengers > 0:
		s.add_log("Their companions swear revenge!")
