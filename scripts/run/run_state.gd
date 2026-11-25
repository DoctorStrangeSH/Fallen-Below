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
var heart_cell := Vector2i.ZERO

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
var draft := []            # card ids offered at the start of a day

# resources & flow
var act := 1
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
	for attempt in 300:
		var region := _random_region()
		var ring := _trace_ring(region)
		if ring.size() < 30 or ring.size() > 62:
			continue
		var interior := {}
		for c in region:
			if not ring.has(c):
				interior[c] = true
		if interior.size() < 10:
			continue
		_commit_loop(ring, interior)
		return
	push_warning("Map generation failed, using a rectangle.")
	var rect := {}
	for x in range(2, 17):
		for y in range(1, 10):
			rect[Vector2i(x, y)] = true
	var ring := _trace_ring(rect)
	var interior := {}
	for c in rect:
		if not ring.has(c):
			interior[c] = true
	_commit_loop(ring, interior)


## A rectangle with 2-4 notches carved from its sides. Different every run.
func _random_region() -> Dictionary:
	var w := rng.randi_range(11, D.GRID_W - 2)
	var h := rng.randi_range(8, D.GRID_H)
	var x0 := rng.randi_range(1, D.GRID_W - 1 - w)
	var y0 := rng.randi_range(0, D.GRID_H - h)
	var region := {}
	for x in range(x0, x0 + w):
		for y in range(y0, y0 + h):
			region[Vector2i(x, y)] = true
	for n in rng.randi_range(2, 4):
		var side := rng.randi() % 4
		var depth := rng.randi_range(2, 3)
		var length := rng.randi_range(3, 5)
		var rect := Rect2i()
		if side < 2:  # top / bottom
			var sx := rng.randi_range(x0 + 2, x0 + w - 2 - length)
			var sy := y0 if side == 0 else y0 + h - depth
			rect = Rect2i(sx, sy, length, depth)
		else:  # left / right
			length = mini(length, h - 5)
			var sy2 := rng.randi_range(y0 + 2, y0 + h - 2 - length)
			var sx2 := x0 if side == 2 else x0 + w - depth
			rect = Rect2i(sx2, sy2, depth, length)
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				region.erase(Vector2i(x, y))
	return region


## Border cells of the region as an ordered cycle, or [] if it is not a clean loop.
func _trace_ring(region: Dictionary) -> Array:
	var ring := {}
	for c in region:
		for nb in neighbors(c):
			if not region.has(nb):
				ring[c] = true
				break
	if ring.is_empty():
		return []
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	for c in ring:
		var deg := 0
		for d in dirs:
			if ring.has(c + d):
				deg += 1
		if deg != 2:
			return []
	var start: Vector2i = ring.keys()[0]
	var order: Array = [start]
	var prev := start
	var cur := start
	for d in dirs:
		if ring.has(start + d):
			cur = start + d
			break
	while cur != start:
		order.append(cur)
		if order.size() > ring.size():
			return []
		var nxt := cur
		for d in dirs:
			var c2: Vector2i = cur + d
			if c2 != prev and ring.has(c2):
				nxt = c2
				break
		prev = cur
		cur = nxt
	if order.size() != ring.size():
		return []  # more than one loop
	return order


func _commit_loop(ring: Array, interior: Dictionary) -> void:
	# rotate so the Gate is a random tile
	var off := rng.randi() % ring.size()
	for i in ring.size():
		_add_tile(ring[(i + off) % ring.size()])
	loop_size = tiles.size()
	for i in loop_size:
		_link(i, (i + 1) % loop_size)

	# heart: the interior cell farthest from the path
	var best_d := -1
	for c in interior:
		var dmin := 999
		for r in ring:
			var rc: Vector2i = r
			dmin = mini(dmin, absi(rc.x - c.x) + absi(rc.y - c.y))
		if dmin > best_d:
			best_d = dmin
			heart_cell = c
	interior.erase(heart_cell)

	# up to two side passages along straight stretches
	var used := {}
	var starts: Array = range(1, loop_size - 7)
	starts.shuffle()
	var made := 0
	for i in starts:
		if made >= 2:
			break
		if _try_detour(i, interior, used):
			made += 1


func _try_detour(l: int, interior: Dictionary, used: Dictionary) -> bool:
	var r := l + 6
	var d := cell_of(l + 1) - cell_of(l)
	for k in range(l, r):
		if cell_of(k + 1) - cell_of(k) != d:
			return false  # not straight
	for p in [Vector2i(d.y, -d.x), Vector2i(-d.y, d.x)]:
		var inward: Vector2i = p
		var cells: Array = [cell_of(l) + inward]
		for k in range(l, r + 1):
			cells.append(cell_of(k) + inward * 2)
		cells.append(cell_of(r) + inward)
		var ok := true
		for c in cells:
			if not interior.has(c) or used.has(c):
				ok = false
				break
			for nb in neighbors(c):
				if used.has(nb):
					ok = false
		if not ok:
			continue
		for c in cells:
			used[c] = true
			interior.erase(c)
		_add_detour(l, r, inward)
		return true
	return false


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
	return game_over or paused or not pending_souls.is_empty() or not draft.is_empty()


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < D.GRID_W and c.y < D.GRID_H
