extends Node

signal language_changed(language_code: String)

const DEFAULT_LANGUAGE: String = "en"
const LOCALIZATION_PATH: String = "res://data/localization.json"

var current_language: String = DEFAULT_LANGUAGE
var translations: Dictionary = {}

func _ready() -> void:
	_load_translations()
	current_language = DEFAULT_LANGUAGE

func _load_translations() -> void:
	var file: FileAccess = FileAccess.open(LOCALIZATION_PATH, FileAccess.READ)
	if not file:
		push_error("No se pudo abrir %s" % LOCALIZATION_PATH)
		translations = {}
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Formato invalido en %s" % LOCALIZATION_PATH)
		translations = {}
		return

	translations = parsed

func set_language(language_code: String) -> void:
	if not translations.has(language_code):
		return
	if current_language == language_code:
		return
	current_language = language_code
	emit_signal("language_changed", current_language)

func get_language() -> String:
	return current_language

func get_available_languages() -> Array[String]:
	var languages: Array[String] = []
	for key in translations.keys():
		languages.append(str(key))
	languages.sort()
	return languages

func t(key: String, args: Array = []) -> String:
	var language_table: Dictionary = translations.get(current_language, translations.get(DEFAULT_LANGUAGE, {}))
	var fallback_table: Dictionary = translations.get(DEFAULT_LANGUAGE, {})
	var value: String = str(language_table.get(key, fallback_table.get(key, key)))
	if not args.is_empty():
		return value % args
	return value

func get_month_name(month: int) -> String:
	return t("months.%d" % clampi(month, 1, 12))

func translate_tip(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		var tip_data: Dictionary = entry
		if tip_data.has(current_language):
			return str(tip_data[current_language])
		if tip_data.has(DEFAULT_LANGUAGE):
			return str(tip_data[DEFAULT_LANGUAGE])
		for key in tip_data.keys():
			return str(tip_data[key])
	if typeof(entry) == TYPE_STRING:
		return str(entry)
	return t("loading.fallback_tip")
