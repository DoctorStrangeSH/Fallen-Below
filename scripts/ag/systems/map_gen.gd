extends RefCounted
## Grid generator for a sprout (GDD 4). Deterministic: uses only the "map" RNG stream.
## Rooms -> minimum spanning tree of corridors + a few loops -> entrances on the border -> biome features.
## Bump SproutState.GEN_VERSION whenever the output for a given seed changes.

const Grid = preload("res://scripts/ag/run/grid_state.gd")

const W := 56
const H := 30
const MAX_ROOMS := 11
const ENTRANCES := 3


static func generate(rng, biome_id: String = "biome.catacombs", w: int = W, h: int = H):
	var g = Grid.new(w, h)
	var r: RandomNumberGenerator = rng.get_rng("map")
	_place_rooms(g, r)
	_connect_rooms(g, r)
	_add_entrances(g, r)
	_decorate(g, r, biome_id)
	return g


static func _carve(g, c: Vector2i, room_id: int = -1) -> void:
	if not g.in_bounds(c):
		return
	var i: int = g.idx(c)
	g.floor[i] = Grid.FLOOR
	if room_id >= 0:
		g.room[i] = room_id


static func _place_rooms(g, r: RandomNumberGenerator) -> void:
	# the Heart's room sits near the middle so every entrance is far from it
	var hw := 8
	var hh := 6
	var hx: int = g.w / 2 - hw / 2 + r.randi_range(-3, 3)
	var hy: int = g.h / 2 - hh / 2 + r.randi_range(-2, 2)
	g.rooms.append(Rect2i(hx, hy, hw, hh))
	g.heart_room = 0
	var tries := 0
	while g.rooms.size() < MAX_ROOMS and tries < 300:
		tries += 1
		var rw := r.randi_range(4, 9)
		var rh := r.randi_range(4, 7)
		var rect := Rect2i(r.randi_range(2, g.w - rw - 2), r.randi_range(2, g.h - rh - 2), rw, rh)
		var ok := true
		for other in g.rooms:
			if (other as Rect2i).grow(2).intersects(rect):
				ok = false
				break
		if ok:
			g.rooms.append(rect)
	for i in g.rooms.size():
		var rect: Rect2i = g.rooms[i]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				_carve(g, Vector2i(x, y), i)


static func _corridor(g, r: RandomNumberGenerator, a: Vector2i, b: Vector2i) -> void:
	var wide := r.randf() < 0.3
	var corner := Vector2i(b.x, a.y) if r.randf() < 0.5 else Vector2i(a.x, b.y)
	for seg in [[a, corner], [corner, b]]:
		var p: Vector2i = seg[0]
		var q: Vector2i = seg[1]
		var step := Vector2i(signi(q.x - p.x), signi(q.y - p.y))
		var horizontal := step.y == 0
		while true:
			_carve(g, p)
			if wide:
				_carve(g, p + (Vector2i(0, 1) if horizontal else Vector2i(1, 0)))
			if p == q:
				break
			p += step


static func _connect_rooms(g, r: RandomNumberGenerator) -> void:
	var n: int = g.rooms.size()
	var edges: Array = []
	for i in n:
		for j in range(i + 1, n):
			var d: int = (g.room_center(i) - g.room_center(j)).length_squared()
			edges.append([d, i, j])
	edges.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and (x[1] < y[1] or (x[1] == y[1] and x[2] < y[2]))))
	# Kruskal over sorted edges: deterministic minimum spanning tree
	var parent: Array = range(n)
	var find := func(x: int) -> int:
		while parent[x] != x:
			x = parent[x]
		return x
	var spare: Array = []
	for e in edges:
		var a: int = find.call(e[1])
		var b: int = find.call(e[2])
		if a != b:
			parent[a] = b
			_corridor(g, r, g.room_center(e[1]), g.room_center(e[2]))
		elif spare.size() < 6:
			spare.append(e)
	# a couple of loops so invaders have more than one route
	for k in mini(2, spare.size()):
		var e: Array = spare[r.randi_range(0, spare.size() - 1)]
		spare.erase(e)
		_corridor(g, r, g.room_center(e[1]), g.room_center(e[2]))


static func _add_entrances(g, r: RandomNumberGenerator) -> void:
	var heart: Vector2i = g.room_center(g.heart_room)
	var order: Array = range(1, g.rooms.size())
	order.sort_custom(func(a, b):
		var da: int = (g.room_center(a) - heart).length_squared()
		var db: int = (g.room_center(b) - heart).length_squared()
		return da > db or (da == db and a < b))
	var used_sides := {}
	for ri in order:
		if g.entrances.size() >= ENTRANCES:
			break
		var c: Vector2i = g.room_center(ri)
		# nearest border side not used yet
		var sides := {"left": c.x, "right": g.w - 1 - c.x, "top": c.y, "bottom": g.h - 1 - c.y}
		var names: Array = sides.keys()
		names.sort_custom(func(a, b): return sides[a] < sides[b] or (sides[a] == sides[b] and a < b))
		var side := ""
		for s in names:
			if not used_sides.has(s):
				side = s
				break
		if side == "":
			break
		used_sides[side] = true
		var target := c
		match side:
			"left": target = Vector2i(0, c.y)
			"right": target = Vector2i(g.w - 1, c.y)
			"top": target = Vector2i(c.x, 0)
			"bottom": target = Vector2i(c.x, g.h - 1)
		_corridor(g, r, c, target)
		g.entrances.append(target)


static func _decorate(g, r: RandomNumberGenerator, _biome_id: String) -> void:
	# Forgotten Catacombs: bone deposits in a few rooms, one flooded room, one EDEN ruin
	var others: Array = range(1, g.rooms.size())
	for i in range(others.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	var k := 0
	for ri in others:
		var rect: Rect2i = g.rooms[ri]
		if k < 3:
			for c in r.randi_range(2, 4):
				var p := Vector2i(r.randi_range(rect.position.x, rect.end.x - 1), r.randi_range(rect.position.y, rect.end.y - 1))
				for q in [p, p + Vector2i(1, 0), p + Vector2i(0, 1)]:
					if g.is_floor(q) and g.room[g.idx(q)] == ri:
						g.tissue[g.idx(q)] = Grid.T_BONE
		elif k == 3:
			var pool := Rect2i(rect.position + Vector2i(1, 1), Vector2i(maxi(1, rect.size.x / 2), maxi(1, rect.size.y / 2)))
			for y in range(pool.position.y, pool.end.y):
				for x in range(pool.position.x, pool.end.x):
					g.tissue[g.idx(Vector2i(x, y))] = Grid.T_WATER
		elif k == 4:
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					g.tissue[g.idx(Vector2i(x, y))] = Grid.T_RUIN
		k += 1


## Stable fingerprint of a generated map (determinism tests).
static func map_hash(g) -> int:
	return hash(JSON.stringify(g.to_dict(), "", true))
