extends Node
## Meta progression between runs. Registered as autoload "Meta".

const D = preload("res://scripts/data/game_data.gd")
const SAVE_PATH := "user://save.json"

var bones := 0
var buildings := {}  # building id -> level
var runs := 0
var wins := 0
var best_day := 0
var total_kills := 0


func _ready() -> void:
	load_game()


# ---------------------------------------------------------- buildings

func level(id: String) -> int:
	return int(buildings.get(id, 0))


func max_level(id: String) -> int:
	var costs: Array = D.BUILDINGS[id]["cost"]
	return costs.size()


## Cost of the next level, or -1 if maxed.
func next_cost(id: String) -> int:
	var lvl := level(id)
	if lvl >= max_level(id):
		return -1
	var costs: Array = D.BUILDINGS[id]["cost"]
	return int(costs[lvl])


func buy(id: String) -> bool:
	var c := next_cost(id)
	if c < 0 or bones < c:
		return false
	bones -= c
	buildings[id] = level(id) + 1
	save_game()
	return true


# ---------------------------------------------------------- run modifiers

func heart_max() -> int:
	return D.HEART_BASE + 5 * level("heart")


func start_jars() -> int:
	return 2 + level("jars")


func start_cards() -> int:
	return 4 + level("crypt")


func start_essence() -> int:
	return 5 * level("well")


func card_weights() -> Dictionary:
	var w: Dictionary = D.CARD_WEIGHTS.duplicate()
	if level("library") < 1:
		w.erase("graveyard")
	return w


## Called when a run ends. Returns bones earned.
func record_run(days: int, kills: int, win: bool) -> int:
	var earned := days * 3 + kills + (25 if win else 0)
	bones += earned
	runs += 1
	total_kills += kills
	if win:
		wins += 1
	best_day = maxi(best_day, days)
	save_game()
	return earned


# ---------------------------------------------------------- save / load

func save_game() -> void:
	var data := {
		"version": 1, "bones": bones, "buildings": buildings, "runs": runs,
		"wins": wins, "best_day": best_day, "total_kills": total_kills,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		push_warning("Save file is corrupt, starting fresh.")
		return
	var d: Dictionary = parsed
	bones = int(d.get("bones", 0))
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	best_day = int(d.get("best_day", 0))
	total_kills = int(d.get("total_kills", 0))
	buildings = {}
	var b = d.get("buildings", {})
	if b is Dictionary:
		for k in b:
			if D.BUILDINGS.has(k):
				buildings[k] = int(b[k])


func reset_save() -> void:
	bones = 0
	buildings = {}
	runs = 0
	wins = 0
	best_day = 0
	total_kills = 0
	save_game()
