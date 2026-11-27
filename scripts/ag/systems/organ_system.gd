extends Node
## Organs and living channels (GDD 4.1, TECH_SPEC AG-03).
## An organ works only while a chain of channels and organs links it to the Heart Bud.
## Organs relay the connection: an organ touching a connected organ is connected too.
## Gets `s` (SproutState) injected. Never preloads the sprout root.

const Reg = preload("res://scripts/ag/core/registry.gd")
const Grid = preload("res://scripts/ag/run/grid_state.gd")

const RECOVER_TIME := 3.0   # seconds an organ needs to wake up after being reconnected

signal organ_changed(uid: int)
signal heart_destroyed

const Defs = preload("res://scripts/ag/data/defs.gd")
const PRIORITY_NAMES := ["Low priority", "Normal priority", "High priority"]

var s   # SproutState
var economy = null   # EconomySystem; when set, organs and channels cost resources
var genetics = null  # GeneticsSystem: line mutations on new organs, organ stats
var evolution = null # EvolutionSystem: threat log


func setup(state) -> void:
	s = state


# ------------------------------------------------------------------ queries

func def_of(uid: int) -> Dictionary:
	var o: Dictionary = s.organs.get(uid, {})
	return Reg.get_def(str(o.get("def", "")))


func cells_of(uid: int) -> Array:
	var o: Dictionary = s.organs.get(uid, {})
	if o.is_empty():
		return []
	return footprint_cells(str(o["def"]), Vector2i(int(o["cell"][0]), int(o["cell"][1])))


static func footprint_cells(def_id: String, at: Vector2i) -> Array:
	var out: Array = []
	for off in Reg.get_def(def_id).get("footprint", [Vector2i.ZERO]):
		out.append(at + (off as Vector2i))
	return out


func heart_uid() -> int:
	for uid in s.organs:
		if str(s.organs[uid]["def"]) == "organ.heart":
			return int(uid)
	return -1


## {"ok": bool, "reason": String (English Loc key)}
func can_place(def_id: String, at: Vector2i) -> Dictionary:
	var d := Reg.get_def(def_id)
	if d.is_empty() or Reg.kind_of(def_id) != "organ":
		return {"ok": false, "reason": "Unknown organ."}
	if def_id == "organ.heart" and heart_uid() >= 0:
		return {"ok": false, "reason": "A sprout has only one Heart."}
	var g = s.grid
	for c in footprint_cells(def_id, at):
		if not g.in_bounds(c):
			return {"ok": false, "reason": "Out of bounds."}
		if not g.is_floor(c):
			return {"ok": false, "reason": "Solid rock. Organs grow only in halls and corridors."}
		if g.organ_at(c) >= 0:
			return {"ok": false, "reason": "Another organ already grows here."}
		if g.tissue_at(c) == Grid.T_WATER:
			return {"ok": false, "reason": "Organs cannot take root in water."}
		if g.is_entrance(c):
			return {"ok": false, "reason": "Entrances cannot be sealed by organs."}
	return _afford(d.get("cost", {}))


func _afford(cost: Dictionary) -> Dictionary:
	if economy != null:
		var m: String = economy.missing(cost)
		if m != "":
			return {"ok": false, "reason": "Not enough %s.", "arg": str(Reg.get_def(m).get("name", m))}
	return {"ok": true, "reason": ""}


func can_lay_channel(c: Vector2i) -> Dictionary:
	var g = s.grid
	if not g.is_floor(c):
		return {"ok": false, "reason": "Channels grow only along floor."}
	if g.organ_at(c) >= 0:
		return {"ok": false, "reason": "An organ is already here."}
	if g.has_channel(c):
		return {"ok": false, "reason": "There is already a channel here."}
	if g.is_entrance(c):
		return {"ok": false, "reason": "Entrances cannot be sealed by organs."}
	return _afford(Defs.ECONOMY["channel_cost"])


func state_of(uid: int) -> String:
	return str(s.organs.get(uid, {}).get("state", "destroyed"))


# ------------------------------------------------------------------ changes

