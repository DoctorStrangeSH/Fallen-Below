extends Node
## Creatures of the Abyss, Zero, and (until stage 08) the simple behaviour of invaders (GDD 6, TECH_SPEC AG-05).
## Behaviour is a small state machine per unit:
##   idle -> engage (attack / move to target) -> retreat -> recover -> idle,
##   protect (go to an organ under attack), return (go back home), heal (support).
## Every decision is deterministic (sorted ids, no randomness), so a seed replays the same fight.

const Reg = preload("res://scripts/ag/core/registry.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")
const Rules = preload("res://scripts/ag/systems/combat_rules.gd")
const Pathing = preload("res://scripts/ag/systems/pathing.gd")

const ABYSS := "abyss"
const ORDER := "order"

signal unit_died(uid: int, def_id: String, team: String)

var s
var organs
var economy
var paths := Pathing.new()
var genetics = null   # GeneticsSystem
var evolution = null  # EvolutionSystem
var minds = null      # MindSystem


func setup(state, organ_system, economy_system) -> void:
	s = state
	organs = organ_system
	economy = economy_system
	paths.setup(state)


static func ai(key: String) -> float:
	return float(Defs.AI[key])


# ------------------------------------------------------------------ helpers

static func pos_of(u: Dictionary) -> Vector2:
	return Vector2(float(u["pos"][0]), float(u["pos"][1]))


static func cell_of(u: Dictionary) -> Vector2i:
	var p := pos_of(u)
	return Vector2i(roundi(p.x), roundi(p.y))


static func home_of(u: Dictionary) -> Vector2i:
	return Vector2i(int(u["home"][0]), int(u["home"][1]))


func _uids() -> Array:
	var out: Array = s.units.keys()
	out.sort()
	return out


func team_units(team: String) -> Array:
	var out: Array = []
	for uid in _uids():
		if str(s.units[uid]["team"]) == team:
			out.append(uid)
	return out


func zero_uid() -> int:
	for uid in _uids():
		if str(s.units[uid]["def"]) == "species.zero":
			return int(uid)
	return -1


## Free floor next to an organ (or the organ cell's neighbours), nearest to its first cell.
func spawn_cell_near(uid: int) -> Vector2i:
	var cells: Array = organs.cells_of(uid)
	var stand: Array = paths.stand_cells(cells)
	if stand.is_empty():
		return Vector2i(-1, -1)
	stand.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return stand[0]


func _new_unit(def_id: String, team: String, cell: Vector2i, d: Dictionary) -> int:
	var st: Dictionary = d.get("stats", {})
	var uid: int = s.next_uid
	s.next_uid += 1
	var hp := float(st.get("hp", 50))
	s.units[uid] = {
		"uid": uid, "def": def_id, "team": team, "pos": [float(cell.x), float(cell.y)], "home": [cell.x, cell.y],
		"hp": hp, "max_hp": hp, "atk": float(st.get("atk", 5)), "armor": float(st.get("armor", 0)),
		"speed": float(st.get("speed", 1.0)), "sight": float(st.get("sight", 5.0)),
		"traits": (d.get("traits", []) as Array).duplicate(), "role": str(d.get("role", "invader")),
		"damage": str(d.get("damage", "physical")),
		"state": "idle", "target": -1, "target_kind": "", "path": [], "path_t": 0.0, "cd": 0.0,
		"hidden": Rules.has_trait({"traits": d.get("traits", [])}, "trait.stealth"), "hide_t": 0.0,
		"first_strike_ready": Rules.has_trait({"traits": d.get("traits", [])}, "trait.first_strike"),
		"infect_t": 0.0, "still_t": 0.0, "last_cell": [cell.x, cell.y], "resets": 0,
		"aggro": -1, "aggro_t": 0.0, "kills": 0, "xp": 0, "level": 1, "storm_cd": 0.0,
		"sees_hidden": bool(d.get("sees_hidden", false)),
		"mutations": [], "defects": [], "bonus_hp": 0.0, "bonus_atk": 0.0, "resist": {}, "weak": {},
		"heal_mult": 1.0, "thorns": 0.0, "regen": 0.0, "upkeep_extra": 0.0, "spores": false, "predator": 0.0,
		"ignores_alarm": false, "impulse_cost": 0, "insulated": false, "slow_t": 0.0,
		"order": "", "order_target": -1, "order_t": 0.0, "last_hit": {}, "infect_by": "",
	}
	return uid


