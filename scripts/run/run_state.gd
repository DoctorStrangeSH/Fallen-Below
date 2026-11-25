extends RefCounted
## All mutable state of one run, plus pure query helpers. No game rules here.
##
## The map is a graph of tiles. Tiles 0..loop_size-1 form the main loop
## (tile 0 is the Gate). Detours branch off the loop and rejoin it later;
## `forks[tile][next_tile]` lists the tiles of each option for hero AI.

const D = preload("res://scripts/data/game_data.gd")

signal log_added
signal hand_changed
signal souls_changed
signal inventory_changed
signal combo_found(combo_name: String)

var rng := RandomNumberGenerator.new()

# map
var tiles := []            # id -> {"cell", "card", "units", "next", "prev"}
var loop_size := 0
var path_lookup := {}      # Vector2i -> tile id
var scenery := {}          # Vector2i -> card id
var forks := {}            # tile id -> {next id -> Array of tile ids}

# actors
var heroes := []
var pending_souls := []
var next_hero_id := 0
var next_party_id := 0

# cards & loot
var hand := []
var selected := -1
var card_weights := {}
var inventory := []
var selected_item := -1

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
	_build_map()


# ---------------------------------------------------------- map building

func _add_tile(c: Vector2i) -> int:
	var id := tiles.size()
	tiles.append({"cell": c, "card": "", "units": [], "next": [], "prev": []})
	path_lookup[c] = id
	return id


func _link(a: int, b: int) -> void:
	tiles[a]["next"].append(b)
	tiles[b]["prev"].append(a)


func _build_map() -> void:
	var a := D.LOOP_MIN
	var b := D.LOOP_MAX
	var cells: Array[Vector2i] = []
	for x in range(a.x, b.x + 1):
		cells.append(Vector2i(x, a.y))
	for y in range(a.y + 1, b.y + 1):
		cells.append(Vector2i(b.x, y))
	for x in range(b.x - 1, a.x - 1, -1):
		cells.append(Vector2i(x, b.y))
	for y in range(b.y - 1, a.y, -1):
		cells.append(Vector2i(a.x, y))
	for c in cells:
		_add_tile(c)
	loop_size = tiles.size()
	for i in loop_size:
		_link(i, (i + 1) % loop_size)

	# two detours: one along the top edge, one along the bottom
	var xt := rng.randi_range(3, 6)
	_add_detour(path_lookup[Vector2i(xt, a.y)], path_lookup[Vector2i(xt + 6, a.y)], Vector2i(0, 1))
	var xb := rng.randi_range(11, 15)
	_add_detour(path_lookup[Vector2i(xb + 6, b.y)], path_lookup[Vector2i(xb, b.y)], Vector2i(0, -1))


## A side passage that leaves loop tile `l`, runs two cells inward and rejoins at loop tile `r`.
func _add_detour(l: int, r: int, inward: Vector2i) -> void:
	var cells: Array[Vector2i] = [cell_of(l) + inward]
	for k in range(l, r + 1):
		cells.append(cell_of(k) + inward * 2)
	cells.append(cell_of(r) + inward)
	var ids := []
	for c in cells:
		ids.append(_add_tile(c))
	for i in ids.size() - 1:
		_link(ids[i], ids[i + 1])
	var main_next: int = tiles[l]["next"][0]
	_link(l, ids[0])
	_link(ids[ids.size() - 1], r)
	var main_seg: Array = range(l + 1, r)
	forks[l] = {main_next: main_seg, ids[0]: ids}


func add_log(msg: String) -> void:
	log_lines.append(msg)
	while log_lines.size() > 8:
		log_lines.pop_front()
	log_added.emit()


# ---------------------------------------------------------- queries

func cell_of(t: int) -> Vector2i:
	return tiles[t]["cell"]


func card_at(t: int) -> String:
	return tiles[t]["card"]


func tile_of(h: Dictionary) -> int:
	return h["cur"]


## Tiles directly before and after `t` along the path graph.
func path_neighbors(t: int) -> Array:
	var out: Array = []
	out.append_array(tiles[t]["prev"])
	out.append_array(tiles[t]["next"])
	return out


func alive_units(t: int) -> Array:
	var units: Array = tiles[t]["units"]
	return units.filter(func(u): return u["hp"] > 0.0)


func undead_at(t: int) -> Array:
	return alive_units(t).filter(func(u): return u["undead"])


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


func scenery_near_cell(c: Vector2i, id: String) -> int:
	var n := 0
	for nb in neighbors(c):
		if scenery.get(nb, "") == id:
			n += 1
	return n


func scenery_near(t: int, id: String) -> int:
	return scenery_near_cell(cell_of(t), id)


func hero_name(h: Dictionary) -> String:
	var title: String = h["title"]
	var n: String = h["name"]
	return n if title == "" else "%s %s" % [n, title]


func bones_value() -> int:
	return day * 3 + kills


func seal_pct() -> float:
	return D.SEAL_WEEK_PCT if day % D.SEAL_EVERY == 0 else D.SEAL_EARLY_PCT


func is_blocked() -> bool:
	return game_over or paused or not pending_souls.is_empty()
