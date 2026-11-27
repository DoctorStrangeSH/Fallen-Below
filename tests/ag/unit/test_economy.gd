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
	return sp


## Grows an organ connected to the Heart (next to the network, channel routed if needed).
func _grow(sp, def_id: String) -> int:
	var g = sp.state.grid
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not sp.organs.can_place(def_id, c)["ok"]:
				continue
			var touches := false
			for fc in sp.organs.footprint_cells(def_id, c):
				for n in g.neighbors(fc):
					if sp.state.network.has(n):
						touches = true
			if touches:
				return sp.organs.place(def_id, c)
	return -1


func _settle(sp, ticks: int = 40) -> void:
	for i in ticks:
		sp.step()


func test_start_stock_and_caps() -> void:
	var sp = _sprout()
	for r in Defs.ECONOMY["start"]:
		eq(sp.economy.amount(r), float(Defs.ECONOMY["start"][r]), "start " + r)
	eq(sp.economy.cap(B), 300.0, "biomass cap from the Heart")
	sp.free()


func test_forecast_equals_fact() -> void:
	var sp = _sprout(3)
	sp.economy.apply(B, 100.0, "Test")
	for id in ["organ.stomach", "organ.sensor", "organ.nerve_node"]:
		check(_grow(sp, id) >= 0, "grew " + id)
	_settle(sp)   # wake-up delays over
	var f: Dictionary = sp.economy.forecast(10.0)
	var before := {}
	for r in [B, E, GN]:
		before[r] = sp.economy.amount(r)
	for i in 100:
		sp.step()
	for r in [B, E, GN]:
		var fact: float = sp.economy.amount(r) - float(before[r])
		check(absf(fact - float(f[r]["net"])) < 0.001, "%s: forecast %.3f, fact %.3f" % [r, f[r]["net"], fact])
	# the forecast explains itself line by line
	check(f[E]["lines"].has("Heart Bud"), "energy line for the Heart")
	check(f[E]["lines"].has("Stomach"), "energy line for the Stomach upkeep")
	check(f[B]["lines"].has("Roots"), "biomass line for the roots")
	sp.free()


func test_ledger_explains_every_change() -> void:
	var sp = _sprout(4)
	sp.economy.apply(B, 150.0, "Test")
	_grow(sp, "organ.incubator")
	_grow(sp, "organ.regen_tissue")
	var far: Vector2i = sp.state.grid.room_center(1)
	var uid: int = sp.organs.place("organ.sensor", far)
	for p in sp.organs.channel_route(far):
		sp.organs.lay_channel(p)
	sp.organs.damage(uid, 30.0)
	sp.economy.add_body("body.pilgrim")
	_settle(sp, 300)
	sp.organs.reabsorb(uid)
	for r in [B, E, GN]:
		var sum := 0.0
		for src in sp.state.ledger.get(r, {}):
			sum += float(sp.state.ledger[r][src])
		check(absf(sum - sp.economy.amount(r)) < 0.001, "%s: ledger %.3f vs stock %.3f" % [r, sum, sp.economy.amount(r)])
		check(sp.economy.amount(r) >= 0.0, r + " never negative")
	check(not sp.state.ledger[B].has("Shortage"), "no unexplained shortage")
	sp.free()


func test_costs_and_reasons() -> void:
	var sp = _sprout(5)
	var c0: float = sp.economy.amount(B)
	var uid := _grow(sp, "organ.incubator")   # costs 30
	eq(sp.economy.amount(B), c0 - 30.0, "incubator paid")
	sp.economy.apply(B, -sp.economy.amount(B), "Test")
	var r: Dictionary = {}
	var g = sp.state.grid
	for y in g.h:
		for x in g.w:
			var t: Dictionary = sp.organs.can_place("organ.stomach", Vector2i(x, y))
			if t["reason"] == "Not enough %s.":
				r = t
	eq(str(r.get("arg", "")), "Biomass", "missing biomass named")
	eq(_grow(sp, "organ.stomach"), -1, "cannot grow without biomass")
	var free := Vector2i(-1, -1)
	for y in g.h:
		for x in g.w:
			if g.is_floor(Vector2i(x, y)) and g.organ_at(Vector2i(x, y)) < 0 and not g.has_channel(Vector2i(x, y)) and not g.is_entrance(Vector2i(x, y)):
				free = Vector2i(x, y)
	check(not sp.organs.lay_channel(free), "channel needs biomass")
	sp.economy.apply(B, 10.0, "Test")
	check(sp.organs.lay_channel(free), "channel laid")
	eq(sp.economy.amount(B), 8.0, "channel cost 2")
	check(sp.organs.reabsorb(uid), "reabsorbed")
	eq(sp.economy.amount(B), 23.0, "half the cost returned")
	sp.free()