func spawn_creature(species_id: String, cell: Vector2i) -> int:
	var d := Reg.get_def(species_id)
	if d.is_empty() or not s.grid.walkable(cell):
		return -1
	var uid := _new_unit(species_id, ABYSS, cell, d)
	if genetics != null:
		genetics.on_creature_born(s.units[uid])
	s.count("creatures_born")
	_bus("creature_born", [uid, species_id])
	s.fx.emit("creature_born", uid, 0.0)
	return uid


func spawn_enemy(enemy_id: String, cell: Vector2i) -> int:
	var d := Reg.get_def(enemy_id)
	if d.is_empty() or not s.grid.walkable(cell):
		return -1
	var uid := _new_unit(enemy_id, ORDER, cell, d)
	s.count("invaders")
	s.fx.emit("invader_arrives", uid, 0.0)
	return uid


# ------------------------------------------------------------------ breeding

## {"ok", "reason", "arg"?}
func can_breed(incubator_uid: int, species_id: String) -> Dictionary:
	if not s.organs.has(incubator_uid) or str(s.organs[incubator_uid]["def"]) != "organ.incubator":
		return {"ok": false, "reason": "Only an Incubator can grow creatures."}
	var d := Reg.get_def(species_id)
	if d.is_empty() or not d.has("breed"):
		return {"ok": false, "reason": "This creature cannot be bred."}
	var cost: Dictionary = breed_cost(species_id)
	var m: String = economy.missing(cost)
	if m != "":
		return {"ok": false, "reason": "Not enough %s.", "arg": str(Reg.get_def(m).get("name", m))}
	return {"ok": true, "reason": ""}


## Pays now; the Incubator grows the brood while it works.
func queue_breed(incubator_uid: int, species_id: String) -> bool:
	if not can_breed(incubator_uid, species_id)["ok"]:
		return false
	economy.pay(breed_cost(species_id), "Breeding")
	if not s.breeding.has(incubator_uid):
		s.breeding[incubator_uid] = {"queue": [], "progress": 0.0}
	(s.breeding[incubator_uid]["queue"] as Array).append(species_id)
	return true


func breed_cost(species_id: String) -> Dictionary:
	if genetics != null:
		return genetics.breed_cost(species_id)
	return Reg.get_def(species_id).get("breed", {}).get("cost", {})


func breed_progress(incubator_uid: int) -> float:
	var b: Dictionary = s.breeding.get(incubator_uid, {})
	if b.is_empty() or (b["queue"] as Array).is_empty():
		return 0.0
	var t := float(Reg.get_def(str(b["queue"][0]))["breed"]["time"])
	return clampf(float(b["progress"]) / t, 0.0, 1.0)


func _tick_breeding(dt: float) -> void:
	var keys: Array = s.breeding.keys()
	keys.sort()
	for inc in keys:
		if not s.organs.has(inc):
			s.breeding.erase(inc)   # the Incubator died: the brood dies with it
			continue
		var b: Dictionary = s.breeding[inc]
		var q: Array = b["queue"]
		if q.is_empty() or not economy.is_working(int(inc)):
			continue
		var t := float(Reg.get_def(str(q[0]))["breed"]["time"])
		b["progress"] = minf(t, float(b["progress"]) + dt)
		if float(b["progress"]) >= t:
			var c := spawn_cell_near(int(inc))
			if c.x >= 0 and spawn_creature(str(q[0]), c) >= 0:
				q.remove_at(0)
				b["progress"] = 0.0


# ------------------------------------------------------------------ Zero

func can_embody_zero() -> Dictionary:
	if s.zero_dead:
		return {"ok": false, "reason": "Zero has fallen in this sprout. He will return in the next one."}
	if zero_uid() >= 0:
		return {"ok": false, "reason": "Zero is already here."}
	if organs.heart_uid() < 0:
		return {"ok": false, "reason": "There is no Heart to grow him from."}
	var m: String = economy.missing(Defs.ZERO["species.zero"]["embody_cost"])
	if m != "":
		return {"ok": false, "reason": "Not enough %s.", "arg": str(Reg.get_def(m).get("name", m))}
	if spawn_cell_near(organs.heart_uid()).x < 0:
		return {"ok": false, "reason": "No room around the Heart."}
	return {"ok": true, "reason": ""}


