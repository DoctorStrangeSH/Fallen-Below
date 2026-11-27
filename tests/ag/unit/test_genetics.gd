extends "res://tests/ag/unit_case.gd"

const SproutRoot = preload("res://scripts/ag/run/sprout.gd")
const Sprout = preload("res://scripts/ag/run/sprout_state.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

const B := "resource.biomass"
const GN := "resource.genome"


func _sprout(seed_value: int = 2):
	var sp = SproutRoot.new()
	sp.start(seed_value)
	sp.economy.apply(B, 300.0, "Test")
	sp.economy.apply(GN, 120.0, "Test")
	return sp


func _stand(sp) -> Array:
	return sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))


func _place(sp, def_id: String) -> int:
	var g = sp.state.grid
	var r: Rect2i = g.rooms[g.heart_room]
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not sp.organs.can_place(def_id, c)["ok"]:
				continue
			for fc in sp.organs.footprint_cells(def_id, c):
				for n in g.neighbors(fc):
					if sp.state.network.has(n):
						return sp.organs.place(def_id, c)
	return -1


## Breeds n offspring of a line through the real birth path (inheritance + stats).
func _broods(sp, species: String, n: int) -> Array:
	var out: Array = []
	var c: Vector2i = _stand(sp)[0]
	for i in n:
		var uid: int = sp.creatures.spawn_creature(species, c)
		out.append((sp.state.units[uid] as Dictionary).duplicate(true))
		sp.state.units.erase(uid)
	return out


func test_compatibility_rules() -> void:
	var sp = _sprout()
	var g = sp.genetics
	check(g.mutate("species.devourer", "mutation.bone_plate"), "bone plate on devourers")
	var r: Dictionary = g.can_mutate("species.devourer", "mutation.swift_tendons")
	eq(str(r["reason"]), "Incompatible with %s.", "excluded pair refused")
	eq(str(r.get("arg", "")), "Bone Plate", "names the conflicting mutation")
	check(not g.can_mutate("species.devourer", "mutation.bone_plate")["ok"], "no duplicates")
	check(g.mutate("species.devourer", "mutation.dense_tissue"), "second slot")
	eq(str(g.can_mutate("species.devourer", "mutation.dark_sight")["reason"]), "No free mutation slot.", "two slots for a strain")
	eq(str(g.can_mutate("organ.stomach", "mutation.acid_blood")["reason"]), "This mutation cannot grow on organs.", "creature-only mutation")
	check(g.can_mutate("organ.stomach", "mutation.fireproof_shell")["ok"], "organ mutation allowed")
	eq(g.slots("species.zero"), 3, "Zero has three slots")
	sp.economy.apply(GN, -sp.economy.amount(GN), "Test")
	eq(str(g.can_mutate("species.lymphatic", "mutation.dark_sight")["reason"]), "Not enough %s.", "needs genome")
	sp.free()


func test_mutation_reaches_living_and_future_members() -> void:
	var sp = _sprout(3)
	var u: int = sp.creatures.spawn_creature("species.bone_crawler", _stand(sp)[0])
	var g0: float = sp.economy.amount(GN)
	check(sp.genetics.mutate("species.bone_crawler", "mutation.dense_tissue"), "mutated")
	eq(sp.economy.amount(GN), g0 - 10.0, "paid genome")
	eq(float(sp.state.units[u]["max_hp"]), 90.0 * 1.25, "living member got +25% health")
	eq(float(sp.state.units[u]["hp"]), 90.0 * 1.25, "health ratio kept")
	eq(float(sp.state.units[u]["atk"]), 6.0 * 0.9, "and its drawback")
	var kids := _broods(sp, "species.bone_crawler", 5)
	for k in kids:
		check((k["mutations"] as Array).has("mutation.dense_tissue"), "dominant always inherited")
	sp.free()


func test_recessive_inheritance_matches_forecast() -> void:
	var sp = _sprout(4)
	sp.genetics.mutate("species.lymphatic", "mutation.dark_sight")         # recessive
	sp.genetics.mutate("species.lymphatic", "mutation.regenerative_tissue")  # recessive
	var f: Dictionary = sp.genetics.forecast("species.lymphatic")
	eq(f["mutations"], [["mutation.dark_sight", 0.5], ["mutation.regenerative_tissue", 0.5]], "forecast")
	var kids := _broods(sp, "species.lymphatic", 400)
	var n := 0
	for k in kids:
		if (k["mutations"] as Array).has("mutation.dark_sight"):
			n += 1
	check(absf(n / 400.0 - 0.5) < 0.08, "recessive about half (%d / 400)" % n)
	# determinism: the same seed breeds the same children
	var sp2 = _sprout(4)
	sp2.genetics.mutate("species.lymphatic", "mutation.dark_sight")
	sp2.genetics.mutate("species.lymphatic", "mutation.regenerative_tissue")
	var kids2 := _broods(sp2, "species.lymphatic", 400)
	var same := true
	for i in 400:
		if kids[i]["mutations"] != kids2[i]["mutations"]:
			same = false
	check(same, "same seed, same broods")
	sp.free()
	sp2.free()


