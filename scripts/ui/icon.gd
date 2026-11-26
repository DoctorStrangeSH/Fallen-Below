extends Control
## A Control that shows one drawn icon (see icons.gd), centred in its rect.
## `kind` starting with "card:" draws a card glyph instead.

const Icons = preload("res://scripts/ui/icons.gd")

var kind := ""
var col := Color(1, 1, 1)
var icon_size := 16.0
var animated := false


static func make(k: String, sz: float = 16.0, c: Color = Color(-1, 0, 0)) -> Control:
	var i = load("res://scripts/ui/icon.gd").new()
	i.kind = k
	i.icon_size = sz
	i.col = Icons.color_of(k) if c.r < 0.0 else c
	i.custom_minimum_size = Vector2(sz + 4, sz + 4)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func set_icon(k: String, c: Color) -> void:
	if k != kind or c != col:
		kind = k
		col = c
		queue_redraw()


func _process(_d: float) -> void:
	if animated:
		queue_redraw()


func _draw() -> void:
	if kind == "":
		return
	if kind.begins_with("card:"):
		Icons.card_glyph(self, kind.substr(5), size / 2.0, Time.get_ticks_msec() / 1000.0)
	else:
		Icons.paint(self, kind, size / 2.0, icon_size, col)
