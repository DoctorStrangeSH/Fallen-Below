extends Control
## Renders the game icon (the dungeon's heart) and saves it cropped to 256x256.
## xvfb-run godot --rendering-driver opengl3 res://tests/icon_shot.tscn -- --out=/path.png

const Icons = preload("res://scripts/ui/icons.gd")

var frames := 0
var out := "/tmp/icon.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	size = Vector2(1280, 720)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.035, 0.07))
	var c := Vector2(640, 360)
	draw_circle(c, 124, Color(0.09, 0.06, 0.12))
	draw_arc(c, 124, 0, TAU, 64, Color(0.55, 0.4, 0.75), 6.0)
	Icons.heart(self, c + Vector2(0, 6), 4.6, 0.06 * 60.0 / 50.0, 50.0, 0.6)


func _process(_d: float) -> void:
	frames += 1
	queue_redraw()
	if frames == 10:
		var img := get_viewport().get_texture().get_image()
		img = img.get_region(Rect2i(512, 232, 256, 256))
		img.save_png(out)
		print("saved ", out)
		get_tree().quit()
