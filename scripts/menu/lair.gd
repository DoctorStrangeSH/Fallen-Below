extends Control
## The Lair: spend Bones on permanent buildings between runs.

const D = preload("res://scripts/data/game_data.gd")
const UI = preload("res://scripts/ui/ui_style.gd")

var bones_label: Label
var list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.background(self)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)

	var title := UI.label("THE LAIR", 36, Color(0.75, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	bones_label = UI.label("", 20, Color(0.95, 0.9, 0.75))
	bones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bones_label)

	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	v.add_child(list)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var run_btn := UI.button("Prepare descent")
	run_btn.pressed.connect(func(): Meta.start_run())
	row.add_child(run_btn)
	var grim := UI.button("Grimoire")
	grim.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/grimoire.tscn"))
	row.add_child(grim)
	var back := UI.button("Main menu")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(back)

	_rebuild()


func _rebuild() -> void:
	var parts: Array = []
	for k in D.RESOURCES:
		parts.append("%s: %d" % [D.RESOURCES[k]["name"], int(Meta.res[k])])
	bones_label.text = "      ".join(parts)
	for c in list.get_children():
		c.queue_free()
	for id in D.BUILDINGS:
		var def: Dictionary = D.BUILDINGS[id]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.07, 0.14), Color(0.3, 0.22, 0.4)))
		panel.custom_minimum_size = Vector2(720, 0)
		list.add_child(panel)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		panel.add_child(h)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var lvl: int = Meta.level(id)
		var max_lvl: int = Meta.max_level(id)
		info.add_child(UI.label("%s   [%d/%d]" % [def["name"], lvl, max_lvl], 16))
		info.add_child(UI.label(def["desc"], 13, Color(1, 1, 1, 0.65)))

		var cost: Dictionary = Meta.next_cost(id)
		var maxed := cost.is_empty()
		var buy := UI.button("Built" if maxed else Meta.cost_text(cost), Vector2(260, 40))
		buy.disabled = maxed or not Meta.can_afford(cost)
		var bid: String = id
		buy.pressed.connect(func():
			if Meta.buy(bid):
				_rebuild()
		)
		h.add_child(buy)
