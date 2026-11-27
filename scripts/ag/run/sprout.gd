extends Node
## Root of one sprout (AG-01): owns SproutState and the system nodes, runs the fixed 10 Hz clock.
## View and HUD read `state` and call methods here or on the systems.

const Sprout = preload("res://scripts/ag/run/sprout_state.gd")
const MapGen = preload("res://scripts/ag/systems/map_gen.gd")
const OrganSystem = preload("res://scripts/ag/systems/organ_system.gd")
const EconomySystem = preload("res://scripts/ag/systems/economy_system.gd")
const CreatureSystem = preload("res://scripts/ag/systems/creature_system.gd")
const GeneticsSystem = preload("res://scripts/ag/systems/genetics_system.gd")
const EvolutionSystem = preload("res://scripts/ag/systems/evolution_system.gd")
const Defs = preload("res://scripts/ag/data/defs.gd")

const TICK := 0.1

signal started

var state = null
var organs: OrganSystem
var economy: EconomySystem
var creatures: CreatureSystem
var genetics: GeneticsSystem
var evolution: EvolutionSystem
var speed := 1.0
var _acc := 0.0


func _init() -> void:
	organs = OrganSystem.new()
	organs.name = "Organs"
	add_child(organs)
	economy = EconomySystem.new()
	economy.name = "Economy"
	add_child(economy)
	creatures = CreatureSystem.new()
	creatures.name = "Creatures"
	add_child(creatures)
	genetics = GeneticsSystem.new()
	genetics.name = "Genetics"
	add_child(genetics)
	evolution = EvolutionSystem.new()
	evolution.name = "Evolution"
	add_child(evolution)


## New sprout: generate the map and grow the Heart Bud in the middle of its hall.
func start(seed_value: int, biome_id: String = "biome.catacombs") -> void:
	state = Sprout.new(seed_value, biome_id)
	state.grid = MapGen.generate(state.rng, biome_id)
	_wire()
	var c: Vector2i = state.grid.room_center(state.grid.heart_room) - Vector2i(1, 1)
	var uid := organs.place("organ.heart", c)
	assert(uid >= 0, "Heart room must fit the Heart")
	for r in Defs.ECONOMY["start"]:
		state.resources[r] = 0.0
		economy.apply(str(r), float(Defs.ECONOMY["start"][r]), "Sprout start")
	started.emit()


## Continue a loaded sprout.
func resume(loaded) -> void:
	state = loaded
	_wire()
	organs.recompute(true)
	started.emit()


func _wire() -> void:
	organs.setup(state)
	organs.economy = economy
	economy.setup(state, organs)
	economy.creatures = creatures
	creatures.setup(state, organs, economy)
	genetics.setup(state, organs, economy)
	evolution.setup(state, genetics, creatures)
	organs.genetics = genetics
	organs.evolution = evolution
	creatures.genetics = genetics
	creatures.evolution = evolution


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
	economy.tick(TICK)
	creatures.tick(TICK)
	evolution.tick(TICK)
