extends Node
## Minds of fallen sentient invaders (GDD 7): digest, keep in the Archive, or give to Zero.
## A mind waits MINDS.time seconds (it does not fade while time is stopped);
## then the default stance decides. Counters feed the story tendencies H and ZF (Narrative Bible 14).

const Reg = preload("res://scripts/ag/core/registry.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

const CHOICES := ["digest", "archive", "zero"]

var s
var economy
var creatures


func setup(state, economy_system, creature_system) -> void:
	s = state
	economy = economy_system
	creatures = creature_system


func release(def_id: String, cell: Vector2i) -> void:
	s.next_mind += 1
	s.minds.append({"id": s.next_mind, "def": def_id, "cell": [cell.x, cell.y], "left": float(Defs.MINDS["time"])})
	s.count("minds_released")
	s.fx.emit("mind_released", cell, 0.0)


func find(id: int) -> Dictionary:
	for m in s.minds:
		if int(m["id"]) == id:
			return m
	return {}


## {"ok", "reason"}
func can(id: int, choice: String) -> Dictionary:
	if find(id).is_empty():
		return {"ok": false, "reason": "That mind is gone."}
	match choice:
		"zero":
			if creatures.zero_uid() < 0:
				return {"ok": false, "reason": "Zero is not here to take it."}
		"archive":
			if economy.net("resource.energy") - float(Defs.MINDS["archive_upkeep"]) < 0.0:
				return {"ok": false, "reason": "Not enough energy to keep another mind."}
		"digest":
			pass
		_:
			return {"ok": false, "reason": "Unknown choice."}
	return {"ok": true, "reason": ""}


func resolve(id: int, choice: String) -> bool:
	if not can(id, choice)["ok"]:
		return false
	var m := find(id)
	s.minds.erase(m)
	match choice:
		"digest":
			var y: Dictionary = Defs.MINDS["digest"]
			var keys: Array = y.keys()
			keys.sort()
			for r in keys:
				economy.apply(str(r), float(y[r]), "Digested minds")
			s.count("minds_digested")
		"archive":
			s.kept_minds += 1
			s.count("minds_archived")
		"zero":
			var z: Dictionary = s.units[creatures.zero_uid()]
			creatures.feed_zero(z, int(Defs.MINDS["zero_xp"]), float(Defs.MINDS["zero_heal"]))
			s.count("minds_to_zero")
	var tree := Engine.get_main_loop() as SceneTree
	var bus = tree.root.get_node_or_null("Bus") if tree else null
	if bus:
		bus.mind_resolved.emit(id, choice)
	s.fx.emit("mind_" + choice, Vector2i(int(m["cell"][0]), int(m["cell"][1])), 0.0)
	return true


func tick(dt: float) -> void:
	for m in s.minds.duplicate():
		m["left"] = float(m["left"]) - dt
		if float(m["left"]) <= 0.0:
			var choice: String = s.mind_stance
			if not can(int(m["id"]), choice)["ok"]:
				choice = "digest"
			resolve(int(m["id"]), choice)


func set_stance(choice: String) -> void:
	if CHOICES.has(choice):
		s.mind_stance = choice
