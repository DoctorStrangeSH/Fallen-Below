extends Node
## ABYSSAL GENESIS saves (TECH_SPEC 5). Registered as autoload "Saves".
## - campaign.json: CampaignState; sprout.json: the run in progress; settings.cfg: options.
## - Atomic writes: *.tmp -> verified -> previous file kept as *.bak -> rename.
## - A corrupt file falls back to *.bak and is kept as *.corrupt; the campaign is never silently reset.
## - Fallen Below's user://save.json is only ever read (migration v2 -> v3), never written.

const Campaign = preload("res://scripts/ag/core/campaign_state.gd")
const Sprout = preload("res://scripts/ag/run/sprout_state.gd")

const LEGACY_SAVE := "user://save.json"
const SETTINGS_DEFAULTS := {
	"audio": {"music": 0.7, "sfx": 0.8, "ambience": 0.7, "voice": 0.9},
	"video": {"fullscreen": false, "ui_scale": 1.0, "screen_shake": true, "flashes": true},
	"game": {"language": "", "auto_pause": true},
}

var dir := "user://ag/"     # tests point this at a scratch folder
var legacy_path := LEGACY_SAVE
var disabled := false       # bots and tests that must not write anything
var last_notice := ""       # shown to the player after a recovery
var disabled_campaign_overwrite := false  # both campaign files were unreadable: preserve them before the next save


func campaign_path() -> String: return dir + "campaign.json"
func sprout_path() -> String: return dir + "sprout.json"
func settings_path() -> String: return dir + "settings.cfg"


# ------------------------------------------------------------------ low level

func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


func _rename(from: String, to: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)) == OK


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Moves the verified tmp file into place, keeping the previous version as .bak.
func _commit(tmp: String, path: String) -> bool:
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		_remove(bak)
		if not _rename(path, bak):
			_remove(tmp)
			return false
	if not _rename(tmp, path):
		if FileAccess.file_exists(bak):
			_rename(bak, path)
		return false
	return true


func write_json_atomic(path: String, data: Dictionary) -> bool:
	if disabled:
		return false
	_ensure_dir()
	var text := JSON.stringify(data, "\t", true, true)   # full precision: a loaded sprout continues identically
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write %s: %s" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	if _parse(tmp) == null:
		_remove(tmp)
		return false
	return _commit(tmp, path)


static func _parse(path: String):
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()   # JSON.new().parse() reports errors quietly, unlike JSON.parse_string()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data if json.data is Dictionary else null


## Returns {"data": Dictionary, "source": "main" | "backup" | "none", "error": String}.
func read_json_with_backup(path: String) -> Dictionary:
	var main = _parse(path)
	if main != null:
		return {"data": main, "source": "main", "error": ""}
	var exists := FileAccess.file_exists(path)
	var bak = _parse(path + ".bak")
	if bak != null:
		if exists and not disabled:
			# keep the broken file for diagnosis and put the backup back in place
			_remove(path + ".corrupt")
			_rename(path, path + ".corrupt")
			write_json_atomic(path, bak)
		return {"data": bak, "source": "backup", "error": "main file corrupt" if exists else "main file missing"}
	return {"data": {}, "source": "none", "error": "corrupt" if exists or FileAccess.file_exists(path + ".bak") else ""}


func _emit_saved(kind: String, ok: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bus = tree.root.get_node_or_null("Bus") if tree else null
	if bus:
		bus.saved.emit(kind, ok)


# ------------------------------------------------------------------ campaign

func save_campaign(c) -> bool:
	if disabled_campaign_overwrite and not disabled:
		# never destroy a damaged campaign: move both files aside before writing a new one
		var p := campaign_path()
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(p + suffix):
				_remove(p + suffix + ".corrupt")
				_rename(p + suffix, p + suffix + ".corrupt")
		disabled_campaign_overwrite = false
	var ok := write_json_atomic(campaign_path(), c.to_dict())
	_emit_saved("campaign", ok)
	return ok


## Loads the campaign. A first launch with a Fallen Below save migrates it (v2 -> v3).
## If both campaign files are unreadable it returns a fresh campaign but does NOT overwrite them.
func load_campaign():
	last_notice = ""
	var r := read_json_with_backup(campaign_path())
	match str(r["source"]):
		"main":
			return Campaign.from_dict(r["data"])
		"backup":
			last_notice = "The campaign was restored from a backup."
			return Campaign.from_dict(r["data"])
	if str(r["error"]) != "":
		last_notice = "The campaign save is damaged. It was kept as a .corrupt file and a new campaign begins."
		disabled_campaign_overwrite = true
		return Campaign.new()
	return migrate_legacy()



func migrate_legacy():
	var c = Campaign.new()
	var legacy = _parse(legacy_path)
	if legacy == null:
		return c
	c.veteran = true
	c.flags["fallen_below_runs"] = int(legacy.get("runs", 0))
	c.flags["fallen_below_acts"] = (legacy.get("acts_cleared", []) as Array).size() if legacy.get("acts_cleared", []) is Array else 0
	if not FileAccess.file_exists(settings_path()):
		var cfg := default_settings()
		cfg.set_value("audio", "music", clampf(float(legacy.get("music_volume", 0.7)), 0.0, 1.0))
		cfg.set_value("audio", "sfx", clampf(float(legacy.get("sfx_volume", 0.8)), 0.0, 1.0))
		cfg.set_value("video", "fullscreen", bool(legacy.get("fullscreen", false)))
		cfg.set_value("game", "language", str(legacy.get("language", "")))
		cfg.set_value("game", "auto_pause", bool(legacy.get("auto_pause", true)))
		save_settings(cfg)
	return c


# ------------------------------------------------------------------ sprout (run in progress)

func save_sprout(s) -> bool:
	var ok := write_json_atomic(sprout_path(), {"schema": Sprout.SCHEMA, "gen_version": Sprout.GEN_VERSION,
		"tick": s.tick, "format": "variant64", "data": s.pack()})
	_emit_saved("sprout", ok)
	return ok


func has_sprout() -> bool:
	return FileAccess.file_exists(sprout_path())


## Ironman rule: loading consumes the file; it is written again on exit or autosave.
func load_sprout():
	var r := read_json_with_backup(sprout_path())
	if str(r["source"]) == "none":
		return null
	var d: Dictionary = r["data"]
	var s = Sprout.unpack(str(d.get("data", ""))) if str(d.get("format", "")) == "variant64" else Sprout.from_dict(d)
	if not disabled:
		discard_sprout()
	return s


func discard_sprout() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		_remove(sprout_path() + suffix)


# ------------------------------------------------------------------ settings

func default_settings() -> ConfigFile:
	var cfg := ConfigFile.new()
	for section in SETTINGS_DEFAULTS:
		for key in SETTINGS_DEFAULTS[section]:
			cfg.set_value(section, key, SETTINGS_DEFAULTS[section][key])
	return cfg


func save_settings(cfg: ConfigFile) -> bool:
	if disabled:
		return false
	_ensure_dir()
	var tmp := settings_path() + ".tmp"
	if cfg.save(tmp) != OK:
		return false
	var check := ConfigFile.new()
	if check.load(tmp) != OK:
		_remove(tmp)
		return false
	return _commit(tmp, settings_path())


func load_settings() -> ConfigFile:
	var cfg := default_settings()
	var loaded := ConfigFile.new()
	var path := settings_path()
	if loaded.load(path) != OK and loaded.load(path + ".bak") != OK:
		return cfg
	for section in loaded.get_sections():
		for key in loaded.get_section_keys(section):
			cfg.set_value(section, key, loaded.get_value(section, key))
	return cfg
