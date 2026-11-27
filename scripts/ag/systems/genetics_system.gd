extends Node
## Mutations, inheritance and the resulting stats (GDD 8, TECH_SPEC AG-06).
## A mutation is applied to a LINE: a species strain ("species.x") or an organ type ("organ.x").
## Living members get it at once; future broods inherit it by the rules below:
##   dominant  -> always passed on;
##   recessive -> passed with GENETICS.recessive_chance (rolled on the "breeding" RNG stream);
##   invalid   -> never passed (unknown id, wrong target, excluded pair, no free slot);
##   combos    -> two mutations together may add a defect or a rare trait.
## forecast() gives the exact probabilities the player sees in the Incubator.

const Reg = preload("res://scripts/ag/core/registry.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

var s
var organs
var economy


func setup(state, organ_system, economy_system) -> void:
	s = state
	organs = organ_system
	economy = economy_system


static func gen(key: String):
	return Defs.GENETICS[key]


# ------------------------------------------------------------------ lines

func line_mutations(line_id: String) -> Array:
	return s.strains.get(line_id, [])


func slots(line_id: String) -> int:
	match Reg.kind_of(line_id):
		"species":
			return int(gen("zero_slots")) if line_id == "species.zero" else int(gen("strain_slots"))
		"organ":
			return int(Reg.get_def(line_id).get("slots", 1))
	return 0


func cost_of(mutation_id: String, discount: float = 1.0) -> Dictionary:
	var out := {}
	var c: Dictionary = Reg.get_def(mutation_id).get("cost", {})
	for r in c:
		out[r] = ceilf(float(c[r]) * discount)
	return out


## Is `mutation_id` allowed next to `present` on a line of `kind`? Returns "" or a reason key.
static func compatibility(mutation_id: String, present: Array, kind: String, max_slots: int) -> String:
	var d := Reg.get_def(mutation_id)
	if d.is_empty() or Reg.kind_of(mutation_id) != "mutation":
		return "Unknown mutation."
	if not (d.get("targets", []) as Array).has(kind):
		return "This mutation cannot grow on organs." if kind == "organ" else "This mutation grows only on organs."
	if present.has(mutation_id):
		return "This line already has it."
	for m in present:
		var md := Reg.get_def(str(m))
		if (d.get("excludes", []) as Array).has(m) or (md.get("excludes", []) as Array).has(mutation_id):
			return "Incompatible with %s."
	for r in d.get("requires", []):
		if not present.has(r):
			return "Requires another mutation first."
	if present.size() >= max_slots:
		return "No free mutation slot."
	return ""


## {"ok", "reason", "arg"?}
func can_mutate(line_id: String, mutation_id: String, discount: float = 1.0, check_cost: bool = true) -> Dictionary:
	var kind := Reg.kind_of(line_id)
	if Reg.get_def(line_id).is_empty() or not ["species", "organ"].has(kind):
		return {"ok": false, "reason": "Unknown line."}
	var present := line_mutations(line_id)
	var why := compatibility(mutation_id, present, kind, slots(line_id))
	if why != "":
		var r := {"ok": false, "reason": why}
		if why == "Incompatible with %s.":
			for m in present:
				var md := Reg.get_def(str(m))
				if (Reg.get_def(mutation_id).get("excludes", []) as Array).has(m) or (md.get("excludes", []) as Array).has(mutation_id):
					r["arg"] = str(md.get("name", m))
		return r
	if check_cost:
		var m: String = economy.missing(cost_of(mutation_id, discount))
		if m != "":
			return {"ok": false, "reason": "Not enough %s.", "arg": str(Reg.get_def(m).get("name", m))}
	return {"ok": true, "reason": ""}


## Pays and grows the mutation on the whole line.
func mutate(line_id: String, mutation_id: String, source: String = "Mutations", discount: float = 1.0) -> bool:
	if not can_mutate(line_id, mutation_id, discount)["ok"]:
		return false
	economy.pay(cost_of(mutation_id, discount), source)
	if not s.strains.has(line_id):
		s.strains[line_id] = []
	(s.strains[line_id] as Array).append(mutation_id)
	if Reg.kind_of(line_id) == "species":
		for uid in _sorted(s.units.keys()):
			var u: Dictionary = s.units[uid]
			if str(u["def"]) == line_id:
				var mine: Array = u["mutations"]
				if compatibility(mutation_id, mine, "species", slots(line_id)) == "":
					mine.append(mutation_id)
					recompute_unit(u)
	else:
		for uid in _sorted(s.organs.keys()):
			if str(s.organs[uid]["def"]) == line_id:
				(s.organs[uid]["mutations"] as Array).append(mutation_id)
				recompute_organ(int(uid))
	s.count("mutations")
	s.fx.emit("mutation", line_id, 0.0)
	return true


static func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


# ------------------------------------------------------------------ inheritance

## Rolls one offspring of a species line. Never returns an invalid set.
func inherit(species_id: String) -> Dictionary:
	var r: RandomNumberGenerator = s.rng.get_rng("breeding")
	var kept: Array = []
	for m in line_mutations(species_id):
		var d := Reg.get_def(str(m))
		if d.is_empty():
			s.count("invalid_dropped")
			continue
		var passes := str(d.get("inherit", "dominant")) == "dominant" or r.randf() < float(gen("recessive_chance"))
		if not passes:
			continue
		if compatibility(str(m), kept, "species", slots(species_id)) != "":
			s.count("invalid_dropped")
			continue
		kept.append(str(m))
	var defects: Array = []
	var traits: Array = []
	for combo in gen("combos"):
		var all_there := true
		for m in combo["all"]:
			if not kept.has(m):
				all_there = false
		if not all_there:
			continue
		if float(combo["chance"]) >= 1.0 or r.randf() < float(combo["chance"]):
			var res := str(combo["result"])
			if Reg.kind_of(res) == "defect":
				defects.append(res)
			else:
				traits.append(res)
			var key := "+".join(combo["all"])
			if not s.recipes.has(key):
				s.recipes[key] = res
				s.fx.emit("recipe_found", res, 0.0)
	return {"mutations": kept, "defects": defects, "traits": traits}


## Exact chances for the next brood: {"mutations": [[id, p]], "results": [[id, p]]}.
func forecast(species_id: String) -> Dictionary:
	var chance := {}
	var out_m: Array = []
	for m in line_mutations(species_id):
		var d := Reg.get_def(str(m))
		if d.is_empty():
			continue
		var p := 1.0 if str(d.get("inherit", "dominant")) == "dominant" else float(gen("recessive_chance"))
		chance[str(m)] = p
		out_m.append([str(m), p])
	var out_r: Array = []
	for combo in gen("combos"):
		var p := float(combo["chance"])
		for m in combo["all"]:
			p *= float(chance.get(m, 0.0))
		if p > 0.0:
			out_r.append([str(combo["result"]), p])
	return {"mutations": out_m, "results": out_r}


## Breeding cost of a species after its line's mutations (Spore Sac makes broods dearer).
func breed_cost(species_id: String) -> Dictionary:
	var base: Dictionary = Reg.get_def(species_id).get("breed", {}).get("cost", {})
	var mult := 1.0
	for m in line_mutations(species_id):
		mult *= float(Reg.get_def(str(m)).get("effect", {}).get("breed_cost_mult", 1.0))
	var out := {}
	for r in base:
		out[r] = ceilf(float(base[r]) * mult)
	return out


# ------------------------------------------------------------------ stats

## Recomputes a creature's stats from its definition, mutations, defects and traits. Keeps the health ratio.
func recompute_unit(u: Dictionary) -> void:
	var d := Reg.get_def(str(u["def"]))
	var st: Dictionary = d.get("stats", {})
	var hp := float(st.get("hp", 50))
	var atk := float(st.get("atk", 5))
	var armor := float(st.get("armor", 0))
	var speed := float(st.get("speed", 1.0))
	var lvl_hp := float(u.get("bonus_hp", 0.0))
	var lvl_atk := float(u.get("bonus_atk", 0.0))
	var resist := {}
	var weak := {}
	var fx := {"heal_mult": 1.0, "thorns": 0.0, "regen": 0.0, "upkeep_extra": 0.0, "spores": false,
		"predator": 0.0, "ignores_alarm": false, "impulse_cost": 0, "insulated": false,
		"sees_hidden": bool(d.get("sees_hidden", false))}
	var effects: Array = []
	for m in u.get("mutations", []):
		effects.append(Reg.get_def(str(m)).get("effect", {}))
	for x in u.get("defects", []):
		effects.append(Reg.get_def(str(x)).get("effect", {}))
	for t in u.get("traits", []):
		effects.append(Reg.get_def(str(t)).get("effect", {}))
	var hp_mult := 1.0
	var atk_mult := 1.0
	var speed_mult := 1.0
	for e in effects:
		armor += float(e.get("armor", 0.0))
		hp_mult *= float(e.get("hp_mult", 1.0))
		atk_mult *= float(e.get("atk_mult", 1.0))
		speed_mult *= float(e.get("speed_mult", 1.0))
		for k in e.get("resist", {}):
			resist[k] = float(resist.get(k, 0.0)) + float(e["resist"][k])
		for k in e.get("weak", {}):
			weak[k] = float(weak.get(k, 0.0)) + float(e["weak"][k])
		fx["heal_mult"] = float(fx["heal_mult"]) * float(e.get("heal_mult", 1.0))
		fx["thorns"] = float(fx["thorns"]) + float(e.get("thorns", 0.0))
		fx["regen"] = float(fx["regen"]) + float(e.get("regen", 0.0))
		fx["upkeep_extra"] = float(fx["upkeep_extra"]) + float(e.get("upkeep", 0.0))
		fx["predator"] = float(fx["predator"]) + float(e.get("predator", 0.0))
		fx["impulse_cost"] = int(fx["impulse_cost"]) + int(e.get("impulse_cost", 0))
		for flag in ["spores", "ignores_alarm", "insulated", "sees_hidden"]:
			if bool(e.get(flag, false)):
				fx[flag] = true
	var ratio := float(u["hp"]) / maxf(1.0, float(u["max_hp"])) if u.has("max_hp") else 1.0
	u["max_hp"] = (hp + lvl_hp) * hp_mult
	u["hp"] = clampf(ratio, 0.0, 1.0) * float(u["max_hp"])
	u["atk"] = (atk + lvl_atk) * atk_mult
	u["armor"] = maxf(0.0, armor)
	u["speed"] = speed * speed_mult
	u["resist"] = resist
	u["weak"] = weak
	for k in fx:
		u[k] = fx[k]


func recompute_organ(uid: int) -> void:
	var o: Dictionary = s.organs[uid]
	var d := Reg.get_def(str(o["def"]))
	var resist := {}
	var hp_mult := 1.0
	var heal_mult := 1.0
	var regen := 0.0
	var upkeep := 0.0
	var insulated := false
	for m in o.get("mutations", []):
		var e: Dictionary = Reg.get_def(str(m)).get("organ_effect", {})
		hp_mult *= float(e.get("hp_mult", 1.0))
		heal_mult *= float(e.get("heal_mult", 1.0))
		regen += float(e.get("regen", 0.0))
		upkeep += float(e.get("upkeep", 0.0))
		insulated = insulated or bool(e.get("insulated", false))
		for k in e.get("resist", {}):
			resist[k] = float(resist.get(k, 0.0)) + float(e["resist"][k])
	var ratio := float(o["hp"]) / maxf(1.0, float(o["max_hp"]))
	o["max_hp"] = float(d.get("hp", 100)) * hp_mult
	o["hp"] = ratio * float(o["max_hp"])
	o["resist"] = resist
	o["heal_mult"] = heal_mult
	o["regen"] = regen
	o["upkeep_extra"] = upkeep
	o["insulated"] = insulated


## A newly grown organ takes its line's mutations.
func on_organ_placed(uid: int) -> void:
	var line := str(s.organs[uid]["def"])
	s.organs[uid]["mutations"] = line_mutations(line).duplicate()
	recompute_organ(uid)


## A newly born creature inherits from its line (Zero takes his whole line: he is not bred).
func on_creature_born(u: Dictionary) -> void:
	var line := str(u["def"])
	if line == "species.zero":
		u["mutations"] = line_mutations(line).duplicate()
		u["defects"] = []
	else:
		var child := inherit(line)
		u["mutations"] = child["mutations"]
		u["defects"] = child["defects"]
		for t in child["traits"]:
			if not (u["traits"] as Array).has(t):
				(u["traits"] as Array).append(t)
	recompute_unit(u)