func test_combos_defect_and_rare_trait() -> void:
	var sp = _sprout(5)
	sp.genetics.mutate("species.blood_tick", "mutation.acid_blood")           # dominant
	sp.genetics.mutate("species.blood_tick", "mutation.regenerative_tissue")  # recessive
	var f: Dictionary = sp.genetics.forecast("species.blood_tick")
	eq(f["results"], [["defect.unstable_flesh", 0.5]], "defect forecast 50%")
	var kids := _broods(sp, "species.blood_tick", 300)
	var bad := 0
	for k in kids:
		var has_both: bool = (k["mutations"] as Array).has("mutation.acid_blood") and (k["mutations"] as Array).has("mutation.regenerative_tissue")
		eq((k["defects"] as Array).has("defect.unstable_flesh"), has_both, "defect exactly when both inherited")
		if has_both:
			bad += 1
			check(absf(float(k["max_hp"]) - 30.0 * 0.9 * 0.8) < 0.01, "defect lowers health")
	check(absf(bad / 300.0 - 0.5) < 0.09, "defect about half (%d)" % bad)
	check(sp.state.recipes.has("mutation.acid_blood+mutation.regenerative_tissue"), "recipe remembered")
	sp.genetics.mutate("species.bone_crawler", "mutation.bone_plate")
	sp.genetics.mutate("species.bone_crawler", "mutation.fireproof_shell")
	var crawlers := _broods(sp, "species.bone_crawler", 400)
	var rare := 0
	for k in crawlers:
		if (k["traits"] as Array).has("trait.ash_carapace"):
			rare += 1
			eq(float(k["resist"]["fire"]), 1.0, "ash carapace: immune to fire")
	check(absf(rare / 400.0 - 0.25) < 0.07, "rare trait about 25%% (%d)" % rare)
	sp.free()


func test_invalid_traits_are_never_inherited() -> void:
	var sp = _sprout(6)
	# a corrupted line (old save, edited data): excluded pair, unknown id, organ-only, too many
	sp.state.strains["species.devourer"] = ["mutation.bone_plate", "mutation.swift_tendons", "mutation.removed_in_patch", "mutation.dense_tissue", "mutation.dark_sight"]
	var kids := _broods(sp, "species.devourer", 100)
	for k in kids:
		var m: Array = k["mutations"]
		check(not (m.has("mutation.bone_plate") and m.has("mutation.swift_tendons")), "never both excluded")
		check(not m.has("mutation.removed_in_patch"), "unknown dropped")
		check(m.size() <= 2, "slot limit kept")
	check(int(sp.state.stats.get("invalid_dropped", 0)) > 0, "drops counted")
	sp.free()


func test_effects_in_combat() -> void:
	var sp = _sprout(7)
	var c: Vector2i = _stand(sp)[0]
	sp.genetics.mutate("species.devourer", "mutation.fireproof_shell")
	var d: int = sp.creatures.spawn_creature("species.devourer", c)
	var b: int = sp.creatures.spawn_enemy("enemy.burner", c)
	var hp0: float = float(sp.state.units[d]["hp"])
	sp.creatures._strike_unit(b, d)
	eq(hp0 - float(sp.state.units[d]["hp"]), (8.0 - 1.0) * 0.5, "fire halved after armour")
	# acid blood burns the attacker
	sp.genetics.mutate("species.bone_crawler", "mutation.acid_blood")
	var a: int = sp.creatures.spawn_creature("species.bone_crawler", c)
	var k: int = sp.creatures.spawn_enemy("enemy.knight", c)
	var khp: float = float(sp.state.units[k]["hp"])
	sp.creatures._strike_unit(k, a)
	eq(khp - float(sp.state.units[k]["hp"]), 3.0, "thorns")
	# dark sight
	sp.genetics.mutate("species.lymphatic", "mutation.dark_sight")
	var stalker: int = sp.creatures.spawn_enemy("enemy.pilgrim", c)
	sp.state.units[stalker]["hidden"] = true
	var l: int = -1
	for i in 10:
		l = sp.creatures.spawn_creature("species.lymphatic", c)
		if (sp.state.units[l]["mutations"] as Array).has("mutation.dark_sight"):
			break
	check(bool(sp.state.units[l]["sees_hidden"]), "dark sight sees hidden")
	eq(float(sp.state.units[l]["weak"].get("holy", 0.0)), 0.25, "and fears holy light")
	sp.free()


