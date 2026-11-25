extends RefCounted
## Shared UI helpers. Preload as `const UI = preload(...)`.


static func box(color: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(3)
	return sb


static func button(text: String, min_size: Vector2 = Vector2(220, 44)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	var base := Color(0.16, 0.11, 0.22)
	b.add_theme_stylebox_override("normal", box(base, Color(0.45, 0.3, 0.6)))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.15), Color(0.7, 0.5, 0.9)))
	b.add_theme_stylebox_override("pressed", box(base.lightened(0.25), Color(1, 1, 1)))
	b.add_theme_stylebox_override("disabled", box(Color(0.1, 0.09, 0.12), Color(0.2, 0.18, 0.24)))
	return b


static func label(text: String, size: int = 16, color: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Full-screen dark background for menu scenes.
static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