## Returns the new uid, or -1 when the spot is not allowed.
func place(def_id: String, at: Vector2i) -> int:
	if not can_place(def_id, at)["ok"]:
		return -1
	var d := Reg.get_def(def_id)
	if economy != null and not economy.pay(d.get("cost", {}), "Construction"):
		return -1
	var uid: int = s.next_uid
	s.next_uid += 1
	var hp := float(d.get("hp", 100))
	s.organs[uid] = {
		"uid": uid, "def": def_id, "cell": [at.x, at.y], "hp": hp, "max_hp": hp,
		"state": "normal", "connected": false, "recover": 0.0, "mutations": [],
		"priority": 1, "dormant": false, "asleep": false,
	}
	for c in footprint_cells(def_id, at):
		var i: int = s.grid.idx(c)
		s.grid.organ[i] = uid
		s.grid.channel[i] = 0   # the organ itself carries the signal now
	s.grid_version += 1
	if genetics != null:
		genetics.on_organ_placed(uid)
	recompute(true)
	s.fx.emit("organ_grow", uid, 0.0)
	return uid


func lay_channel(c: Vector2i) -> bool:
	if not can_lay_channel(c)["ok"]:
		return false
	if economy != null and not economy.pay(Defs.ECONOMY["channel_cost"], "Channels"):
		return false
	s.grid.channel[s.grid.idx(c)] = 1
	recompute()
	s.fx.emit("channel_grow", c, 0.0)
	return true


## Cuts a channel cell (player removal or enemy action).
func cut_channel(c: Vector2i) -> bool:
	if not s.grid.has_channel(c):
		return false
	s.grid.channel[s.grid.idx(c)] = 0
	recompute()
	s.fx.emit("channel_cut", c, 0.0)
	return true


## Applies damage with resistances and weaknesses. Returns the damage actually dealt.
func damage(uid: int, amount: float, kind: String = "physical", attacker_def: String = "") -> float:
	if not s.organs.has(uid):
		return 0.0
	var d := def_of(uid)
	var o: Dictionary = s.organs[uid]
	var mult := 1.0 - float((d.get("resist", {}) as Dictionary).get(kind, 0.0)) \
		- float((o.get("resist", {}) as Dictionary).get(kind, 0.0)) + float((d.get("weak", {}) as Dictionary).get(kind, 0.0))
	var dealt := maxf(0.0, amount * maxf(0.0, mult))
	if evolution != null:
		evolution.record(kind, dealt, attacker_def, str(o["def"]))
	var note := ""
	if mult < 1.0:
		note = kind + " resisted"
	elif mult > 1.0:
		note = kind + " weakness"
	o["last_hit"] = {"by": attacker_def, "reason": note, "kind": kind}
	o["hp"] = maxf(0.0, float(o["hp"]) - dealt)
	_bus("organ_damaged", [uid, dealt, kind])
	s.alerts[uid] = float(Defs.AI["alert_time"])
	s.fx.emit("organ_hit", uid, dealt)
	if float(o["hp"]) <= 0.0:
		destroy(uid)
	else:
		refresh(uid)
	return dealt


func heal(uid: int, amount: float) -> void:
	if not s.organs.has(uid):
		return
	var o: Dictionary = s.organs[uid]
	o["hp"] = minf(float(o["max_hp"]), float(o["hp"]) + amount * float(o.get("heal_mult", 1.0)))
	refresh(uid)


func destroy(uid: int) -> void:
	if not s.organs.has(uid):
		return
	var is_heart := str(s.organs[uid]["def"]) == "organ.heart"
	var lh: Dictionary = s.organs[uid].get("last_hit", {})
	s.log_death({"victim": str(s.organs[uid]["def"]), "team": "organ", "by": str(lh.get("by", "")),
		"reason": str(lh.get("reason", "")), "kind": str(lh.get("kind", ""))})
	for c in cells_of(uid):
		var i: int = s.grid.idx(c)
		s.grid.organ[i] = -1
		s.grid.scar[i] = 1.0
	s.grid_version += 1
	s.organs.erase(uid)
	_bus("organ_state_changed", [uid, "destroyed"])
	s.fx.emit("organ_destroyed", uid, 0.0)
	organ_changed.emit(uid)
	if is_heart:
		s.lost = true
		heart_destroyed.emit()
	recompute()


## Player takes an organ back into the body: part of its cost returns, no scar is left.
func reabsorb(uid: int) -> bool:
	if not s.organs.has(uid) or str(s.organs[uid]["def"]) == "organ.heart":
		return false
	var cost: Dictionary = def_of(uid).get("cost", {})
	for c in cells_of(uid):
		s.grid.organ[s.grid.idx(c)] = -1
	s.grid_version += 1
	s.organs.erase(uid)
	if economy != null:
		var keys: Array = cost.keys()
		keys.sort()
		for r in keys:
			economy.apply(str(r), float(cost[r]) * float(Defs.ECONOMY["reabsorb_refund"]), "Reabsorbed organs")
	_bus("organ_state_changed", [uid, "destroyed"])
	s.fx.emit("organ_reabsorb", uid, 0.0)
	organ_changed.emit(uid)
	recompute()
	return true


