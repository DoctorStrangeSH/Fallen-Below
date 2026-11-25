extends Node
## Autoplay bot for playtesting without a human.
## Runs whole runs at accelerated simulated time, plays cards, equips loot,
## switches the soul stance and uses the Warden's ability, then prints a report.
##
## Usage (headless):
##   godot --headless res://tests/bot.tscn -- --runs=20 --warden=bone --lure=rumors
## Options: --runs=N  --warden=bone|brood|mimic|saint  --lure=gold|rumors|holy|arcane
##          --sleep=week   (sleep at the first end of a week after day 10 instead of fighting the champion)

const D = preload("res://scripts/data/game_data.gd")
const RunScene = preload("res://scenes/run.tscn")

const STEP := 0.05            # simulated seconds per step
const STEPS_PER_FRAME := 400  # 20 simulated seconds per rendered frame
const MAX_DAYS := 60

var runs_total := 10
var warden_id := "bone"
var lure := "gold"
var sleep_mode := ""
var shot_path := ""
var shot_day := 6
var results: Array = []
var current: Node = null
var rng := RandomNumberGenerator.new()
var act_timer := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"runs":
				runs_total = int(kv[1])
			"warden":
				warden_id = kv[1]
			"lure":
				lure = kv[1]
			"sleep":
				sleep_mode = kv[1]
			"shot":
				shot_path = kv[1]
			"shot_day":
				shot_day = int(kv[1])
			"growth":
				Meta.buildings["pit"] = int(kv[1])
	rng.seed = 12345
	Meta.no_save = true
	# make every Warden and lure available to the bot (does not touch buildings permanently)
	Meta.warden_id = warden_id
	Meta.lure = lure
	Meta.deck = D.START_CARDS.duplicate()
	Meta.loadout = []
	Meta.seen = D.BEATS.keys()  # skip tutorial narration
	print("BOT: %d runs, warden=%s, lure=%s, sleep=%s" % [runs_total, warden_id, lure, sleep_mode])
	_start_run()


func _start_run() -> void:
	current = RunScene.instantiate()
	add_child(current)
	act_timer = 0.0


func _process(_delta: float) -> void:
	if current == null:
		return
	var run = current
	var s = run.state
	if shot_path != "" and s.day >= shot_day:
		_take_shot()
		return
	var steps := 40 if shot_path != "" else STEPS_PER_FRAME
	for i in steps:
		if s.game_over or s.day > MAX_DAYS:
			break
		run._process(STEP)
		act_timer += STEP
		if act_timer >= 0.5:
			act_timer = 0.0
			_think(run)
	if s.game_over or s.day > MAX_DAYS:
		_finish_run(run)


# ---------------------------------------------------------- bot brain

func _think(run) -> void:
	var s = run.state
	if s.game_over:
		return
	s.paused = false
	if not s.level_choices.is_empty():
		run.warden.pick_ability(rng.randi() % s.level_choices.size())
	_play_cards(run)
	_manage_loot(run)
	# raise while there are free servant slots and the Warden is healthy, otherwise devour
	var healthy: bool = s.warden["hp"] > s.warden["max_hp"] * 0.6
	var free_slot: bool = s.undead_count() < s.jar_cap
	# the Hollow Saint lives by her army; the others raise only when they can afford it
	s.raise_souls = free_slot and (healthy or warden_id == "saint")
	if warden_id == "saint" and s.warden["cooldown"] <= 0.0 and s.warden["hp"] < s.warden["max_hp"] * 0.5:
		run.warden.use_active()
	if s.warden["cooldown"] <= 0.0 and not s.travelers_at(s.warden["cur"]).is_empty():
		run.warden.use_active()
	if sleep_mode == "week" and s.day >= 10 and s.day % D.SEAL_EVERY == 0:
		run.sleep()


func _play_cards(run) -> void:
	var s = run.state
	var guard := 0
	while not s.hand.is_empty() and guard < 10:
		guard += 1
		var id: String = s.hand[0]
		var kind: String = D.CARDS[id]["kind"]
		if kind == "instant":
			run.cards.use_card(0)
			continue
		var cell := _best_cell(run, id)
		if cell == Vector2i(-1, -1):
			s.hand.remove_at(0)  # nowhere to put it
			continue
		s.selected = 0
		run.cards.place_selected(cell)


