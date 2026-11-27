extends SceneTree
## Dumps every player-facing string from game_data.gd to stdout as JSON (for translation).
const D = preload("res://scripts/data/game_data.gd")
const AG = preload("res://scripts/ag/data/defs.gd")
const KEYS := ["name", "desc", "drawback", "organ_desc", "organ_drawback", "title", "style", "passive", "passive_desc", "active", "active_desc",
	"hint", "xp_source", "boss", "boss_title", "dark"]
var out := {}

func _add(s) -> void:
	if s is String and s != "":
		out[s] = true

func _walk(v) -> void:
	if v is Dictionary:
		for k in v:
			if k is String and KEYS.has(k):
				_add(v[k])
			_walk(v[k])
	elif v is Array:
		for x in v:
			_walk(x)

func _init() -> void:
	for c in ["CARDS", "HERO_CLASSES", "LURES", "MONSTERS", "TRAITS", "BUILDINGS", "RELICS", "WARDENS", "ABILITIES",
			"COMBOS", "ACTS", "RESOURCES", "STATS", "RARITIES", "ITEM_TYPES", "AFFIXES"]:
		_walk(D.new().get(c))
	for c in ["STORY", "BOSS_LINES", "FRAGMENTS", "WHISPERS"]:
		var v = D.new().get(c)
		for k in v:
			for line in v[k]:
				_add(line)
	for k in D.BEATS:
		_add(D.BEATS[k])
	for n in D.FIRST_NAMES:
		_add(n)
	_add(D.WARDEN_TRUE_NAME)
	for s in D.GEAR_SLOTS:
		_add(str(s).capitalize())
	for c in ["RESOURCES", "ORGANS", "SPECIES", "TRAITS", "MUTATIONS", "FACTIONS", "ENEMIES", "BOSSES", "BIOMES", "DECISIONS", "BODIES", "ZERO", "DEFECTS"]:
		_walk(AG.new().get(c))
	print("JSONSTART" + JSON.stringify(out.keys()) + "JSONEND")
	quit()
