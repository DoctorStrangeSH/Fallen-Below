extends "res://tests/ag/unit_case.gd"

const Reg = preload("res://scripts/ag/core/registry.gd")


func test_data_is_consistent() -> void:
	var errors := Reg.validate()
	eq(errors.size(), 0, "registry errors: %s" % str(errors))


func test_slice_counts_match_gdd() -> void:
	# GDD 14: Heart + 5 organs, 5 species, 10 mutations, 3 Order enemies, 1 boss, 3 resources
	eq(Reg.ids("organ").size(), 6, "organs")
	eq(Reg.ids("species").size(), 5, "species")
	eq(Reg.ids("mutation").size(), 10, "mutations")
	eq(Reg.ids("enemy").size(), 3, "enemies")
	eq(Reg.ids("boss").size(), 1, "bosses")
	eq(Reg.ids("resource").size(), 3, "resources")
	eq((Reg.get_def("boss.iron_executioner").get("phases", []) as Array).size(), 3, "executioner phases")


func test_every_mutation_has_a_drawback() -> void:
	for id in Reg.ids("mutation"):
		check(str(Reg.get_def(id).get("drawback", "")) != "", "%s has no drawback" % id)


func test_lookup() -> void:
	check(Reg.has("organ.stomach"), "has stomach")
	check(not Reg.has("organ.nope"), "unknown id")
	eq(Reg.kind_of("species.devourer"), "species", "kind_of")
	check(Reg.get_def("nothing").is_empty(), "missing def is empty")


## Decision options must be exactly those in tools/narrative_check.py (NARR-04 parity).
func test_decisions_match_narrative_check() -> void:
	var src := FileAccess.get_file_as_string("res://tools/narrative_check.py")
	check(src != "", "narrative_check.py readable")
	for id in Reg.ids("decision"):
		var key: String = id.substr(id.find(".") + 1)
		var re := RegEx.create_from_string('"%s":\\s*\\[([^\\]]*)\\]' % key)
		var m := re.search(src)
		check(m != null, "%s present in narrative_check.py" % key)
		if m == null:
			continue
		var opts: Array = []
		for part in m.get_string(1).split(","):
			var t := part.strip_edges().trim_prefix('"').trim_suffix('"')
			if t != "":
				opts.append(t)
		eq(Reg.get_def(id).get("options", []), opts, "%s options" % key)
