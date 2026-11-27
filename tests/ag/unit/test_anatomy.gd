extends "res://tests/ag/unit_case.gd"

const SproutRoot = preload("res://scripts/ag/run/sprout.gd")
const Sprout = preload("res://scripts/ag/run/sprout_state.gd")
const MapGen = preload("res://scripts/ag/systems/map_gen.gd")
const Rng = preload("res://scripts/ag/core/rng_streams.gd")
const Grid = preload("res://scripts/ag/run/grid_state.gd")


func _sprout(seed_value: int = 1):
	var sp = SproutRoot.new()
	sp.start(seed_value)
	return sp


## A free floor cell in the heart room, `dist` cells right of the Heart, or the first free one.
func _free_cell_near_heart(sp, avoid: Array = []) -> Vector2i:
	var g = sp.state.grid
	var r: Rect2i = g.rooms[g.heart_room]
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if g.organ_at(c) < 0 and not g.has_channel(c) and g.tissue_at(c) != Grid.T_WATER and not avoid.has(c):
				var touches := false
				for n in g.neighbors(c):
					if g.organ_at(n) >= 0 or g.has_channel(n):
						touches = true
				if not touches:
					return c
	return Vector2i(-1, -1)


func test_same_seed_same_map() -> void:
	eq(MapGen.map_hash(MapGen.generate(Rng.new(77))), MapGen.map_hash(MapGen.generate(Rng.new(77))), "seed 77")
	check(MapGen.map_hash(MapGen.generate(Rng.new(77))) != MapGen.map_hash(MapGen.generate(Rng.new(78))), "seeds differ")


func test_maps_are_connected_and_sane() -> void:
	for sd in 60:
		var g = MapGen.generate(Rng.new(sd))
		var reach: Dictionary = g.flood_floor(g.room_center(g.heart_room))
		check(g.rooms.size() >= 6, "seed %d: at least 6 rooms (got %d)" % [sd, g.rooms.size()])
		eq(g.entrances.size(), 3, "seed %d: entrances" % sd)
		for i in g.rooms.size():
			check(reach.has(g.room_center(i)), "seed %d: room %d reachable" % [sd, i])
		for e in g.entrances:
			check(reach.has(e), "seed %d: entrance %s reachable" % [sd, e])
		var c := 0
		for v in g.floor:
			c += v
		check(c > 300, "seed %d: enough floor" % sd)


func test_heart_is_placed_and_connected() -> void:
	for sd in 30:
		var sp = _sprout(sd)
		var hu: int = sp.organs.heart_uid()
		check(hu >= 0, "seed %d: heart placed" % sd)
		eq(sp.organs.state_of(hu), "normal", "seed %d: heart normal" % sd)
		sp.free()


func test_cannot_place_on_occupied_rock_water_or_entrance() -> void:
	var sp = _sprout(3)
	var g = sp.state.grid
	var heart_cell: Vector2i = sp.organs.cells_of(sp.organs.heart_uid())[0]
	check(not sp.organs.can_place("organ.sensor", heart_cell)["ok"], "occupied refused")
	eq(sp.organs.place("organ.sensor", heart_cell), -1, "place refused")
	var rock := Vector2i(-1, -1)
	for i in g.floor.size():
		if g.floor[i] == Grid.ROCK:
			rock = Vector2i(i % g.w, i / g.w)
			break
	check(not sp.organs.can_place("organ.sensor", rock)["ok"], "rock refused")
	check(not sp.organs.can_place("organ.sensor", Vector2i(-5, 2))["ok"], "out of bounds refused")
	check(not sp.organs.can_place("organ.sensor", g.entrances[0])["ok"], "entrance refused")
	check(not sp.organs.can_place("organ.heart", _free_cell_near_heart(sp))["ok"], "second heart refused")
	for i in g.tissue.size():
		if g.tissue[i] == Grid.T_WATER and g.floor[i] == Grid.FLOOR:
			check(not sp.organs.can_place("organ.sensor", Vector2i(i % g.w, i / g.w))["ok"], "water refused")
			break
	# a 2-cell organ partly over another organ is refused
	var c := _free_cell_near_heart(sp)
	var uid: int = sp.organs.place("organ.sensor", c)
	check(uid >= 0, "sensor placed")
	check(not sp.organs.can_place("organ.stomach", c - Vector2i(1, 0))["ok"], "overlap of footprint refused")
	sp.free()


func _grid_path(sp, from: Vector2i, to: Vector2i) -> Array:
	# straight floor path for tests (BFS over free floor)
	var g = sp.state.grid
	var prev := {from: from}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for n in g.neighbors(c):
			if not prev.has(n) and (g.walkable(n) or n == to):
				prev[n] = c
				q.append(n)
	var path: Array = []
	var c: Vector2i = to
	while prev.has(c) and c != from:
		path.push_front(c)
		c = prev[c]
	return path


func test_channels_connect_and_cuts_disable() -> void:
	var sp = _sprout(5)
	var g = sp.state.grid
	# grow a sensor in another room, far from the Heart
	var far: Vector2i = g.room_center(1)
	var uid: int = sp.organs.place("organ.sensor", far)
	check(uid >= 0, "far sensor placed")
	eq(sp.organs.state_of(uid), "disabled", "no channel -> disabled")
	var heart_cell: Vector2i = sp.organs.cells_of(sp.organs.heart_uid())[0]
	var path := _grid_path(sp, far, heart_cell)
	check(path.size() > 3, "path exists")
	for c in path:
		if g.organ_at(c) < 0:
			sp.organs.lay_channel(c)
	check(bool(sp.state.organs[uid]["connected"]), "connected through channels")
	eq(sp.organs.state_of(uid), "recovering", "wakes up after reconnection")
	for i in 40:
		sp.step()
	eq(sp.organs.state_of(uid), "normal", "normal after recovery")
	# cut the middle of the channel
	var mid: Vector2i = path[path.size() / 2]
	check(sp.organs.cut_channel(mid), "cut")
	eq(sp.organs.state_of(uid), "disabled", "cut -> disabled")
	sp.organs.lay_channel(mid)
	eq(sp.organs.state_of(uid), "recovering", "re-laid -> recovering")
	sp.free()