func test_deficit_sleeps_by_priority_and_wakes() -> void:
	var sp = _sprout(6)
	sp.economy.apply(B, 200.0, "Test")
	var a := _grow(sp, "organ.incubator")     # upkeep 1.0
	var b := _grow(sp, "organ.stomach")       # 0.5
	var c := _grow(sp, "organ.sensor")        # 0.5
	var d := _grow(sp, "organ.nerve_node")    # 0.5
	var e := _grow(sp, "organ.regen_tissue")  # 0.5
	var f := _grow(sp, "organ.incubator")     # 1.0 -> total 4.0, heart gives 4.0
	var h := _grow(sp, "organ.sensor")        # 0.5 -> 4.5 > 4.0
	for u in [a, b, c, d, e, f, h]:
		check(u >= 0, "grown %d" % u)
	sp.organs.cycle_priority(f)               # f: high priority
	sp.economy.apply(E, -sp.economy.amount(E), "Test")   # empty the energy
	var events := [0]
	sp.state.fx.connect(func(k, _t, _a):
		if k == "organ_sleep" or k == "organ_wake":
			events[0] += 1)
	_settle(sp, 200)
	check(sp.economy.amount(E) >= 0.0, "energy never negative")
	check(sp.economy.net(E) >= -0.0001, "balance restored")
	eq(sp.organs.state_of(f), "normal", "high priority incubator stays awake")
	eq(sp.organs.state_of(a), "asleep", "normal priority, highest upkeep sleeps first")
	check(events[0] <= 3, "no flapping (%d events)" % events[0])
	# freeing energy wakes the sleeper
	sp.organs.reabsorb(f)
	sp.step()
	eq(sp.organs.state_of(a), "normal", "woken when there is room")
	check(not sp.state.ledger[E].has("Shortage"), "no shortage")
	sp.free()


func test_manual_dormancy_saves_upkeep() -> void:
	var sp = _sprout(7)
	var u := _grow(sp, "organ.incubator")
	_settle(sp)
	var before: float = sp.economy.net(E)
	sp.organs.set_dormant(u, true)
	eq(sp.organs.state_of(u), "dormant", "dormant")
	eq(sp.economy.net(E), before + 1.0, "no upkeep while dormant")
	sp.organs.set_dormant(u, false)
	check(sp.organs.state_of(u) != "dormant", "awake again")
	sp.free()


func test_digestion_yields_exactly() -> void:
	var sp = _sprout(8)
	sp.economy.apply(B, 50.0, "Test")
	var st := _grow(sp, "organ.stomach")
	_settle(sp)
	var g0: float = sp.economy.amount(GN)
	sp.economy.add_body("body.burner")   # mass 35, genome 10, speed 3/s -> 11.67 s
	_settle(sp, 130)
	check(sp.state.bodies.is_empty(), "body digested")
	check(absf(sp.economy.amount(GN) - g0 - 10.0) < 0.01, "genome +10 (got %.3f)" % (sp.economy.amount(GN) - g0))
	check(absf(float(sp.state.ledger[B]["Digestion"]) - 28.0) < 0.01, "biomass +28 from digestion")
	sp.organs.set_dormant(st, true)
	sp.economy.add_body("body.pilgrim")
	_settle(sp, 50)
	eq(sp.state.bodies.size(), 1, "a dormant stomach digests nothing")
	sp.free()


func test_regeneration_costs_biomass() -> void:
	var sp = _sprout(9)
	sp.economy.apply(B, 100.0, "Test")
	var rt := _grow(sp, "organ.regen_tissue")
	_settle(sp)
	var heart: int = sp.organs.heart_uid()
	sp.organs.damage(heart, 40.0, "physical")
	var hp0: float = float(sp.state.organs[heart]["hp"])
	var spent0: float = float(sp.state.ledger[B].get("Regeneration", 0.0))
	_settle(sp, 50)
	var healed: float = float(sp.state.organs[heart]["hp"]) - hp0
	var spent: float = -(float(sp.state.ledger[B].get("Regeneration", 0.0)) - spent0)
	check(healed > 5.0, "heart healed (%.2f)" % healed)
	check(absf(spent - healed * float(Defs.ECONOMY["regen_cost"])) < 0.01, "biomass spent %.3f for %.3f hp" % [spent, healed])
	check(rt >= 0, "tissue grown")
	sp.free()


func test_impulses_from_nerve_nodes() -> void:
	var sp = _sprout(10)
	eq(sp.economy.impulse_cap(), 3.0, "base cap")
	_grow(sp, "organ.nerve_node")
	_settle(sp, 100)
	eq(sp.economy.impulse_cap(), 5.0, "cap with a node")
	check(sp.state.impulses > 1.0, "impulses accumulate")
	_settle(sp, 400)
	eq(sp.state.impulses, 5.0, "capped")
	sp.free()


func test_save_keeps_economy() -> void:
	var sp = _sprout(11)
	_grow(sp, "organ.stomach")
	sp.economy.add_body("body.knight")
	_settle(sp, 25)
	var back = Sprout.from_dict(JSON.parse_string(JSON.stringify(sp.state.to_dict())))
	eq(back.state_hash(), sp.state.state_hash(), "same state")
	eq(back.bodies.size(), 1, "body queue kept")
	sp.free()
