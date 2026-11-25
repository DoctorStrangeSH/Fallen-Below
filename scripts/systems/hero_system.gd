extends Node
## Travelers lured into the dungeon: spawning, movement, fork decisions (bait AI),
## traits, damage, death, harvest and escape.
## (Called "heroes" internally; in the game they are travelers.)

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var run  # run.gd
var s: RunState


func make_hero(cls: String, hero_name: String, mult: float, party: int, idx: int) -> Dictionary:
	var base: Dictionary = D.HERO_CLASSES[cls]
	var hp: float = round(base["hp"] * mult)
	var h := {
		"id": s.next_hero_id, "name": hero_name, "cls": cls, "title": "",
		"hp": hp, "max_hp": hp, "dmg": base["dmg"] * mult,
		"speed": base["speed"], "color": base["color"],
		"party": party, "cur": 0, "nxt": 0, "prog": 0.0, "delay": idx * 0.8, "stun": 0.0,
		"laps": 0, "revenge": false, "boss": false, "gone": false, "death_tile": 0,
		"trait": "", "baited": false, "half_said": false, "poison": 0,
		"armor": float(base.get("armor", 0.0)), "disarms": bool(base.get("disarms", false)),
	}
	if s.rng.randf() < D.TRAIT_CHANCE:
		set_trait(h, D.TRAITS.keys()[s.rng.randi() % D.TRAITS.size()])
	h["nxt"] = choose_next(h, 0)
	s.next_hero_id += 1
	s.heroes.append(h)
	return h


func set_trait(h: Dictionary, trait_id: String) -> void:
	h["trait"] = trait_id
	if trait_id == "greedy":
		h["speed"] *= 1.2
	elif trait_id == "veteran":
		h["max_hp"] = round(h["max_hp"] * 1.3)
		h["hp"] = h["max_hp"]


static func party_size(day: int) -> int:
	return clampi(1 + day / 3, 1, 4)


## Most of each party answers your lure; the rest are random wanderers.
func spawn_party() -> void:
	var pid := s.next_party_id
	s.next_party_id += 1
	var size := party_size(s.day)
	var mult: float = (1.0 + D.LOOP_POWER * (s.loop - 1)) * float(s.act_def()["power"])
	var wanderers: Array = D.HERO_CLASSES.keys().filter(func(c): return int(D.HERO_CLASSES[c].get("act", 1)) <= s.act)
	var lured: String = D.LURES[s.lure]["traveler"]
	var names: Array = []
	for i in size:
		var cls := lured
		var share := D.LURE_SHARE_LANTERN if s.has_relic("lantern_of_lies") else D.LURE_SHARE
		if s.rng.randf() >= share:
			cls = wanderers[s.rng.randi() % wanderers.size()]
		var hero_name: String = Loc.t(D.FIRST_NAMES[s.rng.randi() % D.FIRST_NAMES.size()])
		make_hero(cls, hero_name, mult, pid, i)
		names.append(Loc.t(D.HERO_CLASSES[cls]["name"]))
	s.add_log(Loc.t("Day %d (loop %d): lured below: %s.") % [s.day, s.loop, ", ".join(names)])


func spawn_boss() -> void:
	s.boss_spawned = true
	var act: Dictionary = D.ACTS[s.act]
	var h := make_hero(act["boss_cls"], Loc.t(act["boss"]), 1.0, s.next_party_id, 0)
	s.next_party_id += 1
	h["trait"] = ""
	h["boss"] = true
	h["title"] = Loc.t(act["boss_title"])
	var bm: float = act["boss_mult"]
	h["hp"] = (D.BOSS_HP + s.loop * D.BOSS_HP_PER_LOOP) * bm
	h["max_hp"] = h["hp"]
	h["dmg"] = (D.BOSS_DMG + s.loop * D.BOSS_DMG_PER_LOOP) * bm
	h["disarms"] = false
	h["speed"] = 1.3
	h["color"] = Color(1, 1, 1)
	for line in boss_lines()["arrive"]:
		s.narrate.emit(Loc.t(line))
	if s.act == 1:
		s.add_log(Loc.t("%s descends. Her radiance burns undead nearby: meet her with the Warden and the living.") % s.hero_name(h))
	else:
		s.add_log(Loc.t("%s descends. He plants charges on your halls: watch for the red marks and rebuild.") % s.hero_name(h))
	s.combo_found.emit(Loc.t("%s DESCENDS") % s.hero_name(h).to_upper())
	s.fx.emit("boss", h, 0.0)


