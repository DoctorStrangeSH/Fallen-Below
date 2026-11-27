extends RefCounted
## Damage formulas (TECH_SPEC 3 CombatRules). Pure functions, no state: same inputs, same result.
## Stage 05 version: armour, first strike, execute, organ resistances are applied by organ_system.
## Stage 07 extends it (statuses, mutations, kinds) and the combat log reads `reason`.

const Defs = preload("res://scripts/ag/data/defs.gd")


static func has_trait(u: Dictionary, trait_id: String) -> bool:
	return (u.get("traits", []) as Array).has(trait_id)


## Unit hits unit. Returns {"amount": float, "reason": String (English Loc key, may hold %s)}.
static func unit_vs_unit(att: Dictionary, def: Dictionary) -> Dictionary:
	var base := float(att["atk"])
	var reasons: Array = []
	if bool(att.get("first_strike_ready", false)):
		base *= 2.0
		reasons.append("first strike")
	var ratio := float(def["hp"]) / maxf(1.0, float(def["max_hp"]))
	if has_trait(att, "trait.execute") and ratio < float(Defs.AI["execute_below"]):
		base *= 1.0 + float(Defs.AI["execute_bonus"])
		reasons.append("execute")
	var amount := maxf(1.0, base - float(def.get("armor", 0.0)))
	return {"amount": amount, "reason": ", ".join(reasons)}


## Unit hits an organ: raw damage and its kind; organ_system.damage applies resist/weak.
static func unit_vs_organ(att: Dictionary) -> Dictionary:
	var base := float(att["atk"])
	if bool(att.get("first_strike_ready", false)):
		base *= 2.0
	return {"amount": base, "kind": str(att.get("damage", "physical"))}
