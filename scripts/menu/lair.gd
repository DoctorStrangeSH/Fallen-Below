extends Control
## The Lair: a cavern you furnish between runs. Click a spot on the map,
## read what it does, build it with the bones, blood and gold of the fallen.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const LairMap = preload("res://scripts/menu/lair_map.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Icons = preload("res://scripts/ui/icons.gd")

var res_labels := {}
var cost_row: HBoxContainer
var map: LairMap
var title_label: Label
var level_label: Label
var desc_label: Label
var req_label: Label
var cost_label: Label
var build_btn: Button
var selected_id := "den"


func _ready() -> void:
	Music.play("menu")
	# a new memory surfaces when enough pages of the Book of the Fallen are collected
	var memory: String = Meta.pending_memory()
	if memory != "" and Meta.first_time(memory):
		Meta.play_story.call_deferred(memory, "res://scenes/lair.tscn")
		return
	UI.background(self)

	var title := UI.title(Loc.t("THE LAIR"), 32)
	title.position = Vector2(30, 12)
	add_child(title)
	var res_row := HBoxContainer.new()
	res_row.position = Vector2(300, 22)
	res_row.add_theme_constant_override("separation", 22)
	add_child(res_row)
	for r in D.RESOURCES:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(Icon.make(r, 20))
		var l := UI.label("", 20, Icons.color_of(r))
		cell.add_child(l)
		res_labels[r] = l
		res_row.add_child(cell)

	map = LairMap.new()
	map.position = Vector2(20, 70)
	map.size = Vector2(800, 560)
	map.selected.connect(_select)
	add_child(map)

	# details
	var panel := UI.panel()
	panel.position = Vector2(840, 70)
	panel.custom_minimum_size = Vector2(420, 560)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	title_label = UI.label("", 24, Color(0.85, 0.7, 1.0))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(390, 0)
	v.add_child(title_label)
	v.add_child(UI.ornament(390))
	level_label = UI.label("", 15, Color(1, 0.85, 0.5))
	v.add_child(level_label)
	desc_label = UI.label("", 15, Color(1, 1, 1, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(390, 0)
	v.add_child(desc_label)
	req_label = UI.label("", 14, Color(1, 0.55, 0.45))
	req_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req_label.custom_minimum_size = Vector2(390, 0)
	v.add_child(req_label)
	cost_label = UI.label("", 15)
	v.add_child(cost_label)
	cost_row = HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 16)
	v.add_child(cost_row)
	build_btn = UI.primary(Loc.t("Build"), Vector2(390, 52))
	build_btn.pressed.connect(func():
		if Meta.buy(selected_id):
			_refresh()
	)
	v.add_child(build_btn)

	var row := HBoxContainer.new()
	row.position = Vector2(20, 650)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var run_btn := UI.primary(Loc.t("Prepare descent"), Vector2(240, 46))
	run_btn.pressed.connect(func(): Meta.start_run())
	row.add_child(run_btn)
	var book := UI.button(Loc.t("Book of the Fallen"))
	book.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/book.tscn"))
	row.add_child(book)
	var grim := UI.button(Loc.t("Grimoire"))
	grim.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/grimoire.tscn"))
	row.add_child(grim)
	var back := UI.button(Loc.t("Main menu"))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(back)

	_select(_first_affordable())


## Start on something the player can build right now, if anything.
func _first_affordable() -> String:
	for id in D.BUILDINGS:
		var c: Dictionary = Meta.next_cost(id)
		if not c.is_empty() and Meta.requirements_met(id) and Meta.can_afford(c):
			return id
	return "den"


func _select(id: String) -> void:
	selected_id = id
	map.current = id
	_refresh()


func _refresh() -> void:
	for k in res_labels:
		res_labels[k].text = str(int(Meta.res[k]))

	var def: Dictionary = D.BUILDINGS[selected_id]
	var lvl: int = Meta.level(selected_id)
	var max_lvl: int = Meta.max_level(selected_id)
	title_label.text = Loc.t(def["name"])
	level_label.text = Loc.t("Level %d / %d") % [lvl, max_lvl]
	desc_label.text = Loc.t(def["desc"])
	var met: bool = Meta.requirements_met(selected_id)
	req_label.text = "" if met else Loc.t("Requires: %s") % Meta.requirements_text(selected_id)
	var cost: Dictionary = Meta.next_cost(selected_id)
	if cost.is_empty():
		cost_label.text = Loc.t("Fully built.")
		_cost_icons({})
		build_btn.text = Loc.t("Built")
		build_btn.disabled = true
	else:
		cost_label.text = Loc.t("Next level:")
		_cost_icons(cost)
		build_btn.text = Loc.t("Build") if lvl == 0 else Loc.t("Upgrade to level %d") % (lvl + 1)
		build_btn.disabled = not met or not Meta.can_afford(cost)


## The price as resource icons; a number turns red when the Lair cannot pay it.
func _cost_icons(cost: Dictionary) -> void:
	for c in cost_row.get_children():
		c.queue_free()
	for k in cost:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 5)
		cell.add_child(Icon.make(k, 18))
		var enough: bool = int(Meta.res[k]) >= int(cost[k])
		cell.add_child(UI.label(str(int(cost[k])), 18, Icons.color_of(k) if enough else Color(1, 0.35, 0.3)))
		cost_row.add_child(cell)
