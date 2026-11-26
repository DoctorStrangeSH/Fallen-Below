extends Control
## Screenshot of the settings overlay over the main menu.

var frames := 0


func _ready() -> void:
	Meta.no_save = true
	Loc.set_language("ru", false)
	add_child(load("res://scenes/main_menu.tscn").instantiate())
	add_child(load("res://scripts/ui/settings_panel.gd").new())


func _process(_d: float) -> void:
	frames += 1
	if frames == 40:
		get_viewport().get_texture().get_image().save_png("/tmp/settings.png")
		get_tree().quit()
