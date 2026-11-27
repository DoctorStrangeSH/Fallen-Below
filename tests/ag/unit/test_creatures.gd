extends "res://tests/ag/unit_case.gd"

const SproutRoot = preload("res://scripts/ag/run/sprout.gd")
const Sprout = preload("res://scripts/ag/run/sprout_state.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

const B := "resource.biomass"
const E := "resource.energy"
const GN := "resource.genome"


func _sprout(seed_value: int = 2):
	var sp = SproutRoot.new()
	sp.start(seed_value)
	sp.economy.apply(B, 300.0, "Test")
	sp.economy.apply(GN, 100.0, "Test")
	return sp


func _grow(sp, def_id: String) -> int:
	var g = sp.state.grid
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not sp.organs.can_place(def_id, c)["ok"]:
				continue
			for fc in sp.organs.footprint_cells(def_id, c):
				for n in g.neighbors(fc):
					if sp.state.network.has(n):
						return sp.organs.place(def_id, c)
	return -1


func _run(sp, ticks: int) -> void:
	for i in ticks:
		sp.step()


func _heart_cell(sp) -> Vector2i:
	return sp.organs.cells_of(sp.organs.heart_uid())[0]


## A walkable cell at least `dist` path cells away from the Heart (deterministic).
func _far_cell(sp, dist: int) -> Vector2i:
	var g = sp.state.grid
	for e in g.entrances:
		var p: Array = sp.creatures.paths.path(e, sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))[0])
		if p.size() >= dist:
			return e
	return g.entrances[0]


func test_breeding_pays_waits_and_spawns() -> void:
	var sp = _sprout(3)
	var inc := _grow(sp, "organ.incubator")
	_run(sp, 40)
	var b0: float = sp.economy.amount(B)
	check(sp.creatures.queue_breed(inc, "species.bone_crawler"), "queued")
	eq(sp.economy.amount(B), b0 - 18.0, "paid on queue")
	_run(sp, 100)
	eq(sp.creatures.team_units("abyss").size(), 0, "not yet (20 s)")
	_run(sp, 105)
	eq(sp.creatures.team_units("abyss").size(), 1, "born")
	var u: Dictionary = sp.state.units[sp.creatures.team_units("abyss")[0]]
	var c: Vector2i = sp.creatures.cell_of(u)
	var touches := false
	for oc in sp.organs.cells_of(inc):
		if absi(oc.x - c.x) + absi(oc.y - c.y) == 1:
			touches = true
	check(touches, "born next to the Incubator")
	# a sleeping incubator does not grow anything
	sp.creatures.queue_breed(inc, "species.blood_tick")
	sp.organs.set_dormant(inc, true)
	_run(sp, 200)
	eq(sp.creatures.team_units("abyss").size(), 1, "dormant incubator waits")
	check(not sp.creatures.can_breed(inc, "species.zero")["ok"], "Zero cannot be bred")
	sp.free()


func test_invader_reaches_and_hurts_the_heart() -> void:
	var sp = _sprout(4)
	var e: int = sp.creatures.spawn_enemy("enemy.pilgrim", sp.state.grid.entrances[0])
	check(e >= 0, "spawned")
	var hp0: float = float(sp.state.organs[sp.organs.heart_uid()]["hp"])
	_run(sp, 900)
	check(float(sp.state.organs[sp.organs.heart_uid()]["hp"]) < hp0, "heart damaged")
	eq(int(sp.state.stats.get("targets_dropped", 0)), 0, "never gave up")
	sp.free()


func test_defender_engages_and_returns() -> void:
	var sp = _sprout(5)
	var stand: Vector2i = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))[0]
	var d: int = sp.creatures.spawn_creature("species.bone_crawler", stand)
	var e: int = sp.creatures.spawn_enemy("enemy.pilgrim", sp.state.grid.entrances[1])
	var engaged := false
	for i in 1500:
		sp.step()
		if sp.state.units.has(d) and str(sp.state.units[d]["state"]) == "engage":
			engaged = true
		if not sp.state.units.has(e):
			break
	check(engaged, "defender engaged")
	check(not sp.state.units.has(e), "pilgrim killed")
	_run(sp, 200)
	check(sp.state.units.has(d), "defender alive")
	eq(sp.creatures.cell_of(sp.state.units[d]), stand, "back at its post")
	eq(sp.state.bodies.size(), 1, "body goes to the Stomach queue")
	sp.free()


