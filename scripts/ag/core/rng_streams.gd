extends RefCounted
## Named, independently seeded random streams (TECH_SPEC 2.5).
## One master seed -> one RandomNumberGenerator per stream. State is saved and restored,
## so a run loaded mid-way continues with exactly the same future rolls.

const STREAMS := ["map", "combat", "ai", "events", "breeding"]

var master_seed: int = 0
var _rngs := {}


func _init(seed_value: int = 0) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	master_seed = seed_value
	_rngs.clear()
	for name in STREAMS:
		var r := RandomNumberGenerator.new()
		r.seed = derive_seed(seed_value, name)
		_rngs[name] = r


static func derive_seed(seed_value: int, stream: String) -> int:
	return hash("%d/%s" % [seed_value, stream])


func get_rng(stream: String) -> RandomNumberGenerator:
	assert(_rngs.has(stream), "Unknown RNG stream: " + stream)
	return _rngs[stream]


func randi_range(stream: String, from: int, to: int) -> int:
	return get_rng(stream).randi_range(from, to)


func randf(stream: String) -> float:
	return get_rng(stream).randf()


func pick(stream: String, items: Array):
	if items.is_empty():
		return null
	return items[get_rng(stream).randi_range(0, items.size() - 1)]


## Weighted pick: weights is {key: weight}. Keys are sorted so the result never depends on dictionary order.
func weighted(stream: String, weights: Dictionary):
	var keys: Array = weights.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0:
		return null
	var roll := get_rng(stream).randf() * total
	for k in keys:
		roll -= maxf(0.0, float(weights[k]))
		if roll < 0.0:
			return k
	return keys[keys.size() - 1]


func to_dict() -> Dictionary:
	var states := {}
	for name in _rngs:
		# state is a 64-bit integer; stored as a string so JSON keeps every bit
		states[name] = str((_rngs[name] as RandomNumberGenerator).state)
	return {"seed": str(master_seed), "states": states}


static func from_dict(d: Dictionary):
	var s = load("res://scripts/ag/core/rng_streams.gd").new(int(str(d.get("seed", "0"))))
	var states = d.get("states", {})
	if states is Dictionary:
		for name in states:
			if s._rngs.has(name):
				(s._rngs[name] as RandomNumberGenerator).state = int(str(states[name]))
	return s
