extends RefCounted
## Shared UI helpers. Preload as `const UI = preload(...)`.

const ACCENT := Color(0.78, 0.6, 1.0)
const GOLD := Color(1.0, 0.8, 0.45)
const MUTED := Color(0.72, 0.66, 0.82, 0.75)
const PANEL_BG := Color(0.07, 0.05, 0.1, 0.92)
const PANEL_BORDER := Color(0.3, 0.22, 0.4)


static func box(color: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(3)
	return sb


## Thin-bordered box used for slots, chips and panels.
static func frame(color: Color, border: Color, width: int = 2, radius: int = 6, margin: int = 8) -> StyleBoxFlat:
	var sb := box(color, border, radius)
	sb.set_border_width_all(width)
	sb.set_content_margin_all(margin)
	return sb


static func button(text: String, min_size: Vector2 = Vector2(220, 44)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click"))
	var base := Color(0.13, 0.09, 0.18)
	b.add_theme_stylebox_override("normal", frame(base, Color(0.42, 0.3, 0.56)))
	b.add_theme_stylebox_override("hover", frame(base.lightened(0.1), Color(0.8, 0.62, 1.0)))
	b.add_theme_stylebox_override("pressed", frame(base.lightened(0.2), Color(1, 1, 1)))
	b.add_theme_stylebox_override("disabled", frame(Color(0.08, 0.07, 0.1), Color(0.2, 0.18, 0.24)))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	return b


## The one button a screen is about (New run, Descend): warm gold frame.
static func primary(text: String, min_size: Vector2 = Vector2(260, 52)) -> Button:
	var b := button(text, min_size)
	var base := Color(0.2, 0.12, 0.08)
	b.add_theme_stylebox_override("normal", frame(base, Color(0.85, 0.62, 0.3)))
	b.add_theme_stylebox_override("hover", frame(base.lightened(0.12), GOLD))
	b.add_theme_color_override("font_color", Color(1, 0.88, 0.65))
	b.add_theme_font_size_override("font_size", 18)
	return b


static func label(text: String, size: int = 16, color: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func header(text: String, size: int = 11) -> Label:
	return label(text.to_upper(), size, MUTED)


## A screen title with a small ornament (line — diamond — line) under it.
static func title(text: String, size: int = 34, centered: bool = false) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var l := label(text, size, ACCENT)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.25, 0.8))
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(ornament(300.0 if centered else 220.0, centered))
	return v


static func ornament(width: float, centered: bool = false) -> Control:
	var o := Control.new()
	o.custom_minimum_size = Vector2(width, 12)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.draw.connect(func():
		var w: float = o.size.x if centered else width
		var mid := Vector2(w * 0.5, 6)
		var col := Color(ACCENT, 0.55)
		o.draw_line(Vector2(0, 6), mid - Vector2(10, 0), Color(col, 0.0), 1.0)
		for i in 8:
			var f := i / 8.0
			o.draw_line(Vector2(f * (w * 0.5 - 10), 6), Vector2((f + 0.125) * (w * 0.5 - 10), 6), Color(col, f), 1.5)
			o.draw_line(Vector2(w - f * (w * 0.5 - 10), 6), Vector2(w - (f + 0.125) * (w * 0.5 - 10), 6), Color(col, f), 1.5)
		o.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -5), mid + Vector2(6, 0), mid + Vector2(0, 5), mid + Vector2(-6, 0)]), GOLD)
	)
	return o


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame(PANEL_BG, PANEL_BORDER, 2, 8, 14))
	return p


## Full-screen animated background for menu scenes.
static func background(parent: Control) -> void:
	parent.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.position = Vector2.ZERO
	parent.size = Vector2(1280, 720)
	var bg: Control = load("res://scripts/ui/backdrop.gd").new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	parent.add_child(bg)


static func hover_tip(parent: Node) -> CanvasLayer:
	var t: CanvasLayer = load("res://scripts/ui/hover_tip.gd").new()
	parent.add_child(t)
	return t
