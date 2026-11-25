extends Node
## Auto-battle on tiles, every COMBAT_TICK seconds:
## travelers vs your monsters and (if it stands there) the Warden.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func tick() -> void:
	_radiance()
	run.warden.tick_regen(D.COMBAT_TICK)
	var by_tile := {}
	for h in s.heroes:
		if h["gone"] or h["delay"] > 0.0:
			continue
		var t := s.tile_of(h)
		if not by_tile.has(t):
			by_tile[t] = []
		by_tile[t].append(h)

	for key in by_tile.keys():
		if s.game_over:
			return
		var t: int = key
		var units := s.alive_units(t)
		var warden_here := s.warden_at(t)
		if units.is_empty() and not warden_here:
			continue
		var hs: Array = by_tile[t]

		var regen := s.scenery_near(t, "graveyard")
		if regen > 0:
			for u in units:
				if u["undead"]:
					u["hp"] = minf(u["max_hp"], u["hp"] + regen)

		_travelers_strike(hs, units, warden_here)
		if s.game_over:
			return
		for u in units:
			if u["hp"] > 0.0:
				continue
			var burst := 0.0
			if u["name"] == "Skeleton" and s.has_relic("brittle_bones"):
				burst = 4.0
			elif u["undead"] and s.has_relic("sweet_rot"):
				burst = 6.0
			if burst > 0.0:
				for h in hs:
					run.heroes_sys.damage(h, burst)
		units = s.alive_units(t)
		s.tiles[t]["units"] = units
		_monsters_strike(t, hs, units, warden_here)
		if warden_here:
			run.warden.strike(hs.filter(func(x): return not x["gone"]))
		s.tiles[t]["units"] = s.alive_units(t)


func _travelers_strike(hs: Array, units: Array, warden_here: bool) -> void:
	var targets := units.size() + (1 if warden_here else 0)
	for h in hs:
		if h["gone"] or s.game_over:
			continue
		if h["cls"] == "pilgrim":
			_pilgrim_heal(hs)
		var dmg: float = h["dmg"] * (1.3 if h["revenge"] else 1.0)
		var pick := s.rng.randi() % targets
		if pick >= units.size():
			run.warden.take_hit(dmg, h)
			continue
		var target: Dictionary = units[pick]
		if target["undead"] and h["cls"] == "pilgrim":
			dmg *= 2.0
		if target["undead"] and h["trait"] == "zealot":
			dmg *= 1.5
		target["hp"] -= dmg


func _monsters_strike(t: int, hs: Array, units: Array, warden_here: bool) -> void:
	var bonus := 2.0 * s.scenery_near(t, "altar") + 5.0 * s.scenery_near(t, "spire")

	for u in units:
		var alive_h := hs.filter(func(x): return not x["gone"])
		if alive_h.is_empty():
			return
		var target: Dictionary = alive_h[s.rng.randi() % alive_h.size()]
		var dmg: float = u["dmg"] + bonus
		if u["undead"] and s.has_relic("iron_chains"):
			dmg *= 0.8
		if u["undead"] and u["party"] == target["party"]:
			if not s.has_relic("iron_chains") and s.rng.randf() < D.BETRAY_CHANCE:
				u["hp"] = 0.0
				run.heroes_sys.heal(target, 10.0)
				s.add_log("%s remembers %s... and abandons you!" % [u["name"], target["name"]])
				continue
			dmg *= 1.5  # rage of the betrayed
		run.heroes_sys.damage(target, dmg)


## Act I champion: burns undead on her tile and the tiles next to it.
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


func _pilgrim_heal(hs: Array) -> void:
	var lowest = null
	for x in hs:
		if x["gone"]:
			continue
		if lowest == null or x["hp"] / x["max_hp"] < lowest["hp"] / lowest["max_hp"]:
			lowest = x
	if lowest != null:
		run.heroes_sys.heal(lowest, 2.0)
