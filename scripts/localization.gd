extends Node

signal language_changed(language_code: String)

const DEFAULT_LANGUAGE: String = "en"
const LOCALIZATION_PATH: String = "res://data/lenguages.json"
const LEGACY_LOCALIZATION_PATH: String = "res://data/localization.json"

var current_language: String = DEFAULT_LANGUAGE
var translations: Dictionary = {}

# Loads translations once and resets the active language to the default.
# Carga las traducciones una vez y reinicia el idioma activo al valor por defecto.
func _ready() -> void:
	_load_translations()
	current_language = DEFAULT_LANGUAGE

# Loads the translation table from the current file path, with a legacy fallback.
# Carga la tabla de traducci?n desde la ruta actual, con un fallback legado.
func _load_translations() -> void:
	var file: FileAccess = FileAccess.open(LOCALIZATION_PATH, FileAccess.READ)
	var resolved_path: String = LOCALIZATION_PATH
	if not file:
		file = FileAccess.open(LEGACY_LOCALIZATION_PATH, FileAccess.READ)
		resolved_path = LEGACY_LOCALIZATION_PATH
	if not file:
		push_error("No se pudo abrir %s ni %s" % [LOCALIZATION_PATH, LEGACY_LOCALIZATION_PATH])
		translations = {}
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Formato invalido en %s" % resolved_path)
		translations = {}
		return

	translations = parsed

# Switches the active language and notifies listeners.
# Cambia el idioma activo y notifica a los listeners.
func set_language(language_code: String) -> void:
	if not translations.has(language_code):
		return
	if current_language == language_code:
		return
	current_language = language_code
	emit_signal("language_changed", current_language)

# Returns the active language code.
# Devuelve el c?digo del idioma activo.
func get_language() -> String:
	return current_language

# Returns the list of languages available in the loaded file.
# Devuelve la lista de idiomas disponibles en el archivo cargado.
func get_available_languages() -> Array[String]:
	var languages: Array[String] = []
	for key in translations.keys():
		languages.append(str(key))
	languages.sort()
	return languages

# Resolves one translation key and formats optional arguments.
# Resuelve una clave de traducci?n y formatea argumentos opcionales.
func t(key: String, args: Array = []) -> String:
	var language_table: Dictionary = translations.get(current_language, translations.get(DEFAULT_LANGUAGE, {}))
	var fallback_table: Dictionary = translations.get(DEFAULT_LANGUAGE, {})
	var value: String = str(language_table.get(key, fallback_table.get(key, key)))
	if not args.is_empty():
		return value % args
	return value

# Returns the localized month name used by the in-game clock.
# Devuelve el nombre localizado del mes usado por el reloj del juego.
func get_month_name(month: int) -> String:
	return t("months.%d" % clampi(month, 1, 12))

# Resolves one loading tip from either a translated object or a plain string.
# Resuelve un consejo de carga desde un objeto traducido o una cadena simple.
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
