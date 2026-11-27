extends "res://tests/ag/unit_case.gd"

const Campaign = preload("res://scripts/ag/core/campaign_state.gd")


func test_decision_written_once() -> void:
	var c = Campaign.new()
	check(c.decide("Z1", "let_speak"), "first decision")
	check(not c.decide("Z1", "silence"), "second decision refused")
	eq(c.decisions["Z1"], "let_speak", "kept first")
	check(not c.decide("E2", "eat_it"), "unknown option refused")


func test_deeds_keep_last_three() -> void:
	var c = Campaign.new()
	for i in 5:
		c.add_deed("aurelia", "deed.%d" % i)
	var last: Array = c.last_deeds("aurelia")
	eq(last.size(), 3, "three deeds")
	eq(str(last[2]["deed"]), "deed.4", "newest last")


func test_round_trip_and_sanitising() -> void:
	var c = Campaign.new()
	c.unlock("species.devourer")
	c.decide("E2", "archive")
	c.notes_found = 3
	c.add_deed("ren", "deed.let_speak")
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", true, true))
	(d["unlocked"] as Array).append("species.removed_long_ago")
	d["notes_found"] = 99
	var back = Campaign.from_dict(d)
	eq(back.unlocked, ["species.devourer"], "unknown ids dropped")
	eq(back.notes_found, 7, "notes clamped")
	eq(back.decisions, {"E2": "archive"}, "decisions kept")
	eq(back.last_deeds("ren").size(), 1, "deeds kept")
