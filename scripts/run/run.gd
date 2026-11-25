extends Node
## Root of a run. Owns the state, wires systems, view and HUD, runs the clock.

const D = preload("res://scripts/data/game_data.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const HeroSystem = preload("res://scripts/systems/hero_system.gd")
const CombatSystem = preload("res://scripts/systems/combat_system.gd")
const CardSystem = preload("res://scripts/systems/card_system.gd")
const SoulSystem = preload("res://scripts/systems/soul_system.gd")
const RunView = preload("res://scripts/run/run_view.gd")
const RunHud = preload("res://scripts/run/run_hud.gd")

var state: RunState
var heroes_sys: HeroSystem
var combat: CombatSystem
var cards: CardSystem
var souls: SoulSystem
var view: RunView
var hud: RunHud


func _ready() -> void:
	state = RunState.new()
	state.setup(Meta.heart_max(), Meta.start_jars(), Meta.start_essence(), Meta.card_weights())

	heroes_sys = HeroSystem.new()
	_add_system(heroes_sys, "Heroes")
	combat = CombatSystem.new()
	_add_system(combat, "Combat")
	cards = CardSystem.new()
	_add_system(cards, "Cards")
	souls = SoulSystem.new()
	_add_system(souls, "Souls")

	view = RunView.new()
	view.run = self
	add_child(view)
	hud = RunHud.new()
	hud.run = self
	add_child(hud)

	for i in Meta.start_cards():
		cards.draw_card()
	state.add_log("Heroes approach. Build your dungeon.")
	heroes_sys.spawn_party()
	state.hand_changed.emit()


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
	state.combat_timer += delta
	if state.combat_timer >= D.COMBAT_TICK:
		state.combat_timer -= D.COMBAT_TICK
		combat.tick()
	if state.threat >= D.BOSS_THREAT and not state.boss_spawned and not state.game_over:
		heroes_sys.spawn_boss()
	hud.refresh()


func _new_day() -> void:
	state.day += 1
	cards.draw_card()
	cards.respawn_rooms()
	heroes_sys.spawn_party()
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
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		state.selected = -1
		state.hand_changed.emit()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if state.game_over or not state.pending_souls.is_empty():
			return
		cards.place_selected(view.mouse_cell())


func toggle_pause() -> void:
	if state.game_over:
		return
	state.paused = not state.paused


func set_speed(v: float) -> void:
	state.time_scale = v


func cycle_speed() -> void:
	set_speed(1.0 if state.time_scale >= 3.0 else state.time_scale + 1.0)


func heal_heart() -> void:
	if state.essence >= D.RESTORE_COST and state.heart_hp < state.heart_max and not state.game_over:
		state.essence -= D.RESTORE_COST
		state.heart_hp = mini(state.heart_max, state.heart_hp + 5)


func end_game(win: bool) -> void:
	if state.game_over:
		return
	state.game_over = true
	var earned: int = Meta.record_run(state.day, state.kills, win)
	hud.show_end(win, earned)


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