func test_hunter_answers_an_attacked_organ() -> void:
	var sp = _sprout(6)
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	var h: int = sp.creatures.spawn_creature("species.devourer", stand[stand.size() - 1])
	sp.state.units[h]["sight"] = 1.0   # blind it: it must react to the alarm, not to sight
	sp.organs.damage(sp.organs.heart_uid(), 5.0)
	sp.step()
	eq(str(sp.state.units[h]["state"]), "protect", "goes to protect the organ")
	sp.free()


func test_path_replans_when_an_organ_grows_in_the_way() -> void:
	var sp = _sprout(7)
	var g = sp.state.grid
	var from: Vector2i = _far_cell(sp, 12)
	var u: int = sp.creatures.spawn_creature("species.devourer", from)
	sp.state.units[u]["home"] = [_heart_cell(sp).x - 2, _heart_cell(sp).y]
	var home: Vector2i = sp.creatures.home_of(sp.state.units[u])
	if not g.walkable(home):
		home = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))[0]
		sp.state.units[u]["home"] = [home.x, home.y]
	_run(sp, 5)
	var p: Array = sp.state.units[u]["path"]
	check(p.size() > 4, "walking home")
	# grow an organ on its route (where allowed), the unit must re-plan, never stand inside it
	var blocked := false
	for k in range(2, p.size() - 1):
		var c := Vector2i(int(p[k][0]), int(p[k][1]))
		if sp.organs.place("organ.sensor", c) >= 0:
			blocked = true
			break
	check(blocked, "an organ grew on the route")
	var inside := false
	for i in 600:
		sp.step()
		var cc: Vector2i = sp.creatures.cell_of(sp.state.units[u])
		if g.organ_at(cc) >= 0:
			inside = true
	check(not inside, "never walks through an organ")
	sp.free()


func test_breach_when_walled_off() -> void:
	var sp = _sprout(8)
	var g = sp.state.grid
	# wall the Heart in with sensors on every free cell around it
	for c in sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid())):
		sp.organs.place("organ.sensor", c)
	check(sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid())).is_empty(), "heart walled in")
	var e: int = sp.creatures.spawn_enemy("enemy.pilgrim", g.entrances[0])
	var hurt := false
	sp.state.fx.connect(func(k, _t, _a):
		if k == "organ_hit":
			hurt = true)
	_run(sp, 1200)
	check(hurt or int(sp.state.stats.get("breaches", 0)) > 0, "tears through the wall")
	check(int(sp.state.stats.get("breaches", 0)) > 0, "breach counted")
	check(e >= 0, "spawned")
	sp.free()


func test_stealth_and_first_strike() -> void:
	var sp = _sprout(9)
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	var st: int = sp.creatures.spawn_creature("species.nerve_stalker", stand[0])
	check(bool(sp.state.units[st]["hidden"]), "starts hidden")
	var k: int = sp.creatures.spawn_enemy("enemy.knight", stand[0])
	sp.state.units[k]["aggro_t"] = 0.0
	var knight_seen: Array = sp.creatures._visible_enemies(sp.state.units[k], sp.creatures.pos_of(sp.state.units[k]), 5.0)
	check(not knight_seen.has(st), "the knight cannot see it")
	var b: int = sp.creatures.spawn_enemy("enemy.burner", stand[0])
	var burner_seen: Array = sp.creatures._visible_enemies(sp.state.units[b], sp.creatures.pos_of(sp.state.units[b]), 5.0)
	check(burner_seen.has(st), "the burner sees hidden things")
	var hp0: float = float(sp.state.units[k]["hp"])
	sp.creatures._strike_unit(st, k)
	eq(hp0 - float(sp.state.units[k]["hp"]), 10.0 * 2.0 - 4.0, "first strike doubles before armour")
	check(not bool(sp.state.units[st]["hidden"]), "revealed by attacking")
	sp.free()


