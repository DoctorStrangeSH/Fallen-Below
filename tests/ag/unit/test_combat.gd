extends "res://tests/ag/unit_case.gd"

const SproutRoot = preload("res://scripts/ag/run/sprout.gd")
const Sprout = preload("res://scripts/ag/run/sprout_state.gd")
const Log = preload("res://scripts/ag/systems/combat_log.gd")

const B := "resource.biomass"
const GN := "resource.genome"


func _sprout(seed_value: int = 2):
	var sp = SproutRoot.new()
	sp.start(seed_value)
	sp.economy.apply(B, 300.0, "Test")
	sp.economy.apply(GN, 120.0, "Test")
	sp.state.impulses = 10.0
	return sp


func _stand(sp) -> Array:
	return sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))


func _run(sp, n: int) -> void:
	for i in n:
		sp.step()


func test_focus_overrides_choice_and_costs_impulses() -> void:
	var sp = _sprout(3)
	var st: Array = _stand(sp)
	var d: int = sp.creatures.spawn_creature("species.devourer", st[0])
	var near: int = sp.creatures.spawn_enemy("enemy.pilgrim", st[0])
	var far: int = sp.creatures.spawn_enemy("enemy.knight", st[st.size() - 1])
	sp.state.units[near]["hp"] = 1000.0
	sp.state.units[near]["max_hp"] = 1000.0
	check(sp.commands.issue("command.focus", far), "focus issued")
	eq(sp.state.impulses, 9.0, "one impulse")
	check(not sp.commands.check("command.focus", far)["ok"], "cooldown")
	_run(sp, 3)
	eq(int(sp.state.units[d]["target"]), far, "attacks the focused knight, not the nearer pilgrim")
	sp.free()


func test_reach_and_insulation_cost() -> void:
	var sp = _sprout(4)
	var g = sp.state.grid
	var e: int = sp.creatures.spawn_enemy("enemy.pilgrim", g.entrances[0])
	sp.creatures.spawn_creature("species.devourer", g.entrances[0])
	var r: Dictionary = sp.commands.check("command.focus", e)
	if not sp.commands.in_reach(g.entrances[0]):
		eq(str(r["reason"]), "Out of the nerves' reach. Grow a Nerve Node closer.", "out of reach")
	var st: Array = _stand(sp)
	sp.creatures.spawn_creature("species.bone_crawler", st[0])
	sp.creatures.spawn_creature("species.bone_crawler", st[1])
	sp.genetics.mutate("species.bone_crawler", "mutation.nerve_insulation")   # living members get it at once
	var k: int = sp.creatures.spawn_enemy("enemy.knight", st[0])
	var c: Dictionary = sp.commands.check("command.focus", k)
	eq(int(c["cost"]), 3, "1 + 1 per insulated creature")
	sp.free()


func test_protect_holds_creatures_at_the_organ() -> void:
	var sp = _sprout(5)
	var st: Array = _stand(sp)
	var u: int = sp.creatures.spawn_creature("species.bone_crawler", st[0])
	var inc := -1
	var g = sp.state.grid
	for y in g.h:
		for x in g.w:
			if inc < 0 and sp.organs.can_place("organ.sensor", Vector2i(x, y))["ok"] and Vector2(st[0]).distance_to(Vector2(x, y)) > 4.0 and Vector2(st[0]).distance_to(Vector2(x, y)) < 8.0:
				inc = sp.organs.place("organ.sensor", Vector2i(x, y))
	check(inc >= 0, "organ grown")
	check(sp.commands.issue("command.protect", inc), "protect")
	_run(sp, 110)
	var at: Vector2i = sp.creatures.cell_of(sp.state.units[u])
	check(sp.creatures.paths.stand_cells(sp.organs.cells_of(inc)).has(at), "guards the organ")
	_run(sp, 20)
	check(sp.state.units[u]["order"] == "", "order ends after 12 s")
	sp.free()


func test_seal_closes_and_reopens() -> void:
	var sp = _sprout(6)
	var g = sp.state.grid
	var st: Array = _stand(sp)
	var c: Vector2i = st[0]
	check(not sp.commands.check("command.seal", g.entrances[0])["ok"], "entrance cannot be sealed")
	check(sp.commands.issue("command.seal", c), "sealed")
	check(not g.walkable(c), "closed")
	sp.step()
	check(sp.creatures.paths.walk.is_point_solid(c), "paths avoid it")
	_run(sp, 101)
	check(g.walkable(c), "open again after 10 s")
	sp.step()
	check(not sp.creatures.paths.walk.is_point_solid(c), "paths use it again")
	sp.free()


