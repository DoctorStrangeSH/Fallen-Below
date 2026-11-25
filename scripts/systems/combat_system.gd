extends Node
## Auto-battle on tiles: heroes vs dungeon units, every COMBAT_TICK seconds.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func tick() -> void:
	_radiance()
	var by_tile := {}
	for h in s.heroes:
		if h["gone"] or h["delay"] > 0.0:
			continue
		var t := s.tile_of(h)
		if not by_tile.has(t):
			by_tile[t] = []
		by_tile[t].append(h)

	for key in by_tile.keys():
		var t: int = key
		var units := s.alive_units(t)
		if units.is_empty():
			continue
		var hs: Array = by_tile[t]

		var regen := s.scenery_near(t, "graveyard")
		for u in units:
			var r: float = float(regen) if u["undead"] else 0.0
			if _has_affix(u, "regen"):
				r += 2.0
			if r > 0.0:
				u["hp"] = minf(u["max_hp"], u["hp"] + r)

		_heroes_strike(hs, units)
		if s.has_relic("brittle_bones"):
			for u in units:
				if u["hp"] <= 0.0 and u["name"] == "Skeleton":
					for h in hs:
						run.heroes_sys.damage(h, 4.0)
		units = s.alive_units(t)
		s.tiles[t]["units"] = units
		_dungeon_strikes(t, hs, units)
		s.tiles[t]["units"] = s.alive_units(t)


func _heroes_strike(hs: Array, units: Array) -> void:
	for h in hs:
		if h["gone"]:
			continue
		if h["cls"] == "paladin":
			_paladin_heal(hs)
		var target: Dictionary = units[s.rng.randi() % units.size()]
		var dmg: float = h["dmg"] * (1.3 if h["revenge"] else 1.0)
		if target["undead"] and h["cls"] == "paladin":
			dmg *= 2.0
		if target["undead"] and h["trait"] == "zealot":
			dmg *= 1.5
		target["hp"] -= dmg
		if _has_affix(target, "thorns"):
			run.heroes_sys.damage(h, 3.0)


func _dungeon_strikes(t: int, hs: Array, units: Array) -> void:
	var bonus := 2.0 * s.scenery_near(t, "altar") + 5.0 * s.scenery_near(t, "spire")
	for u in units:
		var alive_h := hs.filter(func(x): return not x["gone"])
		if alive_h.is_empty():
			return
		var target: Dictionary = alive_h[s.rng.randi() % alive_h.size()]
		var dmg: float = u["dmg"] + bonus
		var chained := _has_affix(u, "chains") or s.has_relic("iron_chains")
		if u["undead"] and s.has_relic("iron_chains"):
			dmg *= 0.8
		if u["undead"] and u["party"] == target["party"]:
			if not chained and s.rng.randf() < D.BETRAY_CHANCE:
				u["hp"] = 0.0
				run.heroes_sys.heal(target, 10.0)
				s.add_log("%s remembers %s... and abandons you!" % [u["name"], target["name"]])
				continue
			dmg *= 1.5  # rage of the betrayed
		run.heroes_sys.damage(target, dmg)
		if _has_affix(u, "lifesteal"):
			u["hp"] = minf(u["max_hp"], u["hp"] + dmg * 0.25)


## Act I boss: burns undead on her tile and the tiles next to it.
func _radiance() -> void:
	for h in s.heroes:
		if not h["boss"] or h["gone"] or h["delay"] > 0.0:
			continue
		var t: int = h["cur"]
		var area: Array = [t]
		area.append_array(s.path_neighbors(t))
		for a in area:
			for u in s.undead_at(a):
				u["hp"] -= D.RADIANCE_DMG
			s.tiles[a]["units"] = s.alive_units(a)


func _has_affix(u: Dictionary, affix: String) -> bool:
	var list: Array = u.get("affixes", [])
	return list.has(affix)


func _paladin_heal(hs: Array) -> void:
	var lowest = null
	for x in hs:
		if x["gone"]:
			continue
		if lowest == null or x["hp"] / x["max_hp"] < lowest["hp"] / lowest["max_hp"]:
			lowest = x
	if lowest != null:
		run.heroes_sys.heal(lowest, 2.0)