# ---------------------------------------------------------- movement

func _blocked(t: int) -> bool:
	return not s.alive_units(t).is_empty() or s.warden_at(t)


func move(delta: float) -> void:
	for h in s.heroes.duplicate():
		if h["gone"]:
			continue
		if h["delay"] > 0.0:
			h["delay"] -= delta
			continue
		if h["stun"] > 0.0:
			h["stun"] -= delta
			continue
		if _blocked(h["cur"]):
			continue  # fighting
		var speed: float = h["speed"]
		if run.warden.has("silk_snare") and s.count_units(h["cur"], "Spider") > 0:
			speed *= 0.65
		h["prog"] += speed * delta
		while h["prog"] >= 1.0 and not h["gone"] and not s.game_over:
			h["prog"] -= 1.0
			var t: int = h["nxt"]
			h["cur"] = t
			if t == 0:
				_on_lap(h)
				if h["gone"] or s.game_over:
					break
			_on_enter_tile(h, t)
			if h["gone"]:
				break
			h["nxt"] = choose_next(h, t)
			if h["stun"] > 0.0 or _blocked(t):
				h["prog"] = 0.0  # stop on this tile
				break


## Picks the next tile. At forks each traveler scores both branches by personality.
func choose_next(h: Dictionary, t: int) -> int:
	var opts: Array = s.tiles[t]["next"]
	if opts.size() == 1 or not s.forks.has(t):
		return opts[0]
	var fork: Dictionary = s.forks[t]
	var best: int = opts[0]
	var best_score := -INF
	for o in opts:
		var seg: Array = fork[o]
		var sc := _score_segment(h, seg) + s.rng.randf() * 1.5
		if sc > best_score:
			best_score = sc
			best = o
	if best != opts[0] and not h["boss"]:
		var reason := _lure_reason(h, fork[best])
		if reason != "":
			s.add_log(Loc.t("%s %s") % [s.hero_name(h), reason])
	return best


func _is_greedy(h: Dictionary) -> bool:
	return h["trait"] == "greedy" or h["cls"] == "seeker"


func _is_holy(h: Dictionary) -> bool:
	return h["trait"] == "zealot" or h["cls"] == "pilgrim"


func _score_segment(h: Dictionary, seg: Array) -> float:
	var greedy := _is_greedy(h)
	var holy := _is_holy(h)
	var coward: bool = h["trait"] == "coward"
	var sc := 0.0
	for id in seg:
		var card := s.card_at(id)
		if D.BAIT_CARDS.has(card):
			sc += 8.0 if greedy else 1.5
		if D.TRAP_DMG.has(card) and card != "chest":
			sc -= 3.0 if coward else 1.0
		var units := s.alive_units(id)
		var undead := 0
		for u in units:
			if u["undead"]:
				undead += 1
		sc -= (2.0 if coward else 0.3) * units.size()
		if holy:
			sc += 3.0 * undead
			sc += 4.0 * (s.scenery_near(id, "altar") + s.scenery_near(id, "spire"))
	return sc


func _lure_reason(h: Dictionary, seg: Array) -> String:
	for id in seg:
		var card := s.card_at(id)
		if D.BAIT_CARDS.has(card) and _is_greedy(h):
			return Loc.t("can't resist the chest...")
		if _is_holy(h) and (s.scenery_near(id, "altar") + s.scenery_near(id, "spire") > 0 or not s.undead_at(id).is_empty()):
			return Loc.t("goes to purge the darkness.")
	return ""


## Each lap brings a traveler closer to the way out.
func _on_lap(h: Dictionary) -> void:
	if h["boss"]:
		return  # the champion hunts the Warden, she does not leave
	h["laps"] += 1
	if h["laps"] >= escape_laps():
		escape(h, Loc.t("found the way out"))
	else:
		s.add_log(Loc.t("%s is getting closer to the exit (%d/%d).") % [s.hero_name(h), h["laps"], escape_laps()])


