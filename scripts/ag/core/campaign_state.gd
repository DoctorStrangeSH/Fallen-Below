extends RefCounted
## Campaign data that survives sprouts (TECH_SPEC NARR-01, 5). Separate from Fallen Below's Meta.

const Reg = preload("res://scripts/ag/core/registry.gd")

const SCHEMA := 3

# --- Memory Archive (GDD 12)
var unlocked := []          # ids of species / organs / mutations / biomes opened for future sprouts
var recipes := {}           # recipe id -> result id (breeding results already discovered)
var memories := {}          # memory id -> {"version": int, "chosen": String}

# --- StoryState (NARR-01)
var act: int = 0            # 0 = prologue ... 5
var rooted := []            # rooted biome ids
var decisions := {}         # "Z1" -> "let_speak" (key without the "decision." prefix, as in narrative_check.py)
var flags := {}
var deeds := {}             # character id -> [{"deed": id, "act": int, "sprout": int}] (NARR-05)
var names_found := []       # the Twelve
var notes_found: int = 0    # seven notes of the lullaby
var endings_seen := []
var canon_ending: String = ""
var echo_depth_max: int = 0

# --- tendencies (Narrative Bible 14, rule 3)
var minds_digested: int = 0
var minds_archived: int = 0
var minds_to_zero: int = 0

# --- stats
var sprouts: int = 0
var sprouts_rooted: int = 0
var veteran := false        # had a Fallen Below save (migration v2 -> v3)


## Writes a decision once. Returns false if it was already made or the option is unknown.
func decide(decision_key: String, option: String) -> bool:
	if decisions.has(decision_key):
		return false
	var def := Reg.get_def("decision." + decision_key)
	if not def.is_empty() and not (def.get("options", []) as Array).has(option):
		return false
	decisions[decision_key] = option
	return true


func add_deed(character_id: String, deed_id: String) -> void:
	if not deeds.has(character_id):
		deeds[character_id] = []
	(deeds[character_id] as Array).append({"deed": deed_id, "act": act, "sprout": sprouts})


func last_deeds(character_id: String, n: int = 3) -> Array:
	var all: Array = deeds.get(character_id, [])
	return all.slice(maxi(0, all.size() - n))


func unlock(id: String) -> void:
	if not unlocked.has(id):
		unlocked.append(id)


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA, "unlocked": unlocked, "recipes": recipes, "memories": memories,
		"act": act, "rooted": rooted, "decisions": decisions, "flags": flags, "deeds": deeds,
		"names_found": names_found, "notes_found": notes_found, "endings_seen": endings_seen,
		"canon_ending": canon_ending, "echo_depth_max": echo_depth_max,
		"minds": {"digested": minds_digested, "archived": minds_archived, "zero": minds_to_zero},
		"sprouts": sprouts, "sprouts_rooted": sprouts_rooted, "veteran": veteran,
	}


static func from_dict(d: Dictionary):
	var c = load("res://scripts/ag/core/campaign_state.gd").new()
	c.unlocked = _ids(d.get("unlocked", []))
	c.recipes = _dict(d.get("recipes", {}))
	c.memories = _dict(d.get("memories", {}))
	c.act = clampi(int(d.get("act", 0)), 0, 5)
	c.rooted = _ids(d.get("rooted", []))
	c.decisions = _dict(d.get("decisions", {}))
	c.flags = _dict(d.get("flags", {}))
	c.deeds = _dict(d.get("deeds", {}))
	c.names_found = _strings(d.get("names_found", []))
	c.notes_found = clampi(int(d.get("notes_found", 0)), 0, 7)
	c.endings_seen = _strings(d.get("endings_seen", []))
	c.canon_ending = str(d.get("canon_ending", ""))
	c.echo_depth_max = clampi(int(d.get("echo_depth_max", 0)), 0, 10)
	var m = d.get("minds", {})
	if m is Dictionary:
		c.minds_digested = int(m.get("digested", 0))
		c.minds_archived = int(m.get("archived", 0))
		c.minds_to_zero = int(m.get("zero", 0))
	c.sprouts = int(d.get("sprouts", 0))
	c.sprouts_rooted = int(d.get("sprouts_rooted", 0))
	c.veteran = bool(d.get("veteran", false))
	return c


## Known ids only (renamed ids are resolved, removed ones are dropped).
static func _ids(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			var id := Reg.resolve(str(x))
			if Reg.has(id) and not out.has(id):
				out.append(id)
	return out


static func _strings(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			if not out.has(str(x)):
				out.append(str(x))
	return out


static func _dict(v) -> Dictionary:
	return v if v is Dictionary else {}
