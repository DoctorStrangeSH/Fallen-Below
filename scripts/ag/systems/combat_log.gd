extends RefCounted
## Turns a combat_log entry into a sentence (GDD 9: "the log explains every death").
## Returns [English Loc key, args]; the UI translates the key and every String arg.

const Reg = preload("res://scripts/ag/core/registry.gd")

const CAUSES := {
	"first strike": "a strike from the shadows", "execute": "finishing a wounded foe", "predator": "a predator's instinct",
	"Bone Storm": "Bone Storm", "acid blood": "acid blood", "infection": "infection", "starvation": "hunger",
}


static func name_of(id: String) -> String:
	return str(Reg.get_def(id).get("name", id)) if id != "" else ""


## Splits "fire resisted, execute" into readable causes.
static func causes(entry: Dictionary) -> Array:
	var out: Array = []
	for part in str(entry.get("reason", "")).split(",", false):
		var p := part.strip_edges()
		if CAUSES.has(p):
			out.append(CAUSES[p])
		elif p.ends_with(" weakness"):
			out.append("weak to " + p.trim_suffix(" weakness"))
		elif p.ends_with(" resisted"):
			out.append(p.trim_suffix(" resisted") + " partly resisted")
	var k := str(entry.get("kind", ""))
	if out.is_empty() and k != "" and k != "physical":
		out.append(k)
	return out


static func describe(entry: Dictionary) -> Array:
	var victim := name_of(str(entry["victim"]))
	var by := name_of(str(entry.get("by", "")))
	var why: Array = causes(entry)
	if str(entry.get("reason", "")) == "starvation":
		return ["%s starved: the Heart could not feed it.", [victim]]
	if by == "":
		return ["%s died of %s.", [victim, why[0] if not why.is_empty() else "wounds"]]
	if str(entry["team"]) == "organ":
		return ["%s destroyed your %s (%s).", [by, victim, ", ".join(why) if not why.is_empty() else "physical"]] if not why.is_empty() \
			else ["%s destroyed your %s.", [by, victim]]
	if why.is_empty():
		return ["%s killed %s.", [by, victim]]
	return ["%s killed %s: %s.", [by, victim, ", ".join(why)]]
