extends RefCounted
## The dungeon grid of one sprout (GDD 4, TECH_SPEC 3 "Cell"). Plain layers, one value per cell.
## Logic and drawing both read only this, so the visible map and the logical map cannot drift apart.

const ROCK := 0
const FLOOR := 1

# tissue / surface kind of a floor cell
const T_FLESH := 0
const T_BONE := 1     # Catacombs: old bones, a mineral deposit
const T_WATER := 2    # walkable, organs cannot grow on it
const T_RUIN := 3     # EDEN ruins: tiles and plaques

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var w: int = 0
var h: int = 0
var floor := PackedByteArray()
var tissue := PackedByteArray()
var room := PackedInt32Array()       # room index or -1 (corridor / rock)
var organ := PackedInt32Array()      # organ uid or -1
var channel := PackedByteArray()     # 1 = living channel
var scar := PackedFloat32Array()     # damage left on the cell (destroyed organs, burns)

var rooms: Array = []                # Array of Rect2i
var heart_room: int = -1
var entrances: Array = []            # Array of Vector2i on the map border


func _init(width: int = 0, height: int = 0) -> void:
	resize(width, height)


func resize(width: int, height: int) -> void:
	w = width
	h = height
	var n := w * h
	floor = PackedByteArray(); floor.resize(n); floor.fill(ROCK)
	tissue = PackedByteArray(); tissue.resize(n); tissue.fill(T_FLESH)
	room = PackedInt32Array(); room.resize(n); room.fill(-1)
	organ = PackedInt32Array(); organ.resize(n); organ.fill(-1)
	channel = PackedByteArray(); channel.resize(n); channel.fill(0)
	scar = PackedFloat32Array(); scar.resize(n); scar.fill(0.0)
	rooms = []
	heart_room = -1
	entrances = []


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func is_floor(c: Vector2i) -> bool:
	return in_bounds(c) and floor[idx(c)] == FLOOR


func tissue_at(c: Vector2i) -> int:
	return tissue[idx(c)] if in_bounds(c) else -1


func organ_at(c: Vector2i) -> int:
	return organ[idx(c)] if in_bounds(c) else -1


func has_channel(c: Vector2i) -> bool:
	return in_bounds(c) and channel[idx(c)] == 1


func is_entrance(c: Vector2i) -> bool:
	return entrances.has(c)


## Creatures and invaders walk on floor that no organ occupies.
func walkable(c: Vector2i) -> bool:
	return is_floor(c) and organ[idx(c)] == -1


func neighbors(c: Vector2i) -> Array:
	var out: Array = []
	for d in DIRS:
		var n: Vector2i = c + d
		if in_bounds(n):
			out.append(n)
	return out


## Cells reachable from `start` through floor (ignores organs). Used to verify generation.
func flood_floor(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for n in neighbors(c):
			if not seen.has(n) and is_floor(n):
				seen[n] = true
				queue.append(n)
	return seen


func room_center(i: int) -> Vector2i:
	var r: Rect2i = rooms[i]
	return r.position + r.size / 2


# ------------------------------------------------------------------ save

func to_dict() -> Dictionary:
	var rs: Array = []
	for r in rooms:
		rs.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var es: Array = []
	for e in entrances:
		es.append([e.x, e.y])
	return {
		"w": w, "h": h, "rooms": rs, "heart_room": heart_room, "entrances": es,
		"floor": Marshalls.raw_to_base64(floor), "tissue": Marshalls.raw_to_base64(tissue),
		"room": Marshalls.raw_to_base64(room.to_byte_array()), "organ": Marshalls.raw_to_base64(organ.to_byte_array()),
		"channel": Marshalls.raw_to_base64(channel), "scar": Marshalls.raw_to_base64(scar.to_byte_array()),
	}


static func from_dict(d: Dictionary):
	var g = load("res://scripts/ag/run/grid_state.gd").new(int(d.get("w", 0)), int(d.get("h", 0)))
	var n: int = g.w * g.h
	var f := Marshalls.base64_to_raw(str(d.get("floor", "")))
	var t := Marshalls.base64_to_raw(str(d.get("tissue", "")))
	var r := Marshalls.base64_to_raw(str(d.get("room", ""))).to_int32_array()
	var o := Marshalls.base64_to_raw(str(d.get("organ", ""))).to_int32_array()
	var c := Marshalls.base64_to_raw(str(d.get("channel", "")))
	var s := Marshalls.base64_to_raw(str(d.get("scar", ""))).to_float32_array()
	if f.size() != n or t.size() != n or r.size() != n or o.size() != n or c.size() != n or s.size() != n:
		return null
	g.floor = f; g.tissue = t; g.room = r; g.organ = o; g.channel = c; g.scar = s
	for rr in d.get("rooms", []):
		g.rooms.append(Rect2i(int(rr[0]), int(rr[1]), int(rr[2]), int(rr[3])))
	g.heart_room = int(d.get("heart_room", -1))
	for e in d.get("entrances", []):
		g.entrances.append(Vector2i(int(e[0]), int(e[1])))
	return g