func embody_zero() -> int:
	if not can_embody_zero()["ok"]:
		return -1
	economy.pay(Defs.ZERO["species.zero"]["embody_cost"], "Zero")
	var uid := spawn_creature("species.zero", spawn_cell_near(organs.heart_uid()))
	s.fx.emit("zero_embodied", uid, 0.0)
	return uid


func zero_storm() -> bool:
	var z := zero_uid()
	if z < 0:
		return false
	var u: Dictionary = s.units[z]
	if float(u["storm_cd"]) > 0.0:
		return false
	var st: Dictionary = Defs.ZERO["species.zero"]["storm"]
	var hit := false
	for e in team_units(ORDER):
		if s.units.has(e) and pos_of(s.units[e]).distance_to(pos_of(u)) <= float(st["radius"]):
			_hurt_unit(z, e, float(u["atk"]) * float(st["mult"]), "Bone Storm", "physical")
			hit = true
	u["storm_cd"] = float(st["cooldown"])
	s.fx.emit("bone_storm", z, 0.0)
	return hit


## A mind given to Zero: experience and a little healing (GDD 7).
func feed_zero(z: Dictionary, xp: int, heal: float) -> void:
	_gain_xp(z, xp)
	z["hp"] = minf(float(z["max_hp"]), float(z["hp"]) + float(z["max_hp"]) * heal)


func _gain_xp(u: Dictionary, amount: int) -> void:
	if str(u["def"]) != "species.zero":
		return
	var z: Dictionary = Defs.ZERO["species.zero"]
	var levels: Array = z["xp_levels"]
	u["xp"] = int(u["xp"]) + amount
	while int(u["level"]) - 1 < levels.size() and int(u["xp"]) >= int(levels[int(u["level"]) - 1]):
		u["level"] = int(u["level"]) + 1
		var lu: Dictionary = z["level_up"]
		u["bonus_hp"] = float(u["bonus_hp"]) + float(z["stats"]["hp"]) * float(lu["hp"])
		u["bonus_atk"] = float(u["bonus_atk"]) + float(lu["atk"])
		_restat(u)
		u["hp"] = minf(float(u["max_hp"]), float(u["hp"]) + float(u["max_hp"]) * float(lu["heal"]))
		s.fx.emit("zero_level", int(u["uid"]), float(u["level"]))


## Recompute stats after a permanent change (level, gorge, mutation).
func _restat(u: Dictionary) -> void:
	if genetics != null:
		genetics.recompute_unit(u)
	else:
		var st: Dictionary = Reg.get_def(str(u["def"]))["stats"]
		var ratio := float(u["hp"]) / maxf(1.0, float(u["max_hp"]))
		u["max_hp"] = float(st["hp"]) + float(u["bonus_hp"])
		u["hp"] = ratio * float(u["max_hp"])
		u["atk"] = float(st["atk"]) + float(u["bonus_atk"])


# ------------------------------------------------------------------ upkeep (read by economy)

func upkeep_rate() -> float:
	var total := 0.0
	for uid in team_units(ABYSS):
		total += float(Reg.get_def(str(s.units[uid]["def"]))["stats"].get("upkeep", 0.0)) + float(s.units[uid].get("upkeep_extra", 0.0))
	return total


# ------------------------------------------------------------------ tick

func tick(dt: float) -> void:
	paths.ensure()
	for k in s.alerts.keys():
		s.alerts[k] = float(s.alerts[k]) - dt
		if float(s.alerts[k]) <= 0.0 or not s.organs.has(k):
			s.alerts.erase(k)
	_tick_breeding(dt)
	for uid in _uids():
		if not s.units.has(uid):
			continue
		var u: Dictionary = s.units[uid]
		_timers(u, dt)
		if float(u["hp"]) <= 0.0:
			_die(uid, -1)
			continue
		if str(u["team"]) == ABYSS:
			_think_creature(u, dt)
		else:
			_think_invader(u)
		_act(u, dt)
		_watch_stuck(u, dt)


