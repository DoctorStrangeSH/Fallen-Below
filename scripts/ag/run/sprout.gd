extends Node
## Root of one sprout (AG-01): owns SproutState and the system nodes, runs the fixed 10 Hz clock.
## View and HUD read `state` and call methods here or on the systems.

const Sprout = preload("res://scripts/ag/run/sprout_state.gd")
const MapGen = preload("res://scripts/ag/systems/map_gen.gd")
const OrganSystem = preload("res://scripts/ag/systems/organ_system.gd")

const TICK := 0.1

signal started

var state = null
var organs: OrganSystem
var speed := 1.0
var _acc := 0.0


func _init() -> void:
	organs = OrganSystem.new()
	organs.name = "Organs"
	add_child(organs)


## New sprout: generate the map and grow the Heart Bud in the middle of its hall.
func start(seed_value: int, biome_id: String = "biome.catacombs") -> void:
	state = Sprout.new(seed_value, biome_id)
	state.grid = MapGen.generate(state.rng, biome_id)
	organs.setup(state)
	var c: Vector2i = state.grid.room_center(state.grid.heart_room) - Vector2i(1, 1)
	var uid := organs.place("organ.heart", c)
	assert(uid >= 0, "Heart room must fit the Heart")
	started.emit()


## Continue a loaded sprout.
func resume(loaded) -> void:
	state = loaded
	organs.setup(state)
	organs.recompute(true)
	started.emit()


func _process(delta: float) -> void:
	if state == null or state.time_stopped() or state.lost:
		return
	_acc += delta * speed
	while _acc >= TICK:
		_acc -= TICK
		step()


## One fixed simulation tick (also called directly by tests).
func step() -> void:
	state.tick += 1
	organs.tick(TICK)
