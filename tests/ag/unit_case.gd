extends RefCounted
## Base class for ABYSSAL GENESIS unit tests. Methods named test_* are run by unit_runner.gd.

var failures: Array = []
var checks: int = 0
var tree: SceneTree


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func eq(a, b, msg: String) -> void:
	checks += 1
	if typeof(a) != typeof(b) or a != b:
		failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])


## Scratch save folder that never touches the real user saves.
func scratch_dir(name: String) -> String:
	var d := "user://ag_test/%s/" % name
	var abs := ProjectSettings.globalize_path(d)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs + f)
	DirAccess.make_dir_recursive_absolute(abs)
	return d


func write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