func _timers(u: Dictionary, dt: float) -> void:
	u["cd"] = maxf(0.0, float(u["cd"]) - dt)
	u["storm_cd"] = maxf(0.0, float(u["storm_cd"]) - dt)
	u["aggro_t"] = maxf(0.0, float(u["aggro_t"]) - dt)
	if float(u["infect_t"]) > 0.0:
		u["infect_t"] = maxf(0.0, float(u["infect_t"]) - dt)
		u["hp"] = float(u["hp"]) - ai("infect_dps") * dt
		u["last_hit"] = {"by": str(u.get("infect_by", "")), "reason": "infection", "kind": "poison"}
	if str(u["team"]) == ABYSS and s.starving:
		u["hp"] = float(u["hp"]) - ai("starve_dps") * s.starve_frac * dt
		u["last_hit"] = {"by": "", "reason": "starvation", "kind": ""}
	if float(u.get("order_t", 0.0)) > 0.0:
		u["order_t"] = maxf(0.0, float(u["order_t"]) - dt)
		if float(u["order_t"]) == 0.0:
			u["order"] = ""
	if float(u.get("regen", 0.0)) > 0.0 and float(u["hp"]) > 0.0:
		_heal_unit(u, float(u["regen"]) * float(u["max_hp"]) * dt)
	u["slow_t"] = maxf(0.0, float(u.get("slow_t", 0.0)) - dt)
	if Rules.has_trait(u, "trait.stealth") and not bool(u["hidden"]):
		u["hide_t"] = float(u["hide_t"]) + dt
		if float(u["hide_t"]) >= ai("rehide_time"):
			u["hidden"] = true
			u["first_strike_ready"] = Rules.has_trait(u, "trait.first_strike")


func _heal_unit(u: Dictionary, amount: float) -> void:
	u["hp"] = minf(float(u["max_hp"]), float(u["hp"]) + amount * float(u.get("heal_mult", 1.0)))


# ------------------------------------------------------------------ thinking: creatures

func _visible_enemies(u: Dictionary, center: Vector2, radius: float) -> Array:
	var out: Array = []
	for e in team_units(ORDER if str(u["team"]) == ABYSS else ABYSS):
		var eu: Dictionary = s.units[e]
		if bool(eu.get("hidden", false)) and not bool(u.get("sees_hidden", false)):
			continue
		if pos_of(eu).distance_to(center) <= radius:
			out.append(e)
	return out


func _set_target(u: Dictionary, target: int, kind: String, state: String) -> void:
	if int(u["target"]) != target or str(u["target_kind"]) != kind:
		u["path"] = []
		u["resets"] = 0
	u["target"] = target
	u["target_kind"] = kind
	u["state"] = state


