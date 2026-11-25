extends Node
## Meta progression between runs. Registered as autoload "Meta".
## Holds resources, Lair buildings, relic collection, the chosen loadout and saves.

const D = preload("res://scripts/data/game_data.gd")
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

var res := {"bones": 0, "blood": 0, "gold": 0}
var buildings := {}      # building id -> level
var relics := []         # owned relic ids
var deck := []           # card ids chosen for the next run
var loadout := []        # relic ids equipped for the next run
var lure := "gold"       # last chosen lure
var warden_id := "bone"  # chosen Warden
var runs := 0
var wins := 0
var best_day := 0
var total_kills := 0
var discovered := []     # combo ids
var seen_intro := false
var acts_cleared := []
var fragments := {}      # traveler kind -> pages of the Book of the Fallen unlocked
var seen := []           # one-time story beats and memories already shown

var no_save := false     # set by the test bot so it never touches the real save

# story scene hand-off (not saved)
var pending_story := ""
var story_next := ""


func _ready() -> void:
	load_game()
	_sanitize_loadout()


# ---------------------------------------------------------- resources

func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if int(res.get(k, 0)) < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> void:
	for k in cost:
		res[k] = int(res.get(k, 0)) - int(cost[k])


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), D.RESOURCES[k]["name"]])
	return ", ".join(parts)


# ---------------------------------------------------------- buildings

func level(id: String) -> int:
	return int(buildings.get(id, 0))


func max_level(id: String) -> int:
	var costs: Array = D.BUILDINGS[id]["cost"]
	return costs.size()


## Cost of the next level, or {} if maxed.
func next_cost(id: String) -> Dictionary:
	var lvl := level(id)
	if lvl >= max_level(id):
		return {}
	var costs: Array = D.BUILDINGS[id]["cost"]
	return costs[lvl]


func buy(id: String) -> bool:
	var c := next_cost(id)
	if c.is_empty() or not can_afford(c):
		return false
	pay(c)
	buildings[id] = level(id) + 1
	var unlock: String = D.BUILDINGS[id].get("unlock", "")
	if unlock != "" and deck.size() < deck_slots() and not deck.has(unlock):
		deck.append(unlock)
	save_game()
	return true


# ---------------------------------------------------------- deck & relics

func unlocked_cards() -> Array:
	var out: Array = D.START_CARDS.duplicate()
	for id in D.BUILDINGS:
		var unlock: String = D.BUILDINGS[id].get("unlock", "")
		if unlock != "" and level(id) > 0:
			out.append(unlock)
	return out


func deck_slots() -> int:
	return D.BASE_DECK_SLOTS + level("archive")


func relic_slots() -> int:
	return D.BASE_RELIC_SLOTS + level("reliquary")


func toggle_card(id: String) -> void:
	if deck.has(id):
		if deck.size() > 1:
			deck.erase(id)
	elif deck.size() < deck_slots() and unlocked_cards().has(id):
		deck.append(id)
	save_game()


func toggle_relic(id: String) -> void:
	if loadout.has(id):
		loadout.erase(id)
	elif loadout.size() < relic_slots() and relics.has(id):
		loadout.append(id)
	save_game()


func _sanitize_loadout() -> void:
	var unlocked := unlocked_cards()
	deck = deck.filter(func(c): return unlocked.has(c))
	if deck.is_empty():
		deck = D.START_CARDS.duplicate()
	while deck.size() > deck_slots():
		deck.pop_back()
	loadout = loadout.filter(func(r): return relics.has(r))
	if not available_lures().has(lure):
		lure = "gold"
	if not D.WARDENS.has(warden_id) or not warden_unlocked(warden_id):
		warden_id = "bone"
	while loadout.size() > relic_slots():
		loadout.pop_back()


