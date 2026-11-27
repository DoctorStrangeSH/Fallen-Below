extends Node
## Resources of a sprout (GDD 5, TECH_SPEC AG-04).
## Every change goes through apply() with a named source, so the ledger always explains the stock.
## rates() is the single source of truth: tick() applies it and forecast() multiplies it,
## so the forecast equals what happens while the situation stays the same.
## Energy deficit: organs fall asleep by priority (low first) until the balance is not negative;
## they wake up again only when the balance stays non-negative with them awake (no flapping).

const Reg = preload("res://scripts/ag/core/registry.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

const RESOURCES := ["resource.biomass", "resource.energy", "resource.genome"]
const WORKING := ["normal", "damaged", "critical", "recovering"]
const ENERGY := "resource.energy"

var s       # SproutState
var organs  # OrganSystem
var creatures = null  # CreatureSystem: creature upkeep


func setup(state, organ_system) -> void:
	s = state
	organs = organ_system


static func eco(key: String):
	return Defs.ECONOMY[key]


# ------------------------------------------------------------------ stock

func amount(res: String) -> float:
	return float(s.resources.get(res, 0.0))


func cap(res: String) -> float:
	var total := 0.0
	for uid in _uids():
		var d := Reg.get_def(str(s.organs[uid]["def"]))
		total += float((d.get("storage", {}) as Dictionary).get(res, 0.0))
	return total


func can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if amount(str(r)) + 0.0001 < float(cost[r]):
			return false
	return true


## First resource that is short, or "" when the cost is affordable.
func missing(cost: Dictionary) -> String:
	var keys: Array = cost.keys()
	keys.sort()
	for r in keys:
		if amount(str(r)) + 0.0001 < float(cost[r]):
			return str(r)
	return ""


func pay(cost: Dictionary, source: String) -> bool:
	if not can_afford(cost):
		return false
	var keys: Array = cost.keys()
	keys.sort()
	for r in keys:
		apply(str(r), -float(cost[r]), source)
	return true


## The only way resources change. Overflow above the cap is recorded, not hidden.
func apply(res: String, delta: float, source: String) -> void:
	var before := amount(res)
	var after := before + delta
	var c := cap(res)
	if after > c:
		_record(res, "Overflow", c - after)
		after = c
	if after < 0.0:
		push_warning("Economy: %s would go below zero (%s)" % [res, source])
		_record(res, "Shortage", -after)
		after = 0.0
	s.resources[res] = after
	_record(res, source, delta)


func _record(res: String, source: String, delta: float) -> void:
	if not s.ledger.has(res):
		s.ledger[res] = {}
	s.ledger[res][source] = float(s.ledger[res].get(source, 0.0)) + delta


# ------------------------------------------------------------------ rates

func _uids() -> Array:
	var out: Array = s.organs.keys()
	out.sort()
	return out


func is_working(uid: int) -> bool:
	return WORKING.has(str(s.organs[uid]["state"]))


func organ_name(uid: int) -> String:
	return str(Reg.get_def(str(s.organs[uid]["def"])).get("name", "?"))


## Flows per second at this moment: [{"res", "amount", "source"}], deterministic order.
## With dt > 0 (inside a tick) digestion is limited to the mass that is actually left.
func rates(dt: float = 0.0) -> Array:
	var out: Array = []
	for uid in _uids():
		var o: Dictionary = s.organs[uid]
		var d := Reg.get_def(str(o["def"]))
		var working := is_working(uid) or str(o["def"]) == "organ.heart"
		if not working:
			continue
		var name := organ_name(uid)
		var prod: Dictionary = d.get("produces", {})
		for r in prod:
			if RESOURCES.has(str(r)):
				out.append({"res": str(r), "amount": float(prod[r]), "source": "Roots" if str(r) == "resource.biomass" and str(o["def"]) == "organ.heart" else name})
		var up: Dictionary = d.get("upkeep", {})
		for r in up:
			out.append({"res": str(r), "amount": -float(up[r]), "source": name})
	if creatures != null:
		var cu: float = creatures.upkeep_rate() * (1.0 - s.starve_frac)
		if cu > 0.0:
			out.append({"res": ENERGY, "amount": -cu, "source": "Creatures"})
	# digestion: each working Stomach works on its own body from the queue
	var k := 0
	for uid in _uids():
		if str(s.organs[uid]["def"]) != "organ.stomach" or not is_working(uid):
			continue
		if k >= s.bodies.size():
			break
		var body: Dictionary = s.bodies[k]
		var bd := Reg.get_def(str(body["id"]))
		var speed := _digest_speed(body, dt)
		var y: Dictionary = bd.get("yield", {})
		for r in y:
			out.append({"res": str(r), "amount": float(y[r]) / float(bd["mass"]) * speed, "source": "Digestion"})
		k += 1
	# regeneration: biomass spent on healing organs in range
	var heal := regen_plan()
	var total := 0.0
	for uid in heal:
		total += float(heal[uid])
	if total > 0.0:
		out.append({"res": "resource.biomass", "amount": -total * float(eco("regen_cost")), "source": "Regeneration"})
	return out


## {organ uid: hp per second} that working Regenerative Tissue would heal now.
func regen_plan() -> Dictionary:
	var plan := {}
	if amount("resource.biomass") < 5.0:
		return plan   # no biomass left to spend on healing
	var rng: int = int(eco("regen_range"))
	for uid in _uids():
		if str(s.organs[uid]["def"]) != "organ.regen_tissue" or not is_working(uid):
			continue
		var src: Array = organs.cells_of(uid)
		for other in _uids():
			var o: Dictionary = s.organs[other]
			if float(o["hp"]) >= float(o["max_hp"]):
				continue
			var near := false
			for a in src:
				for b in organs.cells_of(other):
					if maxi(absi(a.x - b.x), absi(a.y - b.y)) <= rng:
						near = true
			if near:
				plan[other] = float(plan.get(other, 0.0)) + float(eco("regen_heal"))
	return plan


func net(res: String) -> float:
	var n := 0.0
	for f in rates():
		if f["res"] == res:
			n += float(f["amount"])
	return n


## {res: {"net": float, "lines": {source: float}}} over `seconds` at the current rates.
func forecast(seconds: float = 10.0) -> Dictionary:
	var out := {}
	for r in RESOURCES:
		out[r] = {"net": 0.0, "lines": {}}
	for f in rates():
		var e: Dictionary = out[f["res"]]
		e["net"] = float(e["net"]) + float(f["amount"]) * seconds
		e["lines"][f["source"]] = float(e["lines"].get(f["source"], 0.0)) + float(f["amount"]) * seconds
	return out


# ------------------------------------------------------------------ deficit

## Puts organs to sleep (lowest priority, then highest upkeep, then newest) while energy would run out,
## and wakes sleepers (highest priority first) when the balance stays non-negative with them.
func balance_energy(dt: float) -> void:
	s.starving = false
	s.starve_frac = 0.0
	var guard := 0
	while amount(ENERGY) + net(ENERGY) * dt < 0.0 and guard < 64:
		guard += 1
		var victim := _sleep_candidate()
		if victim < 0:
			break
		s.organs[victim]["asleep"] = true
		organs.refresh(victim)
		s.fx.emit("organ_sleep", victim, 0.0)
	if amount(ENERGY) + net(ENERGY) * dt < 0.0 and creatures != null:
		# every organ that can sleep is asleep and it is still not enough: creatures get only
		# the share of energy that exists, and weaken in proportion to what they miss
		var cu: float = creatures.upkeep_rate()
		if cu > 0.0:
			var without := net(ENERGY) + cu
			var paid := clampf((amount(ENERGY) / dt + without) / cu, 0.0, 1.0)
			s.starve_frac = 1.0 - paid
			s.starving = s.starve_frac > 0.0
		return
	var sleepers: Array = []
	for uid in _uids():
		if bool(s.organs[uid].get("asleep", false)):
			sleepers.append(uid)
	sleepers.sort_custom(func(a, b): return _wake_key(a) > _wake_key(b))
	for uid in sleepers:
		var up := float((Reg.get_def(str(s.organs[uid]["def"])).get("upkeep", {}) as Dictionary).get(ENERGY, 0.0))
		if net(ENERGY) - up >= 0.0:
			s.organs[uid]["asleep"] = false
			organs.refresh(uid)
			s.fx.emit("organ_wake", uid, 0.0)


func _sleep_candidate() -> int:
	var best := -1
	var best_key := []
	for uid in _uids():
		var o: Dictionary = s.organs[uid]
		if str(o["def"]) == "organ.heart" or not is_working(uid):
			continue
		var up := float((Reg.get_def(str(o["def"])).get("upkeep", {}) as Dictionary).get(ENERGY, 0.0))
		if up <= 0.0:
			continue
		var key := [int(o.get("priority", 1)), -up, -int(uid)]
		if best < 0 or key < best_key:
			best = uid
			best_key = key
	return best


func _wake_key(uid: int) -> Array:
	return [int(s.organs[uid].get("priority", 1)), -int(uid)]


# ------------------------------------------------------------------ tick

func tick(dt: float) -> void:
	balance_energy(dt)
	var flows := rates(dt)
	var heal := regen_plan()
	for f in flows:
		apply(str(f["res"]), float(f["amount"]) * dt, str(f["source"]))
	for uid in heal:
		organs.heal(int(uid), float(heal[uid]) * dt)
	_advance_digestion(dt)
	_impulses(dt)


func _digest_speed(body: Dictionary, dt: float) -> float:
	var speed := float(eco("digest_speed"))
	if dt > 0.0:
		speed = minf(speed, float(body["left"]) / dt)
	return speed


func _advance_digestion(dt: float) -> void:
	var k := 0
	var done: Array = []
	for uid in _uids():
		if str(s.organs[uid]["def"]) != "organ.stomach" or not is_working(uid):
			continue
		if k >= s.bodies.size():
			break
		var body: Dictionary = s.bodies[k]
		body["left"] = float(body["left"]) - _digest_speed(body, dt) * dt
		if float(body["left"]) <= 0.0001:
			done.append(body)
		k += 1
	for b in done:
		s.bodies.erase(b)
		s.fx.emit("digested", str(b["id"]), 0.0)


func add_body(body_id: String) -> void:
	var d := Reg.get_def(body_id)
	if d.is_empty():
		return
	s.bodies.append({"id": body_id, "left": float(d["mass"])})


func impulse_cap() -> float:
	var n := 0
	for uid in _uids():
		if str(s.organs[uid]["def"]) == "organ.nerve_node" and is_working(uid):
			n += 1
	return float(eco("impulse_base_cap")) + float(eco("impulse_cap_per_node")) * n


func impulse_rate() -> float:
	var r := 0.0
	for uid in _uids():
		if is_working(uid):
			r += float((Reg.get_def(str(s.organs[uid]["def"])).get("produces", {}) as Dictionary).get("impulse", 0.0))
	return r


func _impulses(dt: float) -> void:
	s.impulses = clampf(s.impulses + impulse_rate() * dt, 0.0, impulse_cap())