func _think_creature(u: Dictionary, dt: float) -> void:
	var role := str(u["role"])
	var me := pos_of(u)
	var ratio := float(u["hp"]) / maxf(1.0, float(u["max_hp"]))
	var st := str(u["state"])
	# retreat when badly hurt (defenders hold their post)
	if role != "defender" and ratio < ai("retreat_hp") and st != "retreat" and st != "recover":
		_set_target(u, -1, "", "retreat")
		st = "retreat"
	if st == "retreat":
		if cell_of(u) == home_of(u):
			u["state"] = "recover"
		return
	# a nerve command overrides the creature's own judgement while it lasts
	if float(u.get("order_t", 0.0)) > 0.0:
		var ot := int(u["order_target"])
		if str(u["order"]) == "focus" and s.units.has(ot):
			_set_target(u, ot, "unit", "engage")
			return
		if str(u["order"]) == "protect" and s.organs.has(ot):
			_set_target(u, ot, "guard", "protect")
			return
		u["order_t"] = 0.0
		u["order"] = ""
	if st == "recover":
		_heal_unit(u, float(u["max_hp"]) * ai("recover_rate") * dt)
		var attacker := int(u["aggro"])
		if float(u["aggro_t"]) > 0.0 and s.units.has(attacker) and pos_of(s.units[attacker]).distance_to(me) <= ai("attack_range"):
			_set_target(u, attacker, "unit", "engage")   # cornered: fight back
		elif ratio >= ai("recover_hp"):
			u["state"] = "idle"
		return
	if role == "support":
		var ally := _most_hurt_ally(u)
		if ally >= 0:
			_set_target(u, ally, "ally", "heal")
			return
	var center := me
	var radius := float(u["sight"])
	if role == "defender":
		center = Vector2(home_of(u))
		radius = ai("defender_leash")
	# hysteresis: a target seen at `radius` is only lost beyond 1.5 x radius (no flapping at the edge)
	var cur := int(u["target"])
	if str(u["state"]) == "engage" and str(u["target_kind"]) == "unit" and s.units.has(cur) \
			and not bool(s.units[cur].get("hidden", false)) and pos_of(s.units[cur]).distance_to(center) <= radius * 1.5 \
			and _within_leash(u, s.units[cur], 1.5):
		return
	var enemies: Array = _visible_enemies(u, center, radius)
	enemies = enemies.filter(func(e): return _within_leash(u, s.units[e], 1.0))
	var attacker := int(u["aggro"])
	if float(u["aggro_t"]) > 0.0 and s.units.has(attacker) and not bool(s.units[attacker].get("hidden", false)):
		_set_target(u, attacker, "unit", "engage")
		return
	if not enemies.is_empty():
		var best := -1
		var best_key := INF
		for e in enemies:
			var eu: Dictionary = s.units[e]
			var key := pos_of(eu).distance_to(me)
			if role == "hunter":
				key = float(eu["hp"]) / maxf(1.0, float(eu["max_hp"])) * 100.0 + key
			if key < best_key:
				best_key = key
				best = e
		# keep the current target if it is still a candidate (no target flapping)
		if int(u["target"]) in enemies and str(u["target_kind"]) == "unit":
			best = int(u["target"])
		_set_target(u, best, "unit", "engage")
		return
	# no enemy seen: answer an organ under attack
	if role != "ambusher" and role != "support" and not bool(u.get("ignores_alarm", false)):
		var alert := _nearest_alert(me)
		if alert >= 0:
			_set_target(u, alert, "guard", "protect")
			return
	if cell_of(u) != home_of(u) and me.distance_to(Vector2(home_of(u))) > 0.5:
		_set_target(u, -1, "", "return")
	else:
		_set_target(u, -1, "", "idle")


## Zero keeps close to the Heart (Defs.ZERO leash); other creatures have no leash here.
func _within_leash(u: Dictionary, target: Dictionary, mult: float) -> bool:
	if str(u["role"]) != "avatar":
		return true
	var hu: int = organs.heart_uid()
	if hu < 0:
		return true
	var hc := Vector2(organs.cells_of(hu)[0])
	return pos_of(target).distance_to(hc) <= float(Defs.ZERO["species.zero"]["leash"]) * mult


func _most_hurt_ally(u: Dictionary) -> int:
	var best := -1
	var best_ratio := 0.9
	for a in team_units(ABYSS):
		if a == int(u["uid"]):
			continue
		var au: Dictionary = s.units[a]
		var r := float(au["hp"]) / maxf(1.0, float(au["max_hp"]))
		if r < best_ratio and pos_of(au).distance_to(pos_of(u)) <= float(u["sight"]):
			best_ratio = r
			best = a
	return best


func _nearest_alert(from: Vector2) -> int:
	var best := -1
	var bd := INF
	var keys: Array = s.alerts.keys()
	keys.sort()
	for o in keys:
		if not s.organs.has(o):
			continue
		var d := Vector2(organs.cells_of(o)[0]).distance_to(from)
		if d <= ai("alert_radius") and d < bd:
			bd = d
			best = o
	return best


# ------------------------------------------------------------------ thinking: invaders (stage 05 minimum)

func _think_invader(u: Dictionary) -> void:
	var me := pos_of(u)
	var attacker := int(u["aggro"])
	if float(u["aggro_t"]) > 0.0 and s.units.has(attacker) and not bool(s.units[attacker].get("hidden", false)) \
			and pos_of(s.units[attacker]).distance_to(me) <= 2.0:
		_set_target(u, attacker, "unit", "engage")
		return
	# a visible creature in the way
	for e in _visible_enemies(u, me, ai("attack_range")):
		_set_target(u, e, "unit", "engage")
		return
	var keep := int(u["target"])
	if str(u["target_kind"]) == "organ" and s.organs.has(keep):
		u["state"] = "engage"
		return
	var goal := _invader_goal(u)
	if goal >= 0:
		_set_target(u, goal, "organ", "engage")
	else:
		_set_target(u, -1, "", "idle")


