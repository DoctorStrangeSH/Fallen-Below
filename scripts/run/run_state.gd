extends RefCounted
## All mutable state of one run, plus pure query helpers. No game rules here.

const D = preload("res://scripts/data/game_data.gd")

signal log_added
signal hand_changed
signal souls_changed

var rng := RandomNumberGenerator.new()

# map
var path: Array[Vector2i] = []
var path_lookup := {}      # Vector2i -> path index
var tiles := []            # path index -> {"card": String, "units": Array}
var scenery := {}          # Vector2i -> card id

# actors
var heroes := []
var nemesis_pool := []
var pending_souls := []
var next_hero_id := 0
var next_party_id := 0

# cards
var hand := []
var selected := -1
var card_weights := {}

# resources & flow
var day := 1
var day_timer := 0.0
var combat_timer := 0.0
var heart_max := D.HEART_BASE
var heart_hp := D.HEART_BASE
var essence := 0
var jar_cap := 2
var threat := 0.0
var boss_spawned := false
var kills := 0
var game_over := false
var paused := false
var time_scale := 1.0

var log_lines := []


func setup(heart: int, jars: int, start_essence: int, weights: Dictionary) -> void:
	rng.randomize()
	heart_max = heart
	heart_hp = heart
	jar_cap = jars
	essence = start_essence
	card_weights = weights
	_build_path()


func _build_path() -> void:
	var a := D.LOOP_MIN
	var b := D.LOOP_MAX
	for x in range(a.x, b.x + 1):
		path.append(Vector2i(x, a.y))
	for y in range(a.y + 1, b.y + 1):
		path.append(Vector2i(b.x, y))
	for x in range(b.x - 1, a.x - 1, -1):
		path.append(Vector2i(x, b.y))
	for y in range(b.y - 1, a.y, -1):
		path.append(Vector2i(a.x, y))
	for i in path.size():
		path_lookup[path[i]] = i
		tiles.append({"card": "", "units": []})


func add_log(msg: String) -> void:
	log_lines.append(msg)
	while log_lines.size() > 8:
		log_lines.pop_front()
	log_added.emit()


# ---------------------------------------------------------- queries

func tile_of(h: Dictionary) -> int:
	return posmod(int(floor(h["pos"])), path.size())


func alive_units(t: int) -> Array:
	var units: Array = tiles[t]["units"]
	return units.filter(func(u): return u["hp"] > 0.0)


func count_units(t: int, unit_name: String) -> int:
	var c := 0
	for u in tiles[t]["units"]:
		if u["name"] == unit_name and u["hp"] > 0.0:
			c += 1
	return c


func undead_count() -> int:
	var c := 0
	for tile in tiles:
		for u in tile["units"]:
			if u["undead"] and u["hp"] > 0.0:
				c += 1
	return c


func neighbors(c: Vector2i) -> Array:
	var out := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				out.append(c + Vector2i(dx, dy))
	return out


func scenery_near(t: int, id: String) -> int:
	var c := 0
	for nb in neighbors(path[t]):
		if scenery.get(nb, "") == id:
			c += 1
	return c


func hero_name(h: Dictionary) -> String:
	var title: String = h["title"]
	var n: String = h["name"]
	return n if title == "" else "%s %s" % [n, title]


func is_blocked() -> bool:
	return game_over or paused or not pending_souls.is_empty()