func test_organs_relay_and_destruction_cascades() -> void:
	var sp = _sprout(8)
	var g = sp.state.grid
	var hc: Array = sp.organs.cells_of(sp.organs.heart_uid())
	# a regen tissue touching the Heart, then a sensor touching only the regen tissue
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	for c in hc:
		for n in g.neighbors(c):
			if a.x < 0 and sp.organs.can_place("organ.regen_tissue", n)["ok"]:
				for m in g.neighbors(n):
					if not hc.has(m) and m != n and sp.organs.can_place("organ.sensor", m)["ok"]:
						var touches_heart := false
						for k in g.neighbors(m):
							if hc.has(k):
								touches_heart = true
						if not touches_heart:
							a = n
							b = m
							break
	check(a.x >= 0, "found relay spots")
	var ua: int = sp.organs.place("organ.regen_tissue", a)
	var ub: int = sp.organs.place("organ.sensor", b)
	eq(sp.organs.state_of(ua), "normal", "touching heart -> normal")
	eq(sp.organs.state_of(ub), "normal", "relayed through organ -> normal")
	sp.organs.damage(ua, 10000.0)
	check(not sp.state.organs.has(ua), "relay destroyed")
	eq(g.organ_at(a), -1, "cell freed")
	check(g.scar[g.idx(a)] > 0.0, "scar left")
	eq(sp.organs.state_of(ub), "disabled", "loses connection with relay")
	sp.free()


func test_damage_states_and_weakness() -> void:
	var sp = _sprout(9)
	var c := _free_cell_near_heart(sp)
	var hc: Array = sp.organs.cells_of(sp.organs.heart_uid())
	# lay a channel to make it connected
	var uid: int = sp.organs.place("organ.regen_tissue", c)
	var path := _grid_path(sp, c, hc[0])
	for p in path:
		if sp.state.grid.organ_at(p) < 0:
			sp.organs.lay_channel(p)
	for i in 40:
		sp.step()
	eq(sp.organs.state_of(uid), "normal", "normal")
	var dealt: float = sp.organs.damage(uid, 22.0, "fire")   # regen tissue: fire weakness 0.5
	eq(dealt, 33.0, "fire weakness applied")
	eq(sp.organs.state_of(uid), "damaged", "47/80 -> damaged")
	sp.organs.damage(uid, 35.0, "physical")
	eq(sp.organs.state_of(uid), "critical", "12/80 -> critical")
	sp.organs.heal(uid, 100.0)
	eq(sp.organs.state_of(uid), "normal", "healed")
	sp.free()


func test_heart_death_loses_sprout() -> void:
	var sp = _sprout(4)
	sp.organs.damage(sp.organs.heart_uid(), 99999.0, "holy")
	check(sp.state.lost, "sprout lost")
	check(sp.organs.heart_uid() < 0, "heart gone")
	sp.free()


func test_save_round_trip_with_anatomy() -> void:
	var sp = _sprout(12)
	var c := _free_cell_near_heart(sp)
	sp.organs.place("organ.nerve_node", c)
	sp.organs.lay_channel(_free_cell_near_heart(sp))
	for i in 7:
		sp.step()
	var d: Dictionary = JSON.parse_string(JSON.stringify(sp.state.to_dict()))
	var back = Sprout.from_dict(d)
	check(back != null, "loaded")
	eq(back.state_hash(), sp.state.state_hash(), "same state after JSON round-trip")
	var sp2 = SproutRoot.new()
	sp2.resume(back)
	eq(sp2.organs.state_of(sp2.organs.heart_uid()), "normal", "resumed heart works")
	eq(sp2.state.grid.organ_at(c), sp.state.grid.organ_at(c), "organ map restored")
	sp.free()
	sp2.free()


## Stage 03 acceptance: the drawn map and the logical map are the same map.
func test_view_matches_logic() -> void:
	var View = load("res://scripts/ag/ui/anatomy_view.gd")
	var sp = _sprout(21)
	sp.organs.place("organ.stomach", _free_cell_near_heart(sp))
	var v = View.new()
	v.sp = sp
	var g = sp.state.grid
	var bad := 0
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if v.cell_at(v.cell_center(c)) != c:
				bad += 1
			# corners of the drawn cell map back to the same cell
			var tl: Vector2 = v.ORIGIN + Vector2(c) * v.CS + Vector2(0.01, 0.01)
			var br: Vector2 = tl + Vector2(v.CS - 0.02, v.CS - 0.02)
			if v.cell_at(tl) != c or v.cell_at(br) != c:
				bad += 1
	eq(bad, 0, "screen <-> grid mapping")
	for uid in sp.state.organs:
		var r: Rect2 = v.organ_rect(int(uid))
		for c in sp.organs.cells_of(int(uid)):
			check(r.has_point(v.cell_center(c)), "organ %d drawn over its cells" % uid)
			eq(g.organ_at(v.cell_at(v.cell_center(c))), int(uid), "hit-test finds organ %d" % uid)
	v.free()
	sp.free()