## Manual sleep: the organ stops working and stops costing upkeep.
func set_dormant(uid: int, on: bool) -> void:
	if not s.organs.has(uid) or str(s.organs[uid]["def"]) == "organ.heart":
		return
	s.organs[uid]["dormant"] = on
	refresh(uid)


func cycle_priority(uid: int) -> int:
	if not s.organs.has(uid):
		return 1
	var p := (int(s.organs[uid].get("priority", 1)) + 1) % 3
	s.organs[uid]["priority"] = p
	return p


func tick(delta: float) -> void:
	for uid in s.organs:
		var o: Dictionary = s.organs[uid]
		if float(o.get("regen", 0.0)) > 0.0 and float(o["hp"]) < float(o["max_hp"]):
			heal(int(uid), float(o["regen"]) * float(o["max_hp"]) * delta)
		if float(o["recover"]) > 0.0:
			o["recover"] = maxf(0.0, float(o["recover"]) - delta)
			if float(o["recover"]) == 0.0:
				refresh(int(uid))


## Shortest route of free floor cells from `from` to the nearest cell next to the network.
## Used by "auto-route" (Shift+click) and by tests. Empty when unreachable.
func channel_route(from: Vector2i) -> Array:
	var g = s.grid
	if s.network.has(from):
		return []
	var prev := {from: from}
	var queue: Array = [from]
	var goal := Vector2i(-1, -1)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var touches := false
		for n in g.neighbors(c):
			if s.network.has(n):
				touches = true
		if touches:
			goal = c
			break
		for n in g.neighbors(c):
			if not prev.has(n) and g.is_floor(n) and g.organ_at(n) < 0 and not g.is_entrance(n):
				prev[n] = c
				queue.append(n)
	if goal.x < 0:
		return []
	var path: Array = []
	var c: Vector2i = goal
	while true:
		path.push_front(c)
		if c == from:
			break
		c = prev[c]
	return path


# ------------------------------------------------------------------ connectivity

## Flood from the Heart through channels and organs; updates every organ's "connected" flag.
## `fresh` organs that connect immediately (just placed) skip the wake-up delay.
func recompute(fresh: bool = false) -> void:
	var g = s.grid
	var reached := {}
	var hu := heart_uid()
	var queue: Array = []
	if hu >= 0:
		for c in cells_of(hu):
			reached[c] = true
			queue.append(c)
	var linked := {}
	if hu >= 0:
		linked[hu] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for n in g.neighbors(c):
			if reached.has(n):
				continue
			var ou: int = g.organ_at(n)
			if ou >= 0:
				linked[ou] = true
				for oc in cells_of(ou):
					if not reached.has(oc):
						reached[oc] = true
						queue.append(oc)
			elif g.has_channel(n):
				reached[n] = true
				queue.append(n)
	s.network = reached
	for uid in s.organs:
		var o: Dictionary = s.organs[uid]
		var d := Reg.get_def(str(o["def"]))
		var now: bool = linked.has(uid) or not bool(d.get("needs_channel", true))
		var was: bool = bool(o["connected"])
		if now != was:
			o["connected"] = now
			if now and not fresh:
				o["recover"] = RECOVER_TIME
			refresh(int(uid))
		elif fresh and str(o["state"]) == "normal" and not now:
			refresh(int(uid))


func refresh(uid: int) -> void:
	var o: Dictionary = s.organs[uid]
	var st := "normal"
	var ratio := float(o["hp"]) / maxf(1.0, float(o["max_hp"]))
	if not bool(o["connected"]):
		st = "disabled"
	elif bool(o.get("dormant", false)):
		st = "dormant"
	elif bool(o.get("asleep", false)):
		st = "asleep"
	elif float(o["recover"]) > 0.0:
		st = "recovering"
	elif ratio < 0.25:
		st = "critical"
	elif ratio < 0.6:
		st = "damaged"
	if st != str(o["state"]):
		o["state"] = st
		_bus("organ_state_changed", [uid, st])
		organ_changed.emit(uid)


func _bus(sig: String, args: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bus = tree.root.get_node_or_null("Bus") if tree else null
	if bus:
		bus.callv("emit_signal", [sig] + args)
