extends Control
## Top resource bar (GDD 5, 15): stock / cap, 10-second forecast, and a tooltip that names every source.
## Reads the economy only. `bar.economy = sp.economy` after the sprout starts.

const UI = preload("res://scripts/ui/ui_style.gd")
const Reg = preload("res://scripts/ag/core/registry.gd")

const SLOTS := ["resource.biomass", "resource.energy", "resource.genome", "impulse"]
const SLOT_W := 230.0
const FORECAST_SECONDS := 10.0

var economy
var tip: CanvasLayer
var labels := {}
var nets := {}
var t := 0.0
var warn: Label


func _ready() -> void:
	size = Vector2(1120, 30)
	tip = UI.hover_tip(self)
	for i in SLOTS.size():
		var id: String = SLOTS[i]
		var box := Control.new()
		box.position = Vector2(i * SLOT_W, 0)
		box.size = Vector2(SLOT_W - 10, 30)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(box)
		var l := UI.label("", 16, Color(0.95, 0.92, 1.0))
		l.position = Vector2(30, 4)
		box.add_child(l)
		labels[id] = l
		var n := UI.label("", 14, UI.MUTED)
		n.position = Vector2(140, 6)
		box.add_child(n)
		nets[id] = n
		tip.bind(box, _tooltip.bind(id))
	warn = UI.label("", 14, Color(1.0, 0.55, 0.45))
	warn.position = Vector2(SLOTS.size() * SLOT_W, 6)
	add_child(warn)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if economy == null or economy.s == null:
		return
	var f: Dictionary = economy.forecast(FORECAST_SECONDS)
	for id in SLOTS:
		var l: Label = labels[id]
		var n: Label = nets[id]
		if id == "impulse":
			l.text = "%d / %d" % [floori(economy.s.impulses), int(economy.impulse_cap())]
			var ir: float = economy.impulse_rate() * FORECAST_SECONDS
			n.text = ("+%.1f" % ir) if ir > 0.0 else ""
			n.add_theme_color_override("font_color", UI.MUTED)
			continue
		l.text = "%d / %d" % [floori(economy.amount(id)), int(economy.cap(id))]
		var v: float = f[id]["net"]
		n.text = "%s%.1f" % ["+" if v >= 0.0 else "", v]
		n.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6) if v > 0.05 else (Color(1.0, 0.45, 0.4) if v < -0.05 else UI.MUTED))
	var asleep := 0
	for uid in economy.s.organs:
		if str(economy.s.organs[uid]["state"]) == "asleep":
			asleep += 1
	warn.text = Loc.t("Organs asleep: %d — not enough energy") % asleep if asleep > 0 else ""


func _tooltip(id: String) -> String:
	if economy == null:
		return ""
	if id == "impulse":
		return Loc.t("Nerve impulses") + "\n" + Loc.t("Spent on commands to creatures. Nerve Nodes produce them and raise the limit.")
	var d := Reg.get_def(id)
	var f: Dictionary = economy.forecast(FORECAST_SECONDS)
	var lines: Array = [Loc.t(str(d["name"])), Loc.t(str(d["desc"])), "", Loc.t("Next %d seconds:") % int(FORECAST_SECONDS)]
	var src: Dictionary = f[id]["lines"]
	var keys: Array = src.keys()
	keys.sort_custom(func(a, b): return float(src[a]) > float(src[b]))
	for k in keys:
		lines.append("  %s%.1f  %s" % ["+" if float(src[k]) >= 0.0 else "", float(src[k]), Loc.t(str(k))])
	if keys.is_empty():
		lines.append("  " + Loc.t("No change"))
	var net: float = f[id]["net"]
	lines.append(Loc.t("Total: %s") % ("%s%.1f" % ["+" if net >= 0.0 else "", net]))
	if economy.amount(id) >= economy.cap(id) - 0.01 and net > 0.0:
		lines.append(Loc.t("Storage is full: the surplus is lost."))
	return "\n".join(lines)


func _draw() -> void:
	for i in SLOTS.size():
		var c := Vector2(i * SLOT_W + 13, 15)
		match SLOTS[i]:
			"resource.biomass":
				draw_circle(c, 8.0, Color(0.7, 0.12, 0.16))
				draw_circle(c + Vector2(-2.5, -2.5), 2.5, Color(1, 0.5, 0.5, 0.7))
			"resource.energy":
				var b := 1.0 + 0.12 * sin(t * 6.0)
				var pts := PackedVector2Array([c + Vector2(0, -9) * b, c + Vector2(6, 0) * b, c + Vector2(0, 9) * b, c + Vector2(-6, 0) * b])
				draw_colored_polygon(pts, Color(0.62, 0.35, 0.95))
				draw_circle(c, 2.5, Color(0.95, 0.85, 1.0))
			"resource.genome":
				for k in 5:
					var y := -8.0 + k * 4.0
					var x := sin(t * 2.0 + k * 0.9) * 6.0
					draw_line(c + Vector2(-x, y), c + Vector2(x, y), Color(0.5, 0.9, 0.7), 1.5)
					draw_circle(c + Vector2(x, y), 1.6, Color(0.5, 0.9, 0.7))
					draw_circle(c + Vector2(-x, y), 1.6, Color(0.8, 1.0, 0.85))
			"impulse":
				var pts2 := PackedVector2Array([c + Vector2(2, -9), c + Vector2(-5, 1), c + Vector2(0, 1), c + Vector2(-2, 9), c + Vector2(5, -2), c + Vector2(0, -2)])
				draw_colored_polygon(pts2, Color(0.7, 0.85, 1.0))
