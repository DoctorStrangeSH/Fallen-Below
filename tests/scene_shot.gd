extends Node
## Screenshot of any scene: godot res://tests/scene_shot.tscn -- --scene=res://scenes/lair.tscn --lair=mid --out=/tmp/x.png

const D = preload("res://scripts/data/game_data.gd")

var out := "/tmp/shot.png"
var frames := 0


func _ready() -> void:
	var scene := "res://scenes/lair.tscn"
	Meta.no_save = true
	Meta.seen.append_array(["memory_sword", "memory_feast"])
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"scene":
				scene = kv[1]
			"out":
				out = kv[1]
			"lang":
				Loc.set_language(kv[1], false)
			"lair":
				Meta.buildings = {}
				for id in D.BUILDINGS:
					var m: int = Meta.max_level(id)
					if kv[1] == "mid":
						Meta.buildings[id] = int(ceil(m / 2.0)) if ["den", "forge", "larder", "pens", "archive", "treasury", "shrine"].has(id) else 0
					elif kv[1] == "full":
						Meta.buildings[id] = m
				Meta.res = {"bones": 140, "blood": 45, "gold": 60}
	add_child(load(scene).instantiate())


func _process(_d: float) -> void:
	frames += 1
	if frames == 30:
		get_viewport().get_texture().get_image().save_png(out)
		print("saved ", out)
		get_tree().quit()
