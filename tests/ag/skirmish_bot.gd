extends Node
## Stage 05 acceptance: N random skirmishes between creatures and invaders.
## godot --headless res://tests/ag/skirmish_bot.tscn -- --skirmishes=1000 [--max_ticks=1800]
## Reports outcomes, stuck units (engaged but not moving and not in place for 20 s) and the slowest tick.

const SproutRoot = preload("res://scripts/ag/run/sprout.gd")

const SPECIES := ["species.bone_crawler", "species.blood_tick", "species.devourer", "species.nerve_stalker", "species.lymphatic"]
const ENEMIES := ["enemy.pilgrim", "enemy.knight", "enemy.burner"]
const ORGANS := ["organ.stomach", "organ.incubator", "organ.nerve_node", "organ.sensor", "organ.regen_tissue"]
const STUCK_LIMIT := 20.0


func _ready() -> void:
	var n := 1000
	var max_ticks := 1800
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skirmishes="):
			n = int(a.substr(13))
		elif a.begins_with("--max_ticks="):
			max_ticks = int(a.substr(12))
	var res := {"abyss": 0, "order": 0, "timeout": 0}
	var stuck: Array = []
	var slowest := 0
	var total_ticks := 0
	var t0 := Time.get_ticks_msec()
	var counters := {}
	var first := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			first = int(a.substr(7))
	for i in range(first, first + n):
		var sp = SproutRoot.new()
		add_child(sp)
		sp.start(10000 + i)
		var r := RandomNumberGenerator.new()
		r.seed = 777 + i
		sp.economy.apply("resource.biomass", 300.0, "Test")
		sp.economy.apply("resource.genome", 100.0, "Test")
		_setup(sp, r)
		var still := {}
		var outcome := "timeout"
		for t in max_ticks:
			var a := Time.get_ticks_usec()
			sp.step()
			slowest = maxi(slowest, Time.get_ticks_usec() - a)
			total_ticks += 1
			_check_stuck(sp, still, stuck, i)
			if sp.state.lost:
				outcome = "order"
				break
			if sp.creatures.team_units("order").is_empty():
				outcome = "abyss"
				break
		res[outcome] += 1
		if outcome == "timeout" and OS.get_cmdline_user_args().has("--why"):
			for uid in sp.state.units:
				var u: Dictionary = sp.state.units[uid]
				if str(u["team"]) == "order":
					print("  T%d %s %s target=%s/%s cell=%s hp=%d" % [i, u["def"], u["state"], u["target"], u["target_kind"], sp.creatures.cell_of(u), int(u["hp"])])
					var tc: Array = sp.organs.cells_of(int(u["target"]))
					var stand: Array = sp.creatures.paths.stand_cells(tc)
					print("     organ cells %s stand %s path_any %s" % [tc, stand, sp.creatures.paths.path_to_any(sp.creatures.cell_of(u), stand)])
					print("     cell floor=%s organ=%s solid=%s" % [sp.state.grid.is_floor(sp.creatures.cell_of(u)), sp.state.grid.organ_at(sp.creatures.cell_of(u)), sp.creatures.paths.walk.is_point_solid(sp.creatures.cell_of(u))])
					print("     breach %s pos %s path %s" % [sp.creatures.paths.breach_path(sp.creatures.cell_of(u), tc[0]), u["pos"], u["path"]])
		for k in sp.state.stats:
			counters[k] = int(counters.get(k, 0)) + int(sp.state.stats[k])
		sp.queue_free()
		await get_tree().process_frame
	var ms := Time.get_ticks_msec() - t0
	print("SKIRMISHES: %d  abyss %d  order %d  timeout %d" % [n, res["abyss"], res["order"], res["timeout"]])
	print("STUCK: %d %s" % [stuck.size(), str(stuck.slice(0, 5))])
	print("COUNTERS: %s" % str(counters))
	print("TIME: %d ms total, %d sim ticks, slowest tick %.2f ms" % [ms, total_ticks, slowest / 1000.0])
	get_tree().quit(1 if not stuck.is_empty() else 0)


func _setup(sp, r: RandomNumberGenerator) -> void:
	var g = sp.state.grid
	for k in r.randi_range(0, 3):
		var id: String = ORGANS[r.randi_range(0, ORGANS.size() - 1)]
		for tries in 200:
			var c := Vector2i(r.randi_range(1, g.w - 2), r.randi_range(1, g.h - 2))
			if sp.organs.place(id, c) >= 0:
				for p in sp.organs.channel_route(c):
					sp.organs.lay_channel(p)
				break
	var stand: Array = sp.creatures.paths.stand_cells(sp.organs.cells_of(sp.organs.heart_uid()))
	for k in r.randi_range(1, 6):
		var cell: Vector2i = stand[r.randi_range(0, stand.size() - 1)] if r.randf() < 0.6 else _random_floor(sp, r)
		sp.creatures.spawn_creature(SPECIES[r.randi_range(0, SPECIES.size() - 1)], cell)
	if r.randf() < 0.4:
		sp.creatures.embody_zero()
	for k in r.randi_range(1, 5):
		sp.creatures.spawn_enemy(ENEMIES[r.randi_range(0, ENEMIES.size() - 1)], g.entrances[r.randi_range(0, g.entrances.size() - 1)])


func _random_floor(sp, r: RandomNumberGenerator) -> Vector2i:
	var g = sp.state.grid
	for tries in 500:
		var c := Vector2i(r.randi_range(0, g.w - 1), r.randi_range(0, g.h - 1))
		if g.walkable(c):
			return c
	return g.entrances[0]


## A unit is stuck when it keeps a target it can neither reach nor act on for STUCK_LIMIT seconds.
func _check_stuck(sp, still: Dictionary, stuck: Array, skirmish: int) -> void:
	for uid in sp.state.units:
		var u: Dictionary = sp.state.units[uid]
		var c: Vector2i = sp.creatures.cell_of(u)
		var busy: bool = ["engage", "protect", "heal", "retreat", "return"].has(str(u["state"])) and not sp.creatures._in_place(u)
		var key: int = int(uid)
		if not busy:
			still.erase(key)
			continue
		var e: Array = still.get(key, [c, 0.0])
		if e[0] != c:
			e = [c, 0.0]
		e[1] = float(e[1]) + 0.1
		still[key] = e
		if OS.get_cmdline_user_args().has("--why") and float(e[1]) > 19.0:
			print("  trace pos=%s state=%s path=%s path_t=%.2f speed=%s cd=%.2f aggro=%s/%.1f hp=%.1f" % [u["pos"], u["state"], u["path"], float(u["path_t"]), u["speed"], float(u["cd"]), u["aggro"], float(u["aggro_t"]), float(u["hp"])])
		if float(e[1]) >= STUCK_LIMIT:
			if OS.get_cmdline_user_args().has("--why"):
				var h: Vector2i = sp.creatures.home_of(u)
				print("STUCK DETAIL pos=%s home=%s home_walk=%s path=%s plan=%s solid_here=%s" % [u["pos"], h, sp.state.grid.walkable(h), u["path"], sp.creatures.paths.path(c, h), sp.creatures.paths.walk.is_point_solid(c)])
			stuck.append({"skirmish": skirmish, "unit": str(u["def"]), "state": str(u["state"]), "cell": c, "target": u["target"], "kind": u["target_kind"]})
			still.erase(key)
