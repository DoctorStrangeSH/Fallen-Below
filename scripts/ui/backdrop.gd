extends Control
## Menu background: dark stone with faint cracks, a warm glow from below,
## slow drifting embers and a vignette. Purely decorative.

var cracks: Array = []
var embers: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = 1337
	for i in 26:
		var p := Vector2(rng.randf() * 1280.0, rng.randf() * 720.0)
		var pts := PackedVector2Array([p])
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for k in rng.randi_range(3, 6):
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			p += dir * rng.randf_range(14.0, 40.0)
			pts.append(p)
		cracks.append(pts)
	for i in 40:
		embers.append(_ember(true))


func _ember(anywhere: bool) -> Dictionary:
	return {
		"p": Vector2(rng.randf() * 1280.0, rng.randf() * 720.0 if anywhere else 730.0),
		"v": Vector2(rng.randf_range(-6, 6), -rng.randf_range(8, 26)),
		"r": rng.randf_range(0.8, 2.2), "ph": rng.randf() * TAU,
	}


func _process(delta: float) -> void:
	for e in embers:
		e["p"] += e["v"] * delta
		e["p"].x += sin(Time.get_ticks_msec() / 900.0 + e["ph"]) * 6.0 * delta
	for i in embers.size():
		if embers[i]["p"].y < -10.0:
			embers[i] = _ember(false)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(1280, 720))
	draw_rect(r, Color(0.045, 0.035, 0.06))
	# warm glow rising from the depths
	for i in 10:
		var f := i / 10.0
		draw_circle(Vector2(640, 900), 520.0 - f * 380.0, Color(0.35, 0.06, 0.12, 0.025))
	for pts in cracks:
		draw_polyline(pts, Color(0.14, 0.1, 0.18, 0.7), 1.5)
	var t := Time.get_ticks_msec() / 1000.0
	for e in embers:
		var a := 0.35 + 0.35 * sin(t * 3.0 + e["ph"])
		var fade: float = clampf(e["p"].y / 720.0, 0.0, 1.0)
		draw_circle(e["p"], e["r"], Color(1.0, 0.55, 0.25, a * fade))
	# vignette
	for i in 8:
		var w := 40.0 + i * 22.0
		var c := Color(0, 0, 0, 0.06)
		draw_rect(Rect2(0, 0, 1280, w * 0.5), c)
		draw_rect(Rect2(0, 720 - w * 0.5, 1280, w * 0.5), c)
		draw_rect(Rect2(0, 0, w * 0.6, 720), c)
		draw_rect(Rect2(1280 - w * 0.6, 0, w * 0.6, 720), c)
