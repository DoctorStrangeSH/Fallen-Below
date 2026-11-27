extends Node
## Runs every tests/ag/unit/test_*.gd. Exit code 0 = all passed.
## godot --headless res://tests/ag/unit_runner.tscn [-- --only=name]

const DIR := "res://tests/ag/unit/"


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var files: Array = []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var total_fail := 0
	var total_checks := 0
	var total_tests := 0
	for f in files:
		if only != "" and not f.contains(only):
			continue
		var script: GDScript = load(DIR + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var case = script.new()
			case.tree = get_tree()
			case.call(name)
			total_tests += 1
			total_checks += case.checks
			if case.failures.is_empty():
				print("  ok    %s :: %s" % [f, name])
			else:
				total_fail += 1
				print("  FAIL  %s :: %s" % [f, name])
				for msg in case.failures:
					print("        - " + str(msg))
	print("UNIT: %d tests, %d checks, %d failed" % [total_tests, total_checks, total_fail])
	get_tree().quit(1 if total_fail > 0 else 0)
