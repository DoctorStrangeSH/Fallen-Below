extends Node
## Localization. Registered as autoload "Loc".
## Keys are the English source strings; translations live in res://locale/<lang>.json
## ({"English text": "Перевод"}). Missing keys fall back to English.
##   Loc.t("Day %d") % day
## The language is saved in Meta; on the very first launch it follows the system locale.

const LANGUAGES := {"en": "English", "ru": "Русский"}

var lang := "en"
var table := {}


func _ready() -> void:
	var saved: String = Meta.language
	if saved == "":
		saved = "ru" if OS.get_locale_language() == "ru" else "en"
	set_language(saved, false)


func set_language(code: String, save: bool = true) -> void:
	if not LANGUAGES.has(code):
		code = "en"
	lang = code
	table = {}
	if code != "en":
		var path := "res://locale/%s.json" % code
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				table = parsed
	Meta.language = code
	if save:
		Meta.save_game()


func t(text: String) -> String:
	if table.is_empty():
		return text
	var v = table.get(text)
	return text if v == null or str(v) == "" else str(v)


## Cycles to the next language.
func next_language() -> void:
	var codes: Array = LANGUAGES.keys()
	set_language(codes[(codes.find(lang) + 1) % codes.size()])