func _best_cell(run, id: String) -> Vector2i:
	var s = run.state
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var kind: String = D.CARDS[id]["kind"]
	if kind == "path":
		for t in s.tiles.size():
			var c: Vector2i = s.cell_of(t)
			if not run.cards.can_place(id, c):
				continue
			var score := rng.randf()
			for nb in s.path_neighbors(t):
				if s.card_at(nb) == id:
					score += 3.0  # build toward combos
			if id == "chest" and t >= s.loop_size:
				score += 4.0  # bait in side passages
			if t < s.loop_size and id != "chest":
				score += 1.0
			if score > best_score:
				best_score = score
				best = c
	else:
		for x in D.GRID_W:
			for y in D.GRID_H:
				var c := Vector2i(x, y)
				if not run.cards.can_place(id, c):
					continue
				var score := rng.randf()
				for nb in s.neighbors(c):
					if s.path_lookup.has(nb) and s.card_at(s.path_lookup[nb]) != "":
						score += 1.0
					if s.scenery.get(nb, "") == id:
						score += 2.0
				if score > best_score:
					best_score = score
					best = c
	return best


func _item_score(item: Dictionary) -> float:
	const W := {"dmg": 3.0, "hp": 0.4, "def": 3.0, "regen": 4.0, "vamp": 0.6, "evade": 0.8, "counter": 0.5}
	var sc := 0.0
	var st: Dictionary = item["stats"]
	for k in st:
		sc += float(st[k]) * float(W.get(k, 0.5))
	return sc


func _manage_loot(run) -> void:
	var s = run.state
	var i := 0
	while i < s.inventory.size():
		var item: Dictionary = s.inventory[i]
		if not run.warden.can_wear(item["slot"]):
			run.loot.discard(i)
			continue
		var idx: int = run.warden.slot_for(item["slot"])
		var gear: Dictionary = s.warden["gear"]
		var worn_score := -1.0
		if gear.has(idx):
			worn_score = _item_score(gear[idx])
		if _item_score(item) > worn_score:
			run.loot.equip(i)
			continue  # the swapped item lands at the end; re-check from the same index
		i += 1
	while s.inventory.size() > 3:
		run.loot.discard(0)


var shot_wait := 0


## Waits a few rendered frames, then saves a screenshot and quits.
func _take_shot() -> void:
	shot_wait += 1
	if shot_wait < 5:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("BOT: screenshot saved to ", shot_path)
	get_tree().quit()


# ---------------------------------------------------------- reporting

func _finish_run(run) -> void:
	var s = run.state
	var outcome := "timeout"
	if s.game_over:
		if s.warden["hp"] <= 0.0:
			outcome = "warden_died"
		elif s.boss_spawned and _boss_dead(s):
			outcome = "victory"
		else:
			outcome = "slept"
	var gear_count: int = s.warden["gear"].size()
	results.append({"outcome": outcome, "day": s.day, "loop": s.loop, "kills": s.kills,
		"boss": s.boss_spawned, "hp": int(s.warden["hp"]), "max_hp": int(s.warden["max_hp"]),
		"dmg": snappedf(s.warden["dmg"], 0.1), "gear": gear_count, "pouch": s.pouch.duplicate(),
		"undead": s.undead_count(), "escapes": s.escapes, "level": s.warden.get("level", 1)})
	var tf := {}
	for k in s.threat_from:
		tf[k] = int(s.threat_from[k])
	print("lv %d " % int(s.warden.get("level", 1)) + str(s.warden.get("abilities", [])))
	print("run %2d: %-12s day %2d loop %2d kills %3d esc %2d boss %-5s warden %d/%d dmg %.1f gear %d undead %d threat %s" % [
		results.size(), outcome, s.day, s.loop, s.kills, s.escapes, str(s.boss_spawned), int(s.warden["hp"]),
		int(s.warden["max_hp"]), s.warden["dmg"], gear_count, s.undead_count(), str(tf)])
	current.queue_free()
	current = null
	if results.size() >= runs_total:
		_report()
		get_tree().quit()
	else:
		_start_run.call_deferred()


func _boss_dead(s) -> bool:
	for h in s.heroes:
		if h["boss"]:
			return false
	return true


func _report() -> void:
	var outcomes := {}
	var days: Array = []
	var boss_days: Array = []
	for r in results:
		outcomes[r["outcome"]] = int(outcomes.get(r["outcome"], 0)) + 1
		days.append(r["day"])
	days.sort()
	print("==== SUMMARY warden=%s lure=%s: %s | day min %d median %d max %d" % [
		warden_id, lure, str(outcomes), days[0], days[days.size() / 2], days[days.size() - 1]])