func test_zero_embody_storm_and_fall() -> void:
	var sp = _sprout(10)
	var b0: float = sp.economy.amount(B)
	var z: int = sp.creatures.embody_zero()
	check(z >= 0, "embodied")
	eq(sp.economy.amount(B), b0 - 40.0, "embody cost")
	check(not sp.creatures.can_embody_zero()["ok"], "only one Zero")
	var stand: Vector2i = sp.creatures.cell_of(sp.state.units[z])
	var e: int = sp.creatures.spawn_enemy("enemy.knight", stand)
	var hp0: float = float(sp.state.units[e]["hp"])
	check(sp.creatures.zero_storm(), "storm hits")
	eq(hp0 - float(sp.state.units[e]["hp"]), 6.0 * 2.0, "double damage")
	check(not sp.creatures.zero_storm(), "on cooldown")
	sp.state.units[z]["hp"] = 0.0
	sp.step()
	check(sp.state.zero_dead, "Zero fell")
	check(not sp.state.lost, "the sprout goes on without him")
	check(not sp.creatures.can_embody_zero()["ok"], "not again in this sprout")
	sp.free()


func test_zero_levels_from_kills() -> void:
	var sp = _sprout(11)
	var z: int = sp.creatures.embody_zero()
	var zu: Dictionary = sp.state.units[z]
	var atk0: float = float(zu["atk"])
	for i in 3:
		var e: int = sp.creatures.spawn_enemy("enemy.pilgrim", sp.creatures.cell_of(zu))
		sp.state.units[e]["hp"] = 1.0
		sp.creatures._strike_unit(z, e)
		zu["cd"] = 0.0
	eq(int(zu["level"]), 2, "level 2 after 3 kills (12 xp)")
	eq(float(zu["atk"]), atk0 + 1.0, "stronger")
	sp.free()


func test_starving_creatures_weaken_without_shortage() -> void:
	var sp = _sprout(12)
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	for i in 12:
		sp.creatures.spawn_creature("species.devourer", stand[i % stand.size()])   # 12 x 0.4 = 4.8 > 4.0
	sp.economy.apply(E, -sp.economy.amount(E), "Test")
	_run(sp, 30)
	check(sp.state.starving, "starving")
	check(float(sp.state.units[sp.creatures.team_units("abyss")[0]]["hp"]) < 60.0, "losing health")
	check(not sp.state.ledger[E].has("Shortage"), "no unexplained energy loss")
	check(sp.economy.amount(E) >= 0.0, "energy not negative")
	sp.free()


func _scenario(seed_value: int):
	var sp = _sprout(seed_value)
	_grow(sp, "organ.stomach")
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	sp.creatures.spawn_creature("species.bone_crawler", stand[0])
	sp.creatures.spawn_creature("species.devourer", stand[1])
	sp.creatures.spawn_creature("species.lymphatic", stand[2])
	sp.creatures.embody_zero()
	for e in sp.state.grid.entrances:
		sp.creatures.spawn_enemy("enemy.knight", e)
	return sp


func test_same_seed_same_fight() -> void:
	var a = _scenario(13)
	var b = _scenario(13)
	_run(a, 600)
	_run(b, 600)
	eq(a.state.state_hash(), b.state.state_hash(), "identical after 60 s")
	a.free()
	b.free()


func test_save_mid_fight_continues_identically() -> void:
	var a = _scenario(14)
	_run(a, 150)
	var b = SproutRoot.new()
	b.resume(Sprout.unpack(a.state.pack()))
	eq(b.state.state_hash(), a.state.state_hash(), "same right after loading")
	_run(a, 300)
	_run(b, 300)
	eq(b.state.state_hash(), a.state.state_hash(), "same 30 s later")
	a.free()
	b.free()


func test_destroyed_organ_frees_the_way() -> void:
	var sp = _sprout(15)
	var g = sp.state.grid
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	var c: Vector2i = stand[0]
	var uid: int = sp.organs.place("organ.sensor", c)
	sp.step()
	check(sp.creatures.paths.walk.is_point_solid(c), "organ blocks the way")
	sp.organs.damage(uid, 9999.0)
	sp.step()
	check(not sp.creatures.paths.walk.is_point_solid(c), "the cell is free again after the organ died")
	check(g.walkable(c), "grid agrees")
	sp.free()


func test_unreachable_home_becomes_new_post() -> void:
	var sp = _sprout(16)
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	var u: int = sp.creatures.spawn_creature("species.devourer", stand[0])
	var home: Vector2i = sp.state.grid.entrances[0]
	sp.state.units[u]["home"] = [home.x, home.y]
	sp.state.grid.floor[sp.state.grid.idx(home)] = 0   # the way home collapsed
	sp.state.grid_version += 1
	_run(sp, 20)
	eq(sp.creatures.home_of(sp.state.units[u]), stand[0], "stays and makes this its post")
	eq(str(sp.state.units[u]["state"]), "idle", "idle, not stuck walking")
	sp.free()