func escape_laps() -> int:
	return D.ESCAPE_LAPS + (1 if s.has_relic("patient_hunger") else 0)


func escape(h: Dictionary, how: String) -> void:
	remove(h)
	s.fx.emit("escape", h, 0.0)
	var t := D.THREAT_PER_ESCAPE * (0.5 if s.has_relic("whispering_skull") else 1.0)
	s.add_threat(t, "escapes")
	s.escapes += 1
	s.add_log(Loc.t("%s %s and will tell the Order!") % [s.hero_name(h), how])
	run.beat("first_escape")
	run.beat("tut_escape")


func _on_enter_tile(h: Dictionary, t: int) -> void:
	var card := s.card_at(t)
	if not D.TRAP_DMG.has(card):
		return
	if h["disarms"] and s.rng.randf() < D.SAPPER_DISARM_CHANCE:
		s.tiles[t]["card"] = ""
		s.add_log(Loc.t("%s disarms your %s!") % [s.hero_name(h), Loc.t(D.CARDS[card]["name"])])
		s.fx.emit("disarm", t, 0.0)
		return
	var dmg: float = D.TRAP_DMG[card] * Meta.trap_mult()
	if (card == "spikes" or card == "grinder") and s.has_relic("thorned_halls"):
		dmg += 3.0
	if card == "spikes":
		for nb in s.path_neighbors(t):
			var c := s.card_at(nb)
			if c == "spikes" or c == "grinder":
				dmg += 2.0
	elif card == "chest":
		h["stun"] = D.CHEST_STUN
		h["baited"] = true
	elif card == "cavein":
		h["stun"] = D.CAVEIN_STUN
		s.tiles[t]["card"] = ""  # the tunnel is spent
		s.fx.emit("blast", t, 0.0)
	if (card == "chest") and run.warden.has("golden_bait"):
		dmg *= 2.0
	damage(h, dmg)


# ---------------------------------------------------------- health

func damage(h: Dictionary, amount: float) -> void:
	if h["gone"]:
		return
	var armor: float = h.get("armor", 0.0)
	if armor > 0.0:
		amount = maxf(amount - armor, amount * 0.3)
	h["hp"] -= amount
	s.fx.emit("hit_hero", h, amount)
	if h["boss"] and not h["half_said"] and h["hp"] > 0.0 and h["hp"] < h["max_hp"] * 0.5:
		h["half_said"] = true
		for line in boss_lines()["half"]:
			s.narrate.emit(Loc.t(line))
	if h["hp"] <= 0.0:
		_kill(h)
	elif h["trait"] == "coward" and not h["boss"] and h["hp"] < h["max_hp"] * 0.3:
		escape(h, Loc.t("panics and flees for the surface"))


func heal(h: Dictionary, amount: float) -> void:
	h["hp"] = minf(h["max_hp"], h["hp"] + amount)


func _kill(h: Dictionary) -> void:
	h["death_tile"] = h["cur"]
	remove(h)
	s.kills += 1
	s.fx.emit("death", h, 0.0)
	if run.warden.is_kind("brood") and s.count_units(h["cur"], "Spider") > 0:
		run.warden.gain_xp(D.XP_BROOD_KILL)
	s.add_threat(D.THREAT_PER_KILL, "kills")
	_harvest(h)
	run.cards.draw_card()
	run.loot.drop_from(h)
	for x in s.heroes:
		if x["party"] == h["party"] and x["trait"] == "loyal":
			x["dmg"] += 2.0
			x["revenge"] = true
			s.add_log(Loc.t("%s the Loyal swears to avenge %s!") % [x["name"], h["name"]])
	s.hand_changed.emit()
	run.souls.on_death(h)
	run.beat("first_kill")
	run.beat("tut_souls")
	if h["boss"]:
		for line in boss_lines()["death"]:
			s.narrate.emit(Loc.t(line))
		s.add_log(Loc.t("%s has fallen!") % s.hero_name(h))
		run.end_game(true)


