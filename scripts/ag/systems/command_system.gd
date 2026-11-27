extends Node
## Nerve-impulse commands (GDD 9, TECH_SPEC AG-08): the player directs the will, not every creature.
## Each command costs impulses (+1 per affected creature with Nerve Insulation), has a cooldown,
## and works only within reach of the Heart or a working Nerve Node.

const Reg = preload("res://scripts/ag/core/registry.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

var s
var organs
var economy
var creatures


func setup(state, organ_system, economy_system, creature_system) -> void:
	s = state
	organs = organ_system
	economy = economy_system
	creatures = creature_system


static func cmd(id: String) -> Dictionary:
	return Defs.COMMANDS[id]


## Is this cell within the nervous system's reach?
func in_reach(c: Vector2i) -> bool:
	var hu: int = organs.heart_uid()
	if hu >= 0:
		for hc in organs.cells_of(hu):
			if Vector2(hc).distance_to(Vector2(c)) <= float(Defs.COMMAND_REACH["reach_heart"]):
				return true
	for uid in s.organs:
		if str(s.organs[uid]["def"]) == "organ.nerve_node" and economy.is_working(int(uid)):
			if Vector2(organs.cells_of(int(uid))[0]).distance_to(Vector2(c)) <= float(Defs.COMMAND_REACH["reach_node"]):
				return true
	return false


func _creatures_near(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for uid in creatures.team_units("abyss"):
		if creatures.pos_of(s.units[uid]).distance_to(center) <= radius:
			out.append(uid)
	return out


func impulse_cost(id: String, affected: Array) -> int:
	var c := int(cmd(id)["cost"])
	for uid in affected:
		c += int(s.units[uid].get("impulse_cost", 0))
	return c


## {"ok", "reason", "arg"?, "cost"}
func check(id: String, target) -> Dictionary:
	if float(s.cmd_cd.get(id, 0.0)) > 0.0:
		return {"ok": false, "reason": "Not ready yet: %s s.", "arg": str(ceili(float(s.cmd_cd[id]))), "cost": 0}
	var affected: Array = []
	var cell := Vector2i(-1, -1)
	match id:
		"command.focus":
			if not s.units.has(target) or str(s.units[target]["team"]) != "order":
				return {"ok": false, "reason": "Choose an invader.", "cost": 0}
			cell = creatures.cell_of(s.units[target])
			affected = _creatures_near(creatures.pos_of(s.units[target]), float(cmd(id)["radius"]))
			if affected.is_empty():
				return {"ok": false, "reason": "No creatures close enough.", "cost": 0}
		"command.protect":
			if not s.organs.has(target):
				return {"ok": false, "reason": "Choose an organ.", "cost": 0}
			cell = organs.cells_of(int(target))[0]
			affected = _creatures_near(Vector2(cell), float(cmd(id)["radius"]))
			if affected.is_empty():
				return {"ok": false, "reason": "No creatures close enough.", "cost": 0}
		"command.seal":
			cell = target
			var g = s.grid
			if not g.is_floor(cell) or g.organ_at(cell) >= 0 or g.is_sealed(cell) or g.is_entrance(cell):
				return {"ok": false, "reason": "Only an open passage can be sealed.", "cost": 0}
			for uid in s.units:
				if creatures.cell_of(s.units[uid]) == cell:
					return {"ok": false, "reason": "Someone is standing there.", "cost": 0}
		"command.regen":
			var hu: int = organs.heart_uid()
			if hu < 0:
				return {"ok": false, "reason": "There is no Heart to grow him from.", "cost": 0}
			cell = organs.cells_of(hu)[0]
			var m: String = economy.missing({"resource.biomass": cmd(id)["biomass"]})
			if m != "":
				return {"ok": false, "reason": "Not enough %s.", "arg": str(Reg.get_def(m)["name"]), "cost": 0}
		_:
			return {"ok": false, "reason": "Unknown command.", "cost": 0}
	if not in_reach(cell):
		return {"ok": false, "reason": "Out of the nerves' reach. Grow a Nerve Node closer.", "cost": 0}
	var c := impulse_cost(id, affected)
	if s.impulses + 0.0001 < float(c):
		return {"ok": false, "reason": "Not enough nerve impulses (%s needed).", "arg": str(c), "cost": c}
	return {"ok": true, "reason": "", "cost": c, "affected": affected, "cell": cell}


func issue(id: String, target) -> bool:
	var r := check(id, target)
	if not r["ok"]:
		return false
	s.impulses -= float(r["cost"])
	s.cmd_cd[id] = float(cmd(id)["cooldown"])
	s.count("commands")
	match id:
		"command.focus", "command.protect":
			for uid in r["affected"]:
				var u: Dictionary = s.units[uid]
				u["order"] = "focus" if id == "command.focus" else "protect"
				u["order_target"] = int(target)
				u["order_t"] = float(cmd(id)["time"])
				u["path"] = []
		"command.seal":
			var c: Vector2i = target
			s.grid.sealed[s.grid.idx(c)] = 1
			s.seals[s.grid.idx(c)] = float(cmd(id)["time"])
			s.grid_version += 1
		"command.regen":
			economy.pay({"resource.biomass": cmd(id)["biomass"]}, "Emergency regeneration")
			var keys: Array = s.organs.keys()
			keys.sort()
			for uid in keys:
				if economy.is_working(int(uid)) or str(s.organs[uid]["def"]) == "organ.heart":
					organs.heal(int(uid), float(s.organs[uid]["max_hp"]) * float(cmd(id)["heal"]))
	s.fx.emit(id.replace("command.", "cmd_"), target, float(r["cost"]))
	return true


func tick(dt: float) -> void:
	for k in s.cmd_cd.keys():
		s.cmd_cd[k] = float(s.cmd_cd[k]) - dt
		if float(s.cmd_cd[k]) <= 0.0:
			s.cmd_cd.erase(k)
	var keys: Array = s.seals.keys()
	keys.sort()
	for i in keys:
		s.seals[i] = float(s.seals[i]) - dt
		if float(s.seals[i]) <= 0.0:
			s.seals.erase(i)
			s.grid.sealed[int(i)] = 0
			s.grid_version += 1
			s.fx.emit("unsealed", Vector2i(int(i) % s.grid.w, int(i) / s.grid.w), 0.0)
