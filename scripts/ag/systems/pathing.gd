extends RefCounted
## Grid path finding for creatures and invaders (TECH_SPEC AG-05). Two AStarGrid2D layers:
## - walk:   rock and organs are solid; the normal way through the halls;
## - breach: organs are passable but expensive; invaders use it when organs wall them off,
##           and attack the first organ on that route instead of standing still.
## Rebuilt lazily whenever SproutState.grid_version changes.

const Grid = preload("res://scripts/ag/run/grid_state.gd")

const BREACH_WEIGHT := 12.0

var walk := AStarGrid2D.new()
var breach := AStarGrid2D.new()
var version := -1
var s


func setup(state) -> void:
	s = state
	version = -1


func _prep(a: AStarGrid2D, g) -> void:
	a.region = Rect2i(0, 0, g.w, g.h)
	a.cell_size = Vector2.ONE
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	a.update()
	# update() keeps old solid/weight data when the region did not change: reset it explicitly,
	# otherwise cells of destroyed organs stay walls forever
	a.fill_solid_region(a.region, false)
	a.fill_weight_scale_region(a.region, 1.0)


func ensure() -> void:
	if version == s.grid_version:
		return
	var g = s.grid
	_prep(walk, g)
	_prep(breach, g)
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not g.is_floor(c):
				walk.set_point_solid(c, true)
				breach.set_point_solid(c, true)
			elif g.organ_at(c) >= 0:
				walk.set_point_solid(c, true)
				breach.set_point_weight_scale(c, BREACH_WEIGHT)
	version = s.grid_version


## Cells from `from` (excluded) to `to` (included) over walkable floor; [] if none or already there.
func path(from: Vector2i, to: Vector2i) -> Array:
	ensure()
	if from == to or not walk.is_in_boundsv(to) or walk.is_point_solid(to):
		return []
	var start := from
	if walk.is_point_solid(start):
		return []
	var p: Array = walk.get_id_path(start, to)
	if p.size() > 0:
		p.remove_at(0)
	return p


## Path to whichever of `goals` is reachable and closest along the way; tries the nearest few.
func path_to_any(from: Vector2i, goals: Array, tries: int = 6) -> Array:
	var sorted := goals.duplicate()
	sorted.sort_custom(func(a, b):
		var da: int = absi(a.x - from.x) + absi(a.y - from.y)
		var db: int = absi(b.x - from.x) + absi(b.y - from.y)
		return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	var best: Array = []
	var n := 0
	for gcell in sorted:
		if gcell == from:
			return []
		if n >= tries:
			break
		var p := path(from, gcell)
		if p.size() > 0:
			n += 1
			if best.is_empty() or p.size() < best.size():
				best = p
	return best


## Route through organs: [] when even this fails. Used to find which organ to tear through.
func breach_path(from: Vector2i, to: Vector2i) -> Array:
	ensure()
	if from == to or not breach.is_in_boundsv(to) or breach.is_point_solid(to) or breach.is_point_solid(from):
		return []
	var p: Array = breach.get_id_path(from, to)
	if p.size() > 0:
		p.remove_at(0)
	return p


## Free floor cells next to any cell of `cells` (where a unit can stand to hit them).
func stand_cells(cells: Array) -> Array:
	var g = s.grid
	var out: Array = []
	for c in cells:
		for n in g.neighbors(c):
			if g.walkable(n) and not out.has(n):
				out.append(n)
	return out
