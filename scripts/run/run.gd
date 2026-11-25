extends Node
## Root of a run. Owns the state, wires systems, view and HUD, runs the clock.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const HeroSystem = preload("res://scripts/systems/hero_system.gd")
const WardenSystem = preload("res://scripts/systems/warden_system.gd")
const CombatSystem = preload("res://scripts/systems/combat_system.gd")
const CardSystem = preload("res://scripts/systems/card_system.gd")
const SoulSystem = preload("res://scripts/systems/soul_system.gd")
const LootSystem = preload("res://scripts/systems/loot_system.gd")
const RunView = preload("res://scripts/run/run_view.gd")
const RunHud = preload("res://scripts/run/run_hud.gd")

var state: RunState
var heroes_sys: HeroSystem
var warden: WardenSystem
var combat: CombatSystem
var cards: CardSystem
var souls: SoulSystem
var loot: LootSystem
var view: RunView
var hud: RunHud


func _ready() -> void:
	state = RunState.new()
	state.setup(Meta.start_jars(), Meta.card_weights(), Meta.loadout, Meta.lure)

	heroes_sys = HeroSystem.new()
	_add_system(heroes_sys, "Travelers")
	warden = WardenSystem.new()
	_add_system(warden, "Warden")
	combat = CombatSystem.new()
	_add_system(combat, "Combat")
	cards = CardSystem.new()
	_add_system(cards, "Cards")
	souls = SoulSystem.new()
	_add_system(souls, "Souls")
	loot = LootSystem.new()
	_add_system(loot, "Loot")
	warden.setup(Meta.warden_hp(), Meta.warden_dmg())

	view = RunView.new()
	view.run = self
	add_child(view)
	hud = RunHud.new()
	hud.run = self
	add_child(hud)

	for i in Meta.start_cards():
		cards.draw_card()
	state.add_log("The door in the mountain opens. Someone is coming down.")
	heroes_sys.spawn_party()
	state.hand_changed.emit()
	beat("tut_start")
	beat("tut_warden")
	Music.play("run")


func _add_system(sys: Node, sys_name: String) -> void:
	sys.name = sys_name
	sys.set("run", self)
	sys.set("s", state)
	add_child(sys)


func _process(delta: float) -> void:
	if state.is_blocked():
		hud.refresh()
		return
	delta *= state.time_scale
	state.day_timer += delta
	if state.day_timer >= D.DAY_LENGTH:
		state.day_timer -= D.DAY_LENGTH
		_new_day()
	heroes_sys.move(delta)
	warden.move(delta)
	warden.tick(delta)
	state.combat_timer += delta
	if state.combat_timer >= D.COMBAT_TICK:
		state.combat_timer -= D.COMBAT_TICK
		combat.tick()
	if state.threat >= D.BOSS_THREAT * 0.5:
		beat("attention_half")
	if state.threat >= D.BOSS_THREAT and not state.boss_spawned and not state.game_over:
		heroes_sys.spawn_boss()
		Music.play("boss")
	Music.set_intensity(_fight_intensity())
	hud.refresh()


## 1 while blood is spilled somewhere, a low hum when travelers roam, 0 when the halls are empty.
func _fight_intensity() -> float:
	if state.heroes.is_empty():
		return 0.0
	for h in state.heroes:
		var t: int = h["cur"]
		if h["delay"] <= 0.0 and (state.warden_at(t) or not state.alive_units(t).is_empty()):
			return 1.0
	return 0.25


func _new_day() -> void:
	state.day += 1
	cards.draw_card()
	cards.respawn_rooms()
	heroes_sys.spawn_party()
	if state.day == 2:
		beat("tut_lure")
	if state.day % D.SEAL_EVERY == 0:
		beat("tut_week")
		state.add_log("The week ends: the dungeon may sleep now and keep everything.")
		hud.show_banner("WEEK'S END: SLEEP TO KEEP 100%")
	state.hand_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_SPACE, KEY_ESCAPE:
				toggle_pause()
			KEY_1:
				set_speed(1.0)
			KEY_2:
				set_speed(2.0)
			KEY_3:
				set_speed(3.0)
			KEY_R:
				souls.toggle_stance()
			KEY_Q:
				warden.use_active()
			KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5:
				_debug_key(key.keycode)
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		state.selected = -1
		state.hand_changed.emit()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if state.is_blocked():
			return
		cards.place_selected(view.mouse_cell())