## Draw weights for the next run, built from the chosen deck.
func card_weights() -> Dictionary:
	var w := {}
	for id in deck:
		w[id] = D.CARD_WEIGHTS.get(id, 1)
	if warden_id == "brood" and w.has("spider"):
		w["spider"] = int(w["spider"]) * 2
	if warden_id == "mimic" and w.has("chest"):
		w["chest"] = int(w["chest"]) * 2
	return w


# ---------------------------------------------------------- run modifiers

# ---------------------------------------------------------- wardens

func warden_def() -> Dictionary:
	return D.WARDENS[warden_id]


func warden_unlocked(id: String) -> bool:
	var def: Dictionary = D.WARDENS[id]
	if def.has("unlock_building"):
		return level(def["unlock_building"]) > 0
	if def.has("unlock_pages"):
		return fragment_count() >= int(def["unlock_pages"])
	return true


func unlock_text(id: String) -> String:
	var def: Dictionary = D.WARDENS[id]
	if def.has("unlock_building"):
		return "Build the %s in the Lair." % D.BUILDINGS[def["unlock_building"]]["name"]
	if def.has("unlock_pages"):
		return "Collect %d pages of the Book of the Fallen." % int(def["unlock_pages"])
	return ""


func set_warden(id: String) -> void:
	if D.WARDENS.has(id) and warden_unlocked(id):
		warden_id = id
		save_game()


func warden_hp() -> float:
	var hp: float = float(warden_def()["hp"]) + 10.0 * level("den")
	if loadout.has("blood_price"):
		hp -= 25.0
	return hp


func warden_dmg() -> float:
	var dmg: float = float(warden_def()["dmg"]) + level("forge")
	if loadout.has("blood_price"):
		dmg += 3.0
	if loadout.has("hollow_echo"):
		dmg += 0.2 * fragment_count()
	return dmg


func start_jars() -> int:
	return 2 + level("jars") + (1 if loadout.has("mass_grave") else 0) + (2 if warden_id == "saint" else 0)


func start_cards() -> int:
	return 4


func available_lures() -> Array:
	var out: Array = []
	for id in D.LURES:
		var b: String = D.LURES[id].get("building", "")
		if b == "" or level(b) > 0:
			out.append(id)
	return out


func set_lure(id: String) -> void:
	if available_lures().has(id):
		lure = id
		save_game()


# ---------------------------------------------------------- flow

func clear_act(act: int) -> void:
	if not acts_cleared.has(act):
		acts_cleared.append(act)
		save_game()


## Shows a story scene, then loads `next_scene`.
func play_story(id: String, next_scene: String) -> void:
	pending_story = id
	story_next = next_scene
	get_tree().change_scene_to_file("res://scenes/story.tscn")


## Goes to the descent preparation (deck + relics); the very first time the intro plays first.
func start_run() -> void:
	if not seen_intro:
		seen_intro = true
		save_game()
		play_story("intro", "res://scenes/prepare.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/prepare.tscn")


# ---------------------------------------------------------- story

## True only the first time `id` is asked for (beats, memories). Saved.
func first_time(id: String) -> bool:
	if seen.has(id):
		return false
	seen.append(id)
	save_game()
	return true


## Next unread page of the Book of the Fallen for this traveler kind, or "" if all read.
func next_fragment(kind: String) -> String:
	var pages: Array = D.FRAGMENTS.get(kind, [])
	var n := int(fragments.get(kind, 0))
	if n >= pages.size():
		return ""
	fragments[kind] = n + 1
	save_game()
	return pages[n]


func fragment_count() -> int:
	var total := 0
	for k in fragments:
		total += int(fragments[k])
	return total


func fragment_total() -> int:
	var total := 0
	for k in D.FRAGMENTS:
		total += D.FRAGMENTS[k].size()
	return total


## A Lair memory that has just become available (not yet seen), or "".
func pending_memory() -> String:
	for m in D.MEMORIES:
		var id: String = m["id"]
		if fragment_count() >= int(m["pages"]) and not seen.has(id):
			return id
	return ""


