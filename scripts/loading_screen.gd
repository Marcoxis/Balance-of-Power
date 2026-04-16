extends Control

const TARGET_SCENE_PATH: String = "res://scenes/Main.tscn"
const TIPS_PATH: String = "res://data/loading_tips.json"

@onready var progress_bar: ProgressBar = $CenterContainer/Content/ProgressBar
@onready var progress_label: Label = $CenterContainer/Content/ProgressLabel
@onready var tip_label: Label = $CenterContainer/Content/TipPanel/TipMargin/TipLabel
@onready var loading_label: Label = $CenterContainer/Content/LoadingLabel

var tip_index: int = 0
var tip_elapsed: float = 0.0
var total_elapsed: float = 0.0
var scene_changed: bool = false
var tips: Array = []

const MIN_LOADING_TIME: float = 0.75

# Starts threaded scene loading and prepares the rotating tip text.
# Inicia la carga en hilo de la escena y prepara el texto rotatorio de consejos.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)
	tips = _load_tips()
	tip_label.text = Localization.translate_tip(tips[tip_index])
	ResourceLoader.load_threaded_request(TARGET_SCENE_PATH)

# Updates the loading bar, rotates tips, and switches scenes when ready.
# Actualiza la barra de carga, rota los consejos y cambia de escena cuando est? lista.
func _process(delta: float) -> void:
	total_elapsed += delta
	tip_elapsed += delta
	if tip_elapsed >= 1.4:
		tip_elapsed = 0.0
		tip_index = (tip_index + 1) % tips.size()
		tip_label.text = Localization.translate_tip(tips[tip_index])

	if scene_changed:
		return

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(TARGET_SCENE_PATH, progress)
	var progress_value: float = 0.0
	if not progress.is_empty():
		progress_value = clampf(float(progress[0]), 0.0, 1.0)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_bar.value = maxf(progress_bar.value, progress_value * 100.0)
		progress_label.text = Localization.t("loading.resources", [int(round(progress_bar.value))])
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		progress_bar.value = 100.0
		progress_label.text = Localization.t("loading.entering")
		if total_elapsed >= MIN_LOADING_TIME:
			var packed_scene: Resource = ResourceLoader.load_threaded_get(TARGET_SCENE_PATH)
			if packed_scene is PackedScene:
				scene_changed = true
				get_tree().change_scene_to_packed(packed_scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		progress_label.text = Localization.t("loading.error")
		push_error("No se pudo cargar la escena principal: %s" % TARGET_SCENE_PATH)
	else:
		progress_bar.value = maxf(progress_bar.value, 5.0)
		progress_label.text = Localization.t("loading.preparing")

# Loads gameplay tips from JSON and falls back to one default tip.
# Carga consejos de juego desde JSON y usa un consejo por defecto si falla.
func _load_tips() -> Array:
	var file: FileAccess = FileAccess.open(TIPS_PATH, FileAccess.READ)
	if not file:
		return [Localization.t("loading.fallback_tip")]

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
		return [Localization.t("loading.fallback_tip")]

	var loaded_tips: Array = []
	for entry in parsed:
		loaded_tips.append(entry)

	if loaded_tips.is_empty():
		loaded_tips.append(Localization.t("loading.fallback_tip"))
	return loaded_tips

# Refreshes translated labels after a language change.
# Refresca las etiquetas traducidas despu?s de un cambio de idioma.
func _on_language_changed(_language_code: String) -> void:
	if not tips.is_empty():
		tip_label.text = Localization.translate_tip(tips[tip_index])
	loading_label.text = Localization.t("loading.title")