func _invader_goal(u: Dictionary) -> int:
	var d := Reg.get_def(str(u["def"]))
	if str(d.get("goal", "organ")) == "heart":
		return organs.heart_uid()
	var me := cell_of(u)
	var best := -1
	var bd := 1 << 30
	var keys: Array = s.organs.keys()
	keys.sort()
	for o in keys:
		var c: Vector2i = organs.cells_of(o)[0]
		var dd: int = absi(c.x - me.x) + absi(c.y - me.y)
		if dd < bd:
			bd = dd
			best = o
	return best


# ------------------------------------------------------------------ acting

func _act(u: Dictionary, dt: float) -> void:
	var st := str(u["state"])
	var me := pos_of(u)
	match st:
		"retreat":
			if not _move_to(u, home_of(u), dt):
				_adopt_home(u)
				u["state"] = "recover"   # cannot get home: rest where it stands
		"return":
			if not _move_to(u, home_of(u), dt):
				_adopt_home(u)
				u["state"] = "idle"
		"heal":
			var a := int(u["target"])
			if not s.units.has(a):
				u["state"] = "idle"
				return
			if pos_of(s.units[a]).distance_to(me) <= ai("heal_range"):
				_heal_unit(s.units[a], ai("heal_rate") * dt)
				u["path"] = []
				u["still_t"] = 0.0
			else:
				_move_to(u, cell_of(s.units[a]), dt)
		"protect":
			var o := int(u["target"])
			if not s.organs.has(o):
				u["state"] = "idle"
				return
			var stand: Array = paths.stand_cells(organs.cells_of(o))
			if stand.has(cell_of(u)):
				u["path"] = []
				u["still_t"] = 0.0
			else:
				_move_to_any(u, stand, dt)
		"engage":
			if str(u["target_kind"]) == "unit":
				var t := int(u["target"])
				if not s.units.has(t):
					u["state"] = "idle"
					return
				if pos_of(s.units[t]).distance_to(me) <= ai("attack_range"):
					u["path"] = []
					u["still_t"] = 0.0
					if float(u["cd"]) <= 0.0:
						_strike_unit(int(u["uid"]), t)
				else:
					_move_to(u, cell_of(s.units[t]), dt)
			elif str(u["target_kind"]) == "organ":
				_engage_organ(u, dt)


func _engage_organ(u: Dictionary, dt: float) -> void:
	var o := int(u["target"])
	if not s.organs.has(o):
		u["state"] = "idle"
		return
	var cells: Array = organs.cells_of(o)
	var me := cell_of(u)
	for c in cells:
		if absi(c.x - me.x) + absi(c.y - me.y) == 1 and pos_of(u).distance_to(Vector2(me)) < 0.2:
			u["path"] = []
			u["still_t"] = 0.0
			if float(u["cd"]) <= 0.0:
				_strike_organ(u, o)
			return
	var stand: Array = paths.stand_cells(cells)
	if not _move_to_any(u, stand, dt):
		# walled off by organs: tear through the first organ on the cheapest route
		var bp: Array = paths.breach_path(me, cells[0])
		for c in bp:
			var blocker: int = s.grid.organ_at(c)
			if blocker >= 0:
				if blocker != o:
					_set_target(u, blocker, "organ", "engage")
					s.count("breaches")
				return


## Follows (or plans) a path to `goal`. Returns false when no path exists.
func _move_to(u: Dictionary, goal: Vector2i, dt: float) -> bool:
	var me := cell_of(u)
	if me == goal:
		_slide(u, Vector2(goal), dt)
		return true
	var p: Array = u["path"]
	u["path_t"] = float(u["path_t"]) - dt
	var stale := p.is_empty() or float(u["path_t"]) <= 0.0 or Vector2i(int(p[p.size() - 1][0]), int(p[p.size() - 1][1])) != goal
	if stale:
		var np: Array = paths.path(me, goal)
		u["path"] = _pack(np)
		u["path_t"] = ai("repath")
		if np.is_empty():
			return false
	_follow(u, dt)
	return true


## Home cell walled off or overgrown: the current cell becomes the new post.
func _adopt_home(u: Dictionary) -> void:
	var c := cell_of(u)
	u["home"] = [c.x, c.y]
	u["path"] = []
	s.count("homes_moved")


