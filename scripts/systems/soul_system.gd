extends Node
## The fate of fallen heroes: raise, absorb or interrogate.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const HeroSystem = preload("res://scripts/systems/hero_system.gd")

var run  # run.gd
var s: RunState


func current() -> Dictionary:
	if s.pending_souls.is_empty():
		return {}
	return s.pending_souls[0]


func describe(h: Dictionary) -> String:
	var cls_name: String = D.HERO_CLASSES[h["cls"]]["name"]
	var trait_line := ""
	if h["trait"] != "":
		var tr_def: Dictionary = D.TRAITS[h["trait"]]
		trait_line = "\nTrait: %s (%s)" % [tr_def["name"], tr_def["desc"]]
	return "%s the %s has fallen.%s\nTheir soul is yours." % [s.hero_name(h), cls_name, trait_line]


func can_raise() -> bool:
	return s.undead_count() < s.jar_cap


func dark_name(h: Dictionary) -> String:
	return D.HERO_CLASSES[h["cls"]]["dark"]


func resolve(choice: String) -> void:
	if s.pending_souls.is_empty():
		return
	if choice == "raise" and not can_raise():
		return
	var h: Dictionary = s.pending_souls.pop_front()
	match choice:
		"raise":
			_raise(h)
		"absorb":
			var hungry := s.has_relic("hungry_dark")
			s.essence += 8 if hungry else 5
			s.gain("blood", D.BLOOD_PER_ABSORB + (2 if hungry else 0))
		"interrogate":
			run.cards.draw_card()
			run.cards.draw_card()
			if s.has_relic("whispering_skull"):
				run.cards.draw_card()
			s.add_log("%s talks: tomorrow brings %d heroes." % [h["name"], HeroSystem.party_size(s.day + 1)])
	s.hand_changed.emit()
	s.souls_changed.emit()


func _raise(h: Dictionary) -> void:
	var hp: float = round(h["max_hp"] * 0.8)
	var col: Color = h["color"]
	var unit := {
		"name": "%s %s" % [dark_name(h), h["name"]], "hp": hp, "max_hp": hp,
		"dmg": h["dmg"] * 1.1, "color": col.darkened(0.55),
		"undead": true, "party": h["party"], "cls": h["cls"],
		"base_dmg": h["dmg"] * 1.1, "base_hp": hp, "gear": {}, "affixes": [],
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
		s.add_log("Their friends swear revenge!")