## One-time story moment (saved across runs).
func beat(id: String) -> void:
	if D.BEATS.has(id) and Meta.first_time(id):
		state.narrate.emit(D.BEATS[id])


## Playtest shortcuts, only in debug builds (running from the editor).
func _debug_key(code: Key) -> void:
	if not OS.is_debug_build():
		return
	match code:
		KEY_F1:
			cards.draw_card()
			state.hand_changed.emit()
			state.add_log("[debug] +1 card")
		KEY_F2:
			state.threat = D.BOSS_THREAT
			state.add_log("[debug] the champion is summoned")
		KEY_F3:
			for k in Meta.res:
				Meta.res[k] = int(Meta.res[k]) + 50
			Meta.save_game()
			state.add_log("[debug] +50 of every resource (Lair)")
		KEY_F4:
			var fake := {"cls": D.HERO_CLASSES.keys()[state.rng.randi() % D.HERO_CLASSES.size()],
				"boss": false, "trait": "veteran", "name": "Debug"}
			loot.drop_from(fake)
		KEY_F5:
			warden._complete_loop()


func toggle_pause() -> void:
	if state.game_over:
		return
	state.paused = not state.paused


func set_speed(v: float) -> void:
	state.time_scale = v


func cycle_speed() -> void:
	set_speed(1.0 if state.time_scale >= 3.0 else state.time_scale + 1.0)


func set_lure(id: String) -> void:
	if Meta.available_lures().has(id):
		state.lure = id
		Meta.set_lure(id)
		state.add_log("New lure: %s. Tomorrow's travelers will follow it." % D.LURES[id]["name"])


## Warden slain (win = false) or champion slain (win = true).
func end_game(win: bool) -> void:
	_finish("victory" if win else "defeat", 1.0 if win else D.DEFEAT_PCT)


## Retreat like in Loop Hero: the dungeon falls asleep. Full payout at the end of a week.
func sleep() -> void:
	if state.game_over:
		return
	beat("first_sleep")
	_finish("sleep", state.seal_pct())


func _finish(outcome: String, pct: float) -> void:
	if state.game_over:
		return
	state.game_over = true
	var win := outcome == "victory"
	# a full sleep may turn up one more relic
	if outcome == "sleep" and pct >= 1.0 and state.rng.randf() < D.SEAL_RELIC_CHANCE:
		var r: String = Meta.random_unowned_relic(state.rng, state.found_relics)
		if r != "":
			state.found_relics.append(r)
	var payout := {}
	for k in state.pouch:
		payout[k] = int(round(int(state.pouch[k]) * pct))
	if win:
		payout["bones"] = int(payout["bones"]) + D.VICTORY_BONUS
	var kept: Array = []
	var lost: Array = []
	for r in state.found_relics:
		if outcome != "defeat" or state.rng.randf() < D.DEFEAT_RELIC_KEEP:
			kept.append(r)
		else:
			lost.append(r)
	Meta.record_run(state.day, state.kills, payout, kept, win)
	match outcome:
		"victory":
			Music.stinger("victory")
		"defeat":
			Music.stinger("defeat")
		_:
			Music.play("menu")
	if win:
		Meta.clear_act(state.act)
	hud.show_end(outcome, payout, pct, kept, lost)


## After the act's champion dies, play the act's ending, then go to the Lair.
func continue_after_victory() -> void:
	var act: Dictionary = D.ACTS[state.act]
	Meta.play_story(act["end_story"], "res://scenes/lair.tscn")


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
