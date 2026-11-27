extends RefCounted
## State of one sprout (= one run). Stage 02 skeleton: identity, clock, RNG and serialisation.
## Grid, organs, creatures, enemies and scene queue are added in stages 03-10 (TECH_SPEC 3, 5).

const Rng = preload("res://scripts/ag/core/rng_streams.gd")
const Grid = preload("res://scripts/ag/run/grid_state.gd")

## Visible event for sound and effects: kind, target (uid or Vector2i), amount.
signal fx(kind: String, target, amount: float)

const SCHEMA := 3
const GEN_VERSION := 2      # bump when the map generator changes; old mid-run saves are then refused

var seed_value: int = 0
var gen_version: int = GEN_VERSION
var biome_id: String = "biome.catacombs"
var tick: int = 0           # fixed 10 Hz simulation ticks
var rng: Rng
var resources := {"resource.biomass": 0.0, "resource.energy": 0.0, "resource.genome": 0.0}
var paused := false
var grid = null             # GridState
var organs := {}            # uid -> organ instance (TECH_SPEC 3 OrganInstance)
var next_uid: int = 1
var network := {}           # Vector2i -> true: cells linked to the Heart (recomputed, not saved)
var lost := false           # the Heart Bud died
var bodies: Array = []      # digestion queue: [{"id": body id, "left": mass}]
var impulses: float = 0.0   # nerve impulses for commands (stage 07)
var ledger := {}            # res -> {source: total change}; explains every change of the stock


func _init(seed_in: int = 0, biome: String = "biome.catacombs") -> void:
	seed_value = seed_in
	biome_id = biome
	rng = Rng.new(seed_in)


func time_stopped() -> bool:
	return paused


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA, "gen_version": gen_version, "seed": str(seed_value), "biome": biome_id,
		"tick": tick, "rng": rng.to_dict(), "resources": resources.duplicate(),
		"grid": grid.to_dict() if grid else {}, "organs": organs.values(), "next_uid": next_uid, "lost": lost,
		"bodies": bodies.duplicate(true), "impulses": impulses, "ledger": ledger.duplicate(true),
	}


## Returns null when the save belongs to another generator version or is malformed.
static func from_dict(d: Dictionary):
	if int(d.get("schema", 0)) != SCHEMA or int(d.get("gen_version", 0)) != GEN_VERSION:
		return null
	var s = load("res://scripts/ag/run/sprout_state.gd").new(int(str(d.get("seed", "0"))), str(d.get("biome", "biome.catacombs")))
	s.tick = int(d.get("tick", 0))
	var r = d.get("rng", {})
	if r is Dictionary:
		s.rng = Rng.from_dict(r)
	var res = d.get("resources", {})
	if res is Dictionary:
		for k in s.resources:
			s.resources[k] = float(res.get(k, 0.0))
	var g = d.get("grid", {})
	if g is Dictionary and not (g as Dictionary).is_empty():
		s.grid = Grid.from_dict(g)
		if s.grid == null:
			return null
	var os = d.get("organs", [])
	if os is Array:
		for o in os:
			if o is Dictionary:
				var inst: Dictionary = (o as Dictionary).duplicate(true)
				inst["uid"] = int(inst.get("uid", 0))
				inst["cell"] = [int(inst["cell"][0]), int(inst["cell"][1])]
				for k in ["hp", "max_hp", "recover"]:
					inst[k] = float(inst.get(k, 0.0))
				inst["priority"] = int(inst.get("priority", 1))
				s.organs[int(inst["uid"])] = inst
	s.next_uid = int(d.get("next_uid", 1))
	s.lost = bool(d.get("lost", false))
	var bs = d.get("bodies", [])
	if bs is Array:
		for b in bs:
			if b is Dictionary:
				s.bodies.append({"id": str(b.get("id", "")), "left": float(b.get("left", 0.0))})
	s.impulses = float(d.get("impulses", 0.0))
	var lg = d.get("ledger", {})
	if lg is Dictionary:
		for res_id in lg:
			s.ledger[str(res_id)] = {}
			for src in lg[res_id]:
				s.ledger[str(res_id)][str(src)] = float(lg[res_id][src])
	return s


## Stable fingerprint of the serialised state (save/load round-trip and determinism tests).
func state_hash() -> int:
	return hash(JSON.stringify(to_dict(), "", true))
