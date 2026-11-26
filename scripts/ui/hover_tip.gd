extends CanvasLayer
## A styled tooltip for menu screens. `tip.bind(control, func(): return "text")`.

const UI = preload("res://scripts/ui/ui_style.gd")

var panel: PanelContainer
var label: Label
var owner_ctrl: Control = null
var getter: Callable


func _ready() -> void:
	layer = 20
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.03, 0.06, 0.96), Color(0.5, 0.38, 0.65), 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)
	label = UI.label("", 14, Color(0.95, 0.92, 1.0))
	panel.add_child(label)


func bind(c: Control, text: Callable) -> void:
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_entered.connect(func():
		owner_ctrl = c
		getter = text
	)
	c.mouse_exited.connect(func():
		if owner_ctrl == c:
			owner_ctrl = null
	)


func _process(_d: float) -> void:
	if owner_ctrl == null or not is_instance_valid(owner_ctrl) or not owner_ctrl.is_visible_in_tree():
		owner_ctrl = null
		panel.visible = false
		return
	var text := str(getter.call())
	if text == "":
		panel.visible = false
		return
	if text != label.text:
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 0
		panel.size = Vector2.ZERO
		panel.reset_size()
		if panel.size.x > 380:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = 360
			panel.size = Vector2.ZERO
			panel.reset_size()
	panel.visible = true
	var m := panel.get_viewport().get_mouse_position()
	var p := m + Vector2(16, 18)
	if p.x + panel.size.x > 1276:
		p.x = m.x - panel.size.x - 12
	if p.y + panel.size.y > 716:
		p.y = m.y - panel.size.y - 12
	panel.position = p
