extends Node
## Adaptive evolution (GDD 8): the organism remembers what hurt it and proposes an answer.
## Threat log: every hit on an organ or a creature is recorded with its kind, attacker and victim line.
## When one kind of harm passes its threshold within the window, a proposal appears with
## the reason (who did how much to whom), the mutation, its cost (discounted) and its drawback.
## The player accepts or rejects; nothing changes by itself. Rejected or expired kinds rest a while.

const Reg = preload("res://scripts/ag/core/registry.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

var s
var genetics
var creatures


func setup(state, genetics_system, creature_system) -> void:
	s = state
	genetics = genetics_system
	creatures = creature_system


static func gen(key: String):
	return Defs.GENETICS[key]


## Called by organ_system and creature_system for every hit on the Abyss.
func record(kind: String, amount: float, attacker_def: String, victim_line: String) -> void:
	if amount <= 0.0:
		return
	s.threats.append([s.tick, kind, amount, attacker_def, victim_line])


func _window_ticks() -> int:
	return int(float(gen("threat_window")) * 10.0)


func tick(dt: float) -> void:
	# prune old threats
	var oldest: int = s.tick - _window_ticks()
	while not s.threats.is_empty() and int(s.threats[0][0]) < oldest:
		s.threats.pop_front()
	for k in s.adapt_cd.keys():
		s.adapt_cd[k] = float(s.adapt_cd[k]) - dt
		if float(s.adapt_cd[k]) <= 0.0:
			s.adapt_cd.erase(k)
	for p in s.proposals.duplicate():
		p["left"] = float(p["left"]) - dt
		if float(p["left"]) <= 0.0:
			s.proposals.erase(p)
			s.adapt_cd[p["kind"]] = float(gen("reject_cooldown"))
	if s.tick % 10 == 0:
		_consider()


## Sum of each kind of harm in the window: {kind: {"total", "by_line": {}, "by_attacker": {}}}
func summary() -> Dictionary:
	var out := {}
	for t in s.threats:
		var kind := str(t[1])
		if not out.has(kind):
			out[kind] = {"total": 0.0, "by_line": {}, "by_attacker": {}}
		var e: Dictionary = out[kind]
		e["total"] = float(e["total"]) + float(t[2])
		e["by_line"][t[4]] = float(e["by_line"].get(t[4], 0.0)) + float(t[2])
		e["by_attacker"][t[3]] = float(e["by_attacker"].get(t[3], 0.0)) + float(t[2])
	return out


static func _top(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort_custom(func(a, b): return float(d[a]) > float(d[b]) or (float(d[a]) == float(d[b]) and str(a) < str(b)))
	return keys


func _has_proposal(kind: String) -> bool:
	for p in s.proposals:
		if p["kind"] == kind:
			return true
	return false


func _consider() -> void:
	var sm := summary()
	var thresholds: Dictionary = gen("threat_threshold")
	# swarm: many invaders at once (counted now, not summed)
	var invaders: int = creatures.team_units("order").size()
	if invaders >= int(thresholds["swarm"]) and not _has_proposal("swarm") and not s.adapt_cd.has("swarm"):
		var lines := {}
		for uid in creatures.team_units("abyss"):
			var def_id := str(s.units[uid]["def"])
			lines[def_id] = float(lines.get(def_id, 0.0)) + 1.0
		_propose("swarm", float(invaders), "", _top(lines))
	var kinds: Array = sm.keys()
	kinds.sort()
	for kind in kinds:
		if not thresholds.has(kind) or kind == "swarm":
			continue
		var e: Dictionary = sm[kind]
		if float(e["total"]) < float(thresholds[kind]) or _has_proposal(kind) or s.adapt_cd.has(kind):
			continue
		var att: Array = _top(e["by_attacker"])
		_propose(kind, float(e["total"]), str(att[0]) if not att.is_empty() else "", _top(e["by_line"]))


## Picks the most harmed line that can take one of the answers for this kind.
func _propose(kind: String, amount: float, attacker: String, lines: Array) -> void:
	for line in lines:
		for m in gen("threat_answers").get(kind, []):
			if genetics.can_mutate(str(line), str(m), float(gen("adapt_discount")), false)["ok"]:
				s.next_proposal += 1
				s.proposals.append({
					"id": s.next_proposal, "kind": kind, "line": str(line), "mutation": str(m),
					"amount": amount, "attacker": attacker, "left": float(gen("proposal_time")),
					"cost": genetics.cost_of(str(m), float(gen("adapt_discount"))),
				})
				s.count("proposals")
				s.fx.emit("adaptation_offered", str(m), amount)
				return


func find(pid: int) -> Dictionary:
	for p in s.proposals:
		if int(p["id"]) == pid:
			return p
	return {}


func accept(pid: int) -> bool:
	var p := find(pid)
	if p.is_empty():
		return false
	if not genetics.mutate(str(p["line"]), str(p["mutation"]), "Adaptation", float(gen("adapt_discount"))):
		return false
	s.proposals.erase(p)
	s.adapt_cd[p["kind"]] = float(gen("reject_cooldown"))
	s.count("adaptations")
	return true


func reject(pid: int) -> void:
	var p := find(pid)
	if p.is_empty():
		return
	s.proposals.erase(p)
	s.adapt_cd[p["kind"]] = float(gen("reject_cooldown"))


## Player-facing reason: English Loc key and its arguments.
static func reason(p: Dictionary) -> Array:
	if str(p["kind"]) == "swarm":
		return ["%d invaders are inside the Abyss at once.", [int(p["amount"])]]
	var att := str(Reg.get_def(str(p["attacker"])).get("name", "Invaders"))
	var kind_name: String = str(p["kind"])
	return ["%s dealt %d %s damage to the Abyss in the last minute; your %s suffered most.",
		[att, int(p["amount"]), kind_name, str(Reg.get_def(str(p["line"])).get("name", p["line"]))]]