func test_emergency_regeneration() -> void:
	var sp = _sprout(7)
	var hu: int = sp.organs.heart_uid()
	sp.organs.damage(hu, 200.0)
	var b0: float = sp.economy.amount(B)
	check(sp.commands.issue("command.regen", null), "regen")
	eq(float(sp.state.organs[hu]["hp"]), 280.0, "heart +20%")
	eq(sp.economy.amount(B), b0 - 10.0, "costs biomass")
	eq(sp.state.impulses, 7.0, "three impulses")
	sp.free()


func test_minds_three_choices() -> void:
	var sp = _sprout(8)
	var st: Array = _stand(sp)
	var z: int = sp.creatures.embody_zero()
	var ids: Array = []
	for i in 3:
		var k: int = sp.creatures.spawn_enemy("enemy.knight", st[0])
		sp.state.units[k]["hp"] = 0.0
	sp.step()
	eq(sp.state.minds.size(), 3, "three minds wait")
	for m in sp.state.minds:
		ids.append(int(m["id"]))
	var b0: float = sp.economy.amount(B)
	check(sp.minds.resolve(ids[0], "digest"), "digest")
	eq(sp.economy.amount(B), b0 + 10.0, "biomass from the mind")
	var e0: float = sp.economy.net("resource.energy")
	check(sp.minds.resolve(ids[1], "archive"), "keep")
	eq(sp.state.kept_minds, 1, "kept")
	check(absf(sp.economy.net("resource.energy") - (e0 - 0.2)) < 0.0001, "kept minds cost energy")
	var xp0: int = int(sp.state.units[z]["xp"])
	check(sp.minds.resolve(ids[2], "zero"), "to Zero")
	eq(int(sp.state.units[z]["xp"]), xp0 + 6, "Zero learns")
	eq(int(sp.state.stats["minds_digested"]), 1, "counted for the story")
	eq(int(sp.state.stats["minds_archived"]), 1, "counted")
	eq(int(sp.state.stats["minds_to_zero"]), 1, "counted")
	sp.free()


func test_minds_wait_only_while_time_runs() -> void:
	var sp = _sprout(9)
	var st: Array = _stand(sp)
	var k: int = sp.creatures.spawn_enemy("enemy.pilgrim", st[0])
	sp.state.units[k]["hp"] = 0.0
	sp.step()
	eq(sp.state.minds.size(), 1, "waiting")
	check(not sp.minds.can(int(sp.state.minds[0]["id"]), "zero")["ok"], "no Zero, no feeding")
	sp.minds.set_stance("archive")
	_run(sp, 99)
	eq(sp.state.minds.size(), 1, "still waiting at 9.9 s")
	sp.step()
	eq(sp.state.minds.size(), 0, "decided by the stance")
	eq(sp.state.kept_minds, 1, "kept by default stance")
	sp.free()


func test_every_death_is_explained() -> void:
	var total := 0
	for sd in 12:
		var sp = _sprout(20 + sd)
		var st: Array = _stand(sp)
		sp.genetics.mutate("species.bone_crawler", "mutation.acid_blood")
		for i in 4:
			sp.creatures.spawn_creature(["species.bone_crawler", "species.blood_tick", "species.devourer", "species.nerve_stalker"][i], st[i % st.size()])
		sp.creatures.embody_zero()
		for e in sp.state.grid.entrances:
			sp.creatures.spawn_enemy("enemy.knight", e)
			sp.creatures.spawn_enemy("enemy.burner", e)
		_run(sp, 900)
		for entry in sp.state.combat_log:
			total += 1
			var d: Array = Log.describe(entry)
			check(not str(d[0]).contains("died of %s") or d[1][1] != "wounds", "no unexplained death: %s" % str(entry))
			check(str(entry["by"]) != "" or ["starvation", "infection"].has(str(entry["reason"])), "a cause: %s" % str(entry))
		var deaths := int(sp.state.stats.get("invaders_killed", 0)) + int(sp.state.stats.get("creatures_lost", 0))
		check(int(sp.state.stats.get("deaths_logged", 0)) >= deaths, "every death logged")
		sp.free()
	check(total > 20, "enough deaths to judge (%d)" % total)


func test_same_commands_same_fight() -> void:
	var hashes: Array = []
	for run in 2:
		var sp = _sprout(30)
		var st: Array = _stand(sp)
		for i in 3:
			sp.creatures.spawn_creature("species.devourer", st[i])
		for e in sp.state.grid.entrances:
			sp.creatures.spawn_enemy("enemy.knight", e)
		for t in 600:
			if t == 120:
				sp.commands.issue("command.seal", st[3])
			if t == 200:
				sp.commands.issue("command.regen", null)
			if t == 250 and not sp.creatures.team_units("order").is_empty():
				sp.commands.issue("command.focus", sp.creatures.team_units("order")[0])
			sp.step()
		hashes.append(sp.state.state_hash())
		sp.free()
	eq(hashes[0], hashes[1], "identical")