func _move_to_any(u: Dictionary, goals: Array, dt: float) -> bool:
	if goals.is_empty():
		return false
	var me := cell_of(u)
	if goals.has(me):
		_slide(u, Vector2(me), dt)
		return true
	var p: Array = u["path"]
	u["path_t"] = float(u["path_t"]) - dt
	var end_ok := not p.is_empty() and goals.has(Vector2i(int(p[p.size() - 1][0]), int(p[p.size() - 1][1])))
	if not end_ok or float(u["path_t"]) <= 0.0:
		var np: Array = paths.path_to_any(me, goals)
		u["path"] = _pack(np)
		u["path_t"] = ai("repath")
		if np.is_empty():
			return false
	_follow(u, dt)
	return true


static func _pack(cells: Array) -> Array:
	var out: Array = []
	for c in cells:
		out.append([c.x, c.y])
	return out


func _follow(u: Dictionary, dt: float) -> void:
	var p: Array = u["path"]
	if p.is_empty():
		return
	var next := Vector2i(int(p[0][0]), int(p[0][1]))
	if not s.grid.walkable(next):
		u["path"] = []   # something grew in the way: plan again next tick
		u["path_t"] = 0.0
		return
	var reached := _slide(u, Vector2(next), dt)
	if reached:
		p.remove_at(0)


## Moves toward `to`; true when arrived.
func _slide(u: Dictionary, to: Vector2, dt: float) -> bool:
	var me := pos_of(u)
	var step := float(u["speed"]) * ai("move_speed") * dt * (0.5 if float(u.get("slow_t", 0.0)) > 0.0 else 1.0)
	var d := me.distance_to(to)
	var np := to if d <= step else me + (to - me) / d * step
	u["pos"] = [np.x, np.y]
	return d <= step


func _watch_stuck(u: Dictionary, dt: float) -> void:
	var st := str(u["state"])
	var c := cell_of(u)
	var last := Vector2i(int(u["last_cell"][0]), int(u["last_cell"][1]))
	var moving_states := ["engage", "protect", "return", "retreat", "heal"]
	if c != last or not moving_states.has(st) or (u["path"] as Array).is_empty() and _in_place(u):
		u["still_t"] = 0.0
		u["last_cell"] = [c.x, c.y]
		if c != last:
			u["resets"] = 0
		return
	u["still_t"] = float(u["still_t"]) + dt
	if float(u["still_t"]) >= ai("stuck_time"):
		u["still_t"] = 0.0
		u["path"] = []
		u["path_t"] = 0.0
		u["resets"] = int(u["resets"]) + 1
		s.count("repaths")
		if int(u["resets"]) >= 2:
			s.count("targets_dropped")
			s.count("drop_%s_%s_%s" % [str(u["team"]), st, str(u["target_kind"])])
			_set_target(u, -1, "", "idle")
			u["resets"] = 0


## True while the unit is doing its job without needing to move (attacking, healing, guarding).
func _in_place(u: Dictionary) -> bool:
	var st := str(u["state"])
	if st == "engage" and str(u["target_kind"]) == "unit" and s.units.has(int(u["target"])):
		return pos_of(s.units[int(u["target"])]).distance_to(pos_of(u)) <= ai("attack_range")
	if st == "engage" and str(u["target_kind"]) == "organ" and s.organs.has(int(u["target"])):
		for c in organs.cells_of(int(u["target"])):
			if absi(c.x - cell_of(u).x) + absi(c.y - cell_of(u).y) == 1:
				return true
	if st == "heal" and s.units.has(int(u["target"])):
		return pos_of(s.units[int(u["target"])]).distance_to(pos_of(u)) <= ai("heal_range")
	if st == "protect" and s.organs.has(int(u["target"])):
		return paths.stand_cells(organs.cells_of(int(u["target"]))).has(cell_of(u))
	return false


# ------------------------------------------------------------------ combat