## Every body is harvested according to who it was.
func _harvest(h: Dictionary) -> void:
	var drop: Dictionary = D.HERO_CLASSES[h["cls"]]["drop"]
	var times := 2 if h.get("swallowed", false) else 1
	var gold_before := int(s.pouch.get("gold", 0))
	for k in drop:
		s.gain(k, int(drop[k]) * times)
	if h["baited"] and s.has_relic("gilded_bait"):
		s.gain("gold", 2)
	if h["boss"]:
		for k in D.BOSS_DROP:
			s.gain(k, int(D.BOSS_DROP[k]))
	var relic_chance := 0.0
	if h["trait"] == "veteran":
		relic_chance = D.VETERAN_RELIC_CHANCE
	elif h["cls"] == "mage":
		relic_chance = D.MAGE_RELIC_CHANCE
	if h["boss"] or s.rng.randf() < relic_chance:
		_find_relic(h)
	var gold_gained := int(s.pouch.get("gold", 0)) - gold_before
	if run.warden.is_kind("mimic") and gold_gained > 0:
		run.warden.gain_xp(gold_gained * D.XP_PER_GOLD)
		if run.warden.has("hoard_heal"):
			run.warden.heal_by(gold_gained)
	run.warden.recompute()  # the Mimic King grows with the gold


func _find_relic(h: Dictionary) -> void:
	var id: String = Meta.random_unowned_relic(s.rng, s.found_relics)
	if id == "":
		return
	s.found_relics.append(id)
	var relic_name: String = Loc.t(D.RELICS[id]["name"])
	s.add_log(Loc.t("%s carried a relic: %s! Survive to keep it.") % [h["name"], relic_name])
	s.combo_found.emit(Loc.t("RELIC FOUND: %s") % relic_name)


func boss_lines() -> Dictionary:
	return D.BRANN_LINES if s.act == 2 else D.BOSS_LINES


## Act II champion: Brann plants charges on nearby halls; after a short fuse they blow up
## the card, the monsters on it, and anyone standing there (the Warden too).
func boss_tick(delta: float) -> void:
	if s.act != 2:
		return
	var boss = null
	for h in s.heroes:
		if h["boss"] and not h["gone"] and h["delay"] <= 0.0:
			boss = h
	for c in s.charges:
		c["fuse"] -= delta
	for c in s.charges.duplicate():
		if c["fuse"] <= 0.0:
			s.charges.erase(c)
			_detonate(c["tile"], boss)
	if boss == null:
		return
	s.charge_timer += delta
	if s.charge_timer < D.BRANN_CHARGE_EVERY:
		return
	s.charge_timer = 0.0
	var here: int = boss["cur"]
	var options: Array = []
	for i in s.loop_size:
		var dist: int = mini(absi(i - here), s.loop_size - absi(i - here))
		if dist <= 4 and i != 0 and (s.card_at(i) != "" or s.warden_at(i)):
			options.append(i)
	if options.is_empty():
		return
	var t: int = options[s.rng.randi() % options.size()]
	s.charges.append({"tile": t, "fuse": D.BRANN_FUSE})
	s.add_log(Loc.t("Brann plants a charge!"))


func _detonate(t: int, boss) -> void:
	s.fx.emit("blast", t, D.BRANN_BLAST)
	if s.card_at(t) != "":
		s.add_log(Loc.t("BOOM! Your %s is blown apart.") % Loc.t(D.CARDS[s.card_at(t)]["name"]))
		s.tiles[t]["card"] = ""
	for u in s.alive_units(t):
		u["hp"] -= D.BRANN_BLAST
	s.tiles[t]["units"] = s.alive_units(t)
	for h in s.travelers_at(t):
		if not h["boss"]:
			damage(h, D.BRANN_BLAST)
	if s.warden_at(t):
		run.warden.take_hit(D.BRANN_BLAST, boss if boss != null else {})


func remove(h: Dictionary) -> void:
	h["gone"] = true
	var id: int = h["id"]
	s.heroes = s.heroes.filter(func(x): return x["id"] != id)
