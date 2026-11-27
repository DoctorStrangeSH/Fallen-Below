extends "res://tests/ag/unit_case.gd"

const SaveManager = preload("res://scripts/autoload/save_manager.gd")
const Campaign = preload("res://scripts/ag/core/campaign_state.gd")
const Sprout = preload("res://scripts/ag/run/sprout_state.gd")


func _manager(name: String):
	var m = SaveManager.new()
	m.dir = scratch_dir(name)
	m.legacy_path = m.dir + "legacy_save.json"
	return m


func _campaign(tag: String):
	var c = Campaign.new()
	c.flags["tag"] = tag
	return c


func test_campaign_round_trip_and_backup() -> void:
	var m = _manager("roundtrip")
	check(m.save_campaign(_campaign("one")), "first save")
	check(m.save_campaign(_campaign("two")), "second save")
	check(FileAccess.file_exists(m.campaign_path() + ".bak"), "backup kept")
	check(not FileAccess.file_exists(m.campaign_path() + ".tmp"), "no tmp left")
	eq(str(m.load_campaign().flags["tag"]), "two", "latest loaded")
	m.free()


func test_corrupt_main_restores_from_backup() -> void:
	var m = _manager("corrupt_main")
	m.save_campaign(_campaign("old"))
	m.save_campaign(_campaign("new"))
	write_text(m.campaign_path(), "{ broken")
	var c = m.load_campaign()
	eq(str(c.flags["tag"]), "old", "backup used")
	check(m.last_notice != "", "player is told")
	check(FileAccess.file_exists(m.campaign_path() + ".corrupt"), "broken file kept")
	eq(str(Campaign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(m.campaign_path()))).flags["tag"]), "old", "main repaired")
	m.free()


func test_both_corrupt_never_silently_lost() -> void:
	var m = _manager("both_corrupt")
	write_text(m.campaign_path(), "garbage")
	write_text(m.campaign_path() + ".bak", "garbage too")
	var c = m.load_campaign()
	check(c.unlocked.is_empty() and not c.veteran, "fresh campaign")
	check(m.last_notice != "", "player is told")
	m.save_campaign(_campaign("fresh"))
	eq(FileAccess.get_file_as_string(m.campaign_path() + ".corrupt"), "garbage", "damaged main preserved")
	eq(FileAccess.get_file_as_string(m.campaign_path() + ".bak.corrupt"), "garbage too", "damaged backup preserved")
	m.free()


func test_legacy_v2_migration_reads_only() -> void:
	var m = _manager("legacy")
	var legacy := JSON.stringify({"version": 2, "runs": 14, "acts_cleared": [1, 2], "music_volume": 0.3,
		"sfx_volume": 0.5, "fullscreen": true, "language": "ru", "auto_pause": false, "res": {"bones": 50}})
	write_text(m.legacy_path, legacy)
	var c = m.load_campaign()
	check(c.veteran, "veteran flag")
	eq(int(c.flags["fallen_below_runs"]), 14, "runs carried as a flag")
	eq(int(c.flags["fallen_below_acts"]), 2, "acts carried as a flag")
	check(c.unlocked.is_empty(), "no progress carried into the new game")
	var cfg: ConfigFile = m.load_settings()
	eq(float(cfg.get_value("audio", "music")), 0.3, "music volume migrated")
	eq(bool(cfg.get_value("video", "fullscreen")), true, "fullscreen migrated")
	eq(str(cfg.get_value("game", "language")), "ru", "language migrated")
	eq(FileAccess.get_file_as_string(m.legacy_path), legacy, "legacy save untouched")
	m.free()


func test_sprout_ironman_and_version() -> void:
	var m = _manager("sprout")
	var s = Sprout.new(123)
	s.tick = 77
	s.rng.randf("combat")
	check(m.save_sprout(s), "saved")
	var back = m.load_sprout()
	check(back != null, "loaded")
	eq(back.state_hash(), s.state_hash(), "identical state")
	check(not m.has_sprout(), "file consumed on load (no save-scum)")
	var d: Dictionary = s.to_dict()
	d["gen_version"] = 0
	check(Sprout.from_dict(d) == null, "old generator version refused")
	m.free()


func test_disabled_writes_nothing() -> void:
	var m = _manager("disabled")
	m.disabled = true
	check(not m.save_campaign(_campaign("x")), "refused")
	check(not FileAccess.file_exists(m.campaign_path()), "no file")
	m.free()


func test_settings_round_trip() -> void:
	var m = _manager("settings")
	var cfg: ConfigFile = m.default_settings()
	cfg.set_value("video", "ui_scale", 1.25)
	check(m.save_settings(cfg), "saved")
	check(m.save_settings(cfg), "saved twice (backup path)")
	eq(float(m.load_settings().get_value("video", "ui_scale")), 1.25, "ui scale")
	eq(float(m.load_settings().get_value("audio", "voice")), 0.9, "defaults filled")
	m.free()