func _strike_unit(att_uid: int, def_uid: int) -> void:
	var a: Dictionary = s.units[att_uid]
	var r: Dictionary = Rules.unit_vs_unit(a, s.units[def_uid])
	a["cd"] = ai("attack_period")
	_reveal(a)
	var victim: Dictionary = s.units[def_uid]
	if str(victim["team"]) == ABYSS and evolution != null:
		evolution.record(str(r["kind"]), float(r["amount"]), str(a["def"]), str(victim["def"]))
	var thorns := float(victim.get("thorns", 0.0))
	var victim_def := str(victim["def"])
	_hurt_unit(att_uid, def_uid, float(r["amount"]), str(r["reason"]), str(r["kind"]))
	if thorns > 0.0 and s.units.has(att_uid):
		_hurt_unit(def_uid if s.units.has(def_uid) else -1, att_uid, thorns, "acid blood", "acid", victim_def)
	if not s.units.has(att_uid):
		return
	if Rules.has_trait(a, "trait.drain"):
		_heal_unit(a, float(r["amount"]) * ai("drain"))
	if Rules.has_trait(a, "trait.infect") and s.units.has(def_uid):
		s.units[def_uid]["infect_t"] = ai("infect_time")
		s.units[def_uid]["infect_by"] = str(a["def"])


func _strike_organ(u: Dictionary, organ_uid: int) -> void:
	var r: Dictionary = Rules.unit_vs_organ(u)
	u["cd"] = ai("attack_period")
	_reveal(u)
	organs.damage(organ_uid, float(r["amount"]), str(r["kind"]), str(u["def"]))


func _reveal(u: Dictionary) -> void:
	u["first_strike_ready"] = false
	u["hidden"] = false
	u["hide_t"] = 0.0


func _hurt_unit(att_uid: int, def_uid: int, amount: float, reason: String, kind: String = "physical", by: String = "") -> void:
	if not s.units.has(def_uid):
		return
	var d: Dictionary = s.units[def_uid]
	d["hp"] = float(d["hp"]) - amount
	if by == "" and s.units.has(att_uid):
		by = str(s.units[att_uid]["def"])
	d["last_hit"] = {"by": by, "reason": reason, "kind": kind}
	if att_uid >= 0:
		d["aggro"] = att_uid
		d["aggro_t"] = 3.0
	d["hide_t"] = 0.0
	s.fx.emit("unit_hit", def_uid, amount)
	if float(d["hp"]) <= 0.0:
		_die(def_uid, att_uid)


func _die(uid: int, killer: int) -> void:
	if not s.units.has(uid):
		return
	var u: Dictionary = s.units[uid]
	var def_id := str(u["def"])
	var team := str(u["team"])
	var lh: Dictionary = u.get("last_hit", {})
	s.log_death({"victim": def_id, "team": team, "by": str(lh.get("by", "")), "reason": str(lh.get("reason", "")),
		"kind": str(lh.get("kind", ""))})
	s.units.erase(uid)
	if team == ORDER:
		s.count("invaders_killed")
		var d := Reg.get_def(def_id)
		if d.has("body"):
			economy.add_body(str(d["body"]))
		if bool(d.get("sentient", false)):
			_bus("mind_released", [uid, def_id])
			if minds != null:
				minds.release(def_id, cell_of(u))
		if s.units.has(killer):
			var k: Dictionary = s.units[killer]
			k["kills"] = int(k["kills"]) + 1
			if Rules.has_trait(k, "trait.grow_on_kill"):
				k["bonus_hp"] = float(k["bonus_hp"]) + ai("gorge_hp")
				_restat(k)
				k["hp"] = minf(float(k["max_hp"]), float(k["hp"]) + ai("gorge_hp"))
			_gain_xp(k, int(Defs.ZERO["species.zero"]["xp_per_kill"]))
	else:
		s.count("creatures_lost")
		if bool(u.get("spores", false)):
			for e in team_units(ORDER):
				if pos_of(s.units[e]).distance_to(pos_of(u)) <= 2.0:
					s.units[e]["slow_t"] = 4.0
			s.fx.emit("spores", uid, 0.0)
		if def_id == "species.zero":
			s.zero_dead = true
			s.fx.emit("zero_fell", uid, 0.0)
		_bus("creature_died", [uid, "killed" if killer >= 0 else "wounds"])
	s.fx.emit("unit_died", uid, 0.0)
	unit_died.emit(uid, def_id, team)


func _bus(sig: String, args: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bus = tree.root.get_node_or_null("Bus") if tree else null
	if bus:
		bus.callv("emit_signal", [sig] + args)