func warden_name() -> String:
	if warden_id == "bone" and acts_cleared.has(1):
		return D.WARDEN_TRUE_NAME
	return str(warden_def()["name"])


func warden_title() -> String:
	return str(warden_def()["title"])


## Experience and abilities exist only once the Hungering Pit is built.
func growth_unlocked() -> bool:
	return level("pit") > 0


## Marks a combo as discovered. Returns true the first time.
func discover(id: String) -> bool:
	if discovered.has(id):
		return false
	discovered.append(id)
	save_game()
	return true


## A random relic the player does not own yet, excluding `also_skip`. "" if none left.
func random_unowned_relic(rng: RandomNumberGenerator, also_skip: Array) -> String:
	var pool: Array = []
	for id in D.RELICS:
		if not relics.has(id) and not also_skip.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


## Called once when a run ends. `payout` is already scaled by the outcome.
func record_run(days: int, kills: int, payout: Dictionary, new_relics: Array, win: bool) -> void:
	for k in payout:
		res[k] = int(res.get(k, 0)) + int(payout[k])
	for r in new_relics:
		if not relics.has(r):
			relics.append(r)
	runs += 1
	total_kills += kills
	if win:
		wins += 1
	best_day = maxi(best_day, days)
	save_game()


# ---------------------------------------------------------- save / load

func save_game() -> void:
	if no_save:
		return
	var data := {
		"version": SAVE_VERSION, "res": res, "buildings": buildings, "relics": relics,
		"deck": deck, "loadout": loadout, "runs": runs, "wins": wins, "best_day": best_day,
		"total_kills": total_kills, "discovered": discovered, "seen_intro": seen_intro,
		"acts_cleared": acts_cleared, "lure": lure, "warden": warden_id, "fragments": fragments, "seen": seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))


func _str_list(v, valid: Dictionary) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			var id := str(x)
			if valid.has(id) and not out.has(id):
				out.append(id)
	return out


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		push_warning("Save file is corrupt, starting fresh.")
		return
	var d: Dictionary = parsed
	var r = d.get("res", {})
	if r is Dictionary:
		for k in res:
			res[k] = int(r.get(k, 0))
	elif d.has("bones"):  # save v1
		res["bones"] = int(d["bones"])
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	best_day = int(d.get("best_day", 0))
	total_kills = int(d.get("total_kills", 0))
	seen_intro = bool(d.get("seen_intro", false))
	acts_cleared = []
	var ac = d.get("acts_cleared", [])
	if ac is Array:
		for a in ac:
			acts_cleared.append(int(a))
	discovered = _str_list(d.get("discovered", []), D.COMBOS)
	relics = _str_list(d.get("relics", []), D.RELICS)
	loadout = _str_list(d.get("loadout", []), D.RELICS)
	deck = _str_list(d.get("deck", []), D.CARDS)
	lure = str(d.get("lure", "gold"))
	warden_id = str(d.get("warden", "bone"))
	fragments = {}
	var fr = d.get("fragments", {})
	if fr is Dictionary:
		for k in fr:
			if D.FRAGMENTS.has(k):
				fragments[k] = clampi(int(fr[k]), 0, D.FRAGMENTS[k].size())
	seen = []
	var sn = d.get("seen", [])
	if sn is Array:
		for x in sn:
			seen.append(str(x))
	buildings = {}
	var b = d.get("buildings", {})
	if b is Dictionary:
		for k in b:
			if D.BUILDINGS.has(k):
				buildings[k] = mini(int(b[k]), max_level(k))


func reset_save() -> void:
	res = {"bones": 0, "blood": 0, "gold": 0}
	buildings = {}
	relics = []
	deck = []
	loadout = []
	runs = 0
	wins = 0
	best_day = 0
	total_kills = 0
	discovered = []
	seen_intro = false
	acts_cleared = []
	fragments = {}
	seen = []
	_sanitize_loadout()
	save_game()
