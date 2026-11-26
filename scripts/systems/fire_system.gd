extends Node
## Act III fire. A burning hall hurts everyone on it (travelers, your monsters, the Warden),
## may spread to the halls next to it, and crumbles to ash when the fire burns out.
## The player can quench a fire by clicking it, paying Blood from this run's harvest.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState

var _tick := 0.0


## Halls that can catch fire: anything on the loop except the door and Ash Crypts.
func can_burn(t: int) -> bool:
	return t > 0 and t < s.tiles.size() and not s.fires.has(t) and s.card_at(t) != "ashcrypt"


func ignite(t: int) -> void:
	if not can_burn(t):
		return
	s.fires[t] = {"left": D.FIRE_BURN, "spread": D.FIRE_SPREAD}
	s.fx.emit("ignite", t, 0.0)
	run.beat("first_fire")


func quench(t: int) -> bool:
	if not s.fires.has(t):
		return false
	if int(s.pouch["blood"]) < D.QUENCH_BLOOD:
		s.add_log(Loc.t("Not enough Blood to quench the fire (%d needed).") % D.QUENCH_BLOOD)
		return true
	s.pouch["blood"] = int(s.pouch["blood"]) - D.QUENCH_BLOOD
	s.fires.erase(t)
	s.fx.emit("quench", t, 0.0)
	return true


func tick(delta: float) -> void:
	if s.fires.is_empty():
		return
	_tick += delta
	var burn_step := _tick >= 0.5
	if burn_step:
		_tick = 0.0
	for key in s.fires.keys():
		var t: int = key
		var f: Dictionary = s.fires[t]
		f["left"] -= delta
		if f["spread"] > 0.0:
			f["spread"] -= delta
			if f["spread"] <= 0.0:
				for nb in s.path_neighbors(t):
					if s.card_at(nb) != "" and s.rng.randf() < D.FIRE_SPREAD_CHANCE:
						ignite(nb)
		if burn_step:
			_burn(t, D.FIRE_DPS * 0.5)
		if f["left"] <= 0.0:
			s.fires.erase(t)
			var card := s.card_at(t)
			if card != "":
				s.add_log(Loc.t("Your %s burns to ash.") % Loc.t(D.CARDS[card]["name"]))
				s.tiles[t]["card"] = ""
			s.ash[t] = true
			s.fx.emit("ash", t, 0.0)


func _burn(t: int, dmg: float) -> void:
	for u in s.alive_units(t):
		if not D.MONSTERS.get(u.get("kind", ""), {}).get("fireproof", false):
			u["hp"] -= dmg
	s.tiles[t]["units"] = s.alive_units(t)
	for h in s.travelers_at(t):
		if not h["boss"]:
			run.heroes_sys.damage(h, dmg)
	if s.warden_at(t) and not s.game_over:
		run.warden.take_hit(dmg, {})