func test_organ_mutations() -> void:
	var sp = _sprout(8)
	var st: int = _place(sp, "organ.stomach")
	check(st >= 0, "stomach")
	var e0: float = sp.economy.net("resource.energy")
	check(sp.genetics.mutate("organ.stomach", "mutation.bone_plate"), "mutate organ line")
	eq(sp.economy.net("resource.energy"), e0 - 0.2, "organ drawback: upkeep in the forecast")
	var dealt: float = sp.organs.damage(st, 10.0, "physical")
	eq(dealt, 7.0, "30% less physical damage")
	var st2: int = _place(sp, "organ.stomach")
	check((sp.state.organs[st2]["mutations"] as Array).has("mutation.bone_plate"), "new organs of the type grow with it")
	sp.free()


func _burn(sp, organ_uid: int, total: float) -> void:
	var hit := 10.0
	var n := int(total / hit)
	for i in n:
		sp.organs.damage(organ_uid, hit / 0.75, "fire", "enemy.burner")   # incubator: weak to fire 0.25
		sp.organs.heal(organ_uid, 999.0)


func test_adaptation_offer_accept_and_reasons() -> void:
	var sp = _sprout(9)
	var inc: int = _place(sp, "organ.incubator")
	_burn(sp, inc, 150.0)
	for i in 10:
		sp.step()
	eq(sp.state.proposals.size(), 1, "one offer")
	var p: Dictionary = sp.state.proposals[0]
	eq(str(p["mutation"]), "mutation.fireproof_shell", "answer to fire")
	eq(str(p["line"]), "organ.incubator", "for the organ that burned")
	eq(str(p["attacker"]), "enemy.burner", "names who did it")
	check(float(p["amount"]) >= 120.0, "how much")
	var why: Array = sp.evolution.reason(p)
	check(str(why[0]).contains("%s dealt %d"), "reason text")
	eq(p["cost"], {GN: 7.0}, "half price")
	var g0: float = sp.economy.amount(GN)
	check(sp.evolution.accept(int(p["id"])), "accepted")
	eq(sp.economy.amount(GN), g0 - 7.0, "paid half")
	check((sp.state.organs[inc]["mutations"] as Array).has("mutation.fireproof_shell"), "applied")
	check(sp.state.proposals.is_empty(), "offer gone")
	_burn(sp, inc, 200.0)
	for i in 10:
		sp.step()
	check(sp.state.proposals.is_empty(), "no repeat during the cooldown")
	sp.free()


func test_adaptation_reject_and_expire() -> void:
	var sp = _sprout(10)
	var inc: int = _place(sp, "organ.incubator")
	_burn(sp, inc, 150.0)
	for i in 10:
		sp.step()
	var pid: int = int(sp.state.proposals[0]["id"])
	sp.evolution.reject(pid)
	check(sp.state.proposals.is_empty(), "rejected")
	check(not (sp.state.organs[inc]["mutations"] as Array).has("mutation.fireproof_shell"), "nothing changed by itself")
	check(sp.state.adapt_cd.has("fire"), "fire rests")
	for i in 650:
		sp.step()
	_burn(sp, inc, 150.0)
	for i in 10:
		sp.step()
	eq(sp.state.proposals.size(), 1, "offered again after the rest")
	for i in 460:
		sp.step()
	check(sp.state.proposals.is_empty(), "expires after 45 s")
	sp.free()


func test_swarm_offer() -> void:
	var sp = _sprout(11)
	sp.creatures.spawn_creature("species.bone_crawler", _stand(sp)[0])
	for i in 5:
		sp.creatures.spawn_enemy("enemy.pilgrim", sp.state.grid.entrances[0])
	for i in 10:
		sp.step()
	var found := false
	for p in sp.state.proposals:
		if p["kind"] == "swarm":
			found = true
			eq(str(p["line"]), "species.bone_crawler", "for the creatures you have")
	check(found, "swarm offer")
	sp.free()


func test_genetics_saved() -> void:
	var sp = _sprout(12)
	sp.genetics.mutate("species.devourer", "mutation.predator_instinct")
	sp.creatures.spawn_creature("species.devourer", _stand(sp)[0])
	var inc: int = _place(sp, "organ.incubator")
	_burn(sp, inc, 150.0)
	for i in 10:
		sp.step()
	var back = Sprout.unpack(sp.state.pack())
	eq(back.state_hash(), sp.state.state_hash(), "same")
	eq(back.strains, sp.state.strains, "strains")
	eq(back.proposals.size(), 1, "offer kept")
	sp.free()
