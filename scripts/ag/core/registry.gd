extends RefCounted
## Definition registry (TECH_SPEC 2.4). Read-only access to scripts/ag/data/defs.gd by permanent id.
## Usage: const Reg = preload("res://scripts/ag/core/registry.gd"); Reg.get_def("organ.stomach")

const Defs = preload("res://scripts/ag/data/defs.gd")

const TABLES := {
	"resource": "RESOURCES", "organ": "ORGANS", "species": "SPECIES", "trait": "TRAITS",
	"mutation": "MUTATIONS", "faction": "FACTIONS", "enemy": "ENEMIES", "boss": "BOSSES",
	"biome": "BIOMES", "decision": "DECISIONS", "body": "BODIES", "defect": "DEFECTS", "command": "COMMANDS",
}

static var _cache := {}


static func table(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var t: Dictionary = {}
	if TABLES.has(kind):
		var v = Defs.new().get(TABLES[kind])
		if v is Dictionary:
			t = (v as Dictionary).duplicate()
		if kind == "species":
			t.merge(Defs.ZERO)   # Zero is a species too, but never bred
	_cache[kind] = t
	return t


static func kind_of(id: String) -> String:
	var dot := id.find(".")
	return id.substr(0, dot) if dot > 0 else ""


static func resolve(id: String) -> String:
	var seen := 0
	while Defs.RENAMED.has(id) and seen < 16:
		id = str(Defs.RENAMED[id])
		seen += 1
	return id


static func has(id: String) -> bool:
	id = resolve(id)
	return table(kind_of(id)).has(id)


static func get_def(id: String) -> Dictionary:
	id = resolve(id)
	var t := table(kind_of(id))
	if t.has(id):
		return t[id]
	return {}


static func ids(kind: String) -> Array:
	var out: Array = table(kind).keys()
	out.sort()
	return out


## Returns a list of human-readable problems; empty means the data is consistent.
static func validate() -> Array:
	var errors: Array = []
	for kind in TABLES:
		for id in table(kind):
			var sid := str(id)
			if kind_of(sid) != kind:
				errors.append("%s: id prefix does not match table '%s'" % [sid, kind])
			var d: Dictionary = table(kind)[id]
			if str(d.get("name", "")) == "":
				errors.append("%s: empty name" % sid)
			_check_refs(sid, d, errors)
	for combo in Defs.GENETICS["combos"]:
		for m in combo["all"]:
			if not has(str(m)):
				errors.append("combo refers to unknown %s" % m)
		if not has(str(combo["result"])):
			errors.append("combo result unknown %s" % combo["result"])
	for kind in Defs.GENETICS["threat_answers"]:
		for m in Defs.GENETICS["threat_answers"][kind]:
			if not has(str(m)):
				errors.append("threat answer unknown %s" % m)
	for old in Defs.RENAMED:
		if has(str(old)):
			errors.append("%s: renamed id still defined" % old)
		if not has(str(Defs.RENAMED[old])):
			errors.append("%s: renamed to unknown id %s" % [old, Defs.RENAMED[old]])
	return errors


static func _check_refs(id: String, d: Dictionary, errors: Array) -> void:
	for key in ["cost", "upkeep", "produces", "storage", "yield"]:
		var c = d.get(key, {})
		if c is Dictionary:
			for r in c:
				if str(r) != "impulse" and not has(str(r)):
					errors.append("%s: %s refers to unknown resource %s" % [id, key, r])
	for key in ["embody_cost"]:
		var ec = d.get(key, {})
		if ec is Dictionary:
			for r in ec:
				if not has(str(r)):
					errors.append("%s: %s refers to unknown resource %s" % [id, key, r])
	var br = d.get("breed", {})
	if br is Dictionary and br.get("cost", {}) is Dictionary:
		for r in br.get("cost", {}):
			if not has(str(r)):
				errors.append("%s: breed cost refers to unknown resource %s" % [id, r])
	for key in ["traits", "requires", "excludes", "factions"]:
		var l = d.get(key, [])
		if l is Array:
			for x in l:
				if not has(str(x)):
					errors.append("%s: %s refers to unknown id %s" % [id, key, x])
	for key in ["faction", "biome", "boss_id", "decision", "body"]:
		if d.has(key) and not has(str(d[key])):
			errors.append("%s: %s refers to unknown id %s" % [id, key, d[key]])
	if d.has("footprint"):
		var fp = d["footprint"]
		if not fp is Array or (fp as Array).is_empty() or not (fp as Array).has(Vector2i.ZERO):
			errors.append("%s: footprint must contain Vector2i(0, 0)" % id)
	if kind_of(id) == "mutation":
		if str(d.get("drawback", "")) == "" or (d.get("cost", {}) as Dictionary).is_empty():
			errors.append("%s: mutation needs a drawback and a cost" % id)
		if (d.get("targets", []) as Array).has("organ") and (not d.has("organ_effect") or str(d.get("organ_drawback", "")) == ""):
			errors.append("%s: organ mutation needs organ_effect and organ_drawback" % id)
		if not ["dominant", "recessive"].has(str(d.get("inherit", ""))):
			errors.append("%s: inherit must be dominant or recessive" % id)
	if kind_of(id) == "boss":
		var phases = d.get("phases", [])
		if not phases is Array or (phases as Array).is_empty():
			errors.append("%s: boss has no phases" % id)
