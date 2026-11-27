extends "res://tests/ag/unit_case.gd"

const Rng = preload("res://scripts/ag/core/rng_streams.gd")
const Sprout = preload("res://scripts/ag/run/sprout_state.gd")


func _seq(r, stream: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(r.randi_range(stream, 0, 1000000))
	return out


func test_same_seed_same_sequence() -> void:
	eq(_seq(Rng.new(42), "map", 20), _seq(Rng.new(42), "map", 20), "seed 42 map")
	check(_seq(Rng.new(42), "map", 20) != _seq(Rng.new(43), "map", 20), "different seeds differ")


func test_streams_are_independent() -> void:
	var a = Rng.new(7)
	var b = Rng.new(7)
	_seq(b, "combat", 50)   # combat rolls must not shift the map
	eq(_seq(a, "map", 10), _seq(b, "map", 10), "map unaffected by combat")
	check(_seq(Rng.new(7), "map", 10) != _seq(Rng.new(7), "ai", 10), "streams differ")


func test_restore_continues_exactly() -> void:
	var a = Rng.new(99)
	_seq(a, "events", 13)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict(), "", true, true))
	var b = Rng.from_dict(saved)
	eq(_seq(b, "events", 25), _seq(a, "events", 25), "continues after JSON round-trip")


func test_weighted_is_order_independent() -> void:
	var w1 := {"a": 1.0, "b": 2.0, "c": 3.0}
	var w2 := {"c": 3.0, "a": 1.0, "b": 2.0}
	var r1 = Rng.new(5)
	var r2 = Rng.new(5)
	var s1: Array = []
	var s2: Array = []
	for i in 30:
		s1.append(r1.weighted("events", w1))
		s2.append(r2.weighted("events", w2))
	eq(s1, s2, "weighted picks")


func test_large_seed_survives_json() -> void:
	var big := 9007199254740993   # above 2^53: would lose bits as a JSON number
	var s = Sprout.new(big)
	var back = Sprout.from_dict(JSON.parse_string(JSON.stringify(s.to_dict(), "", true, true)))
	eq(back.seed_value, big, "seed kept")
	eq(back.state_hash(), s.state_hash(), "state hash")
