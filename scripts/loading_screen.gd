extends Control

const TARGET_SCENE_PATH: String = "res://scenes/Main.tscn"
const TIPS_PATH: String = "res://data/loading_tips.json"

@onready var progress_bar: ProgressBar = $CenterContainer/Content/ProgressBar
@onready var progress_label: Label = $CenterContainer/Content/ProgressLabel
@onready var tip_label: Label = $CenterContainer/Content/TipPanel/TipMargin/TipLabel

var tip_index: int = 0
var tip_elapsed: float = 0.0
var total_elapsed: float = 0.0
var scene_changed: bool = false
var tips: Array[String] = []

const MIN_LOADING_TIME: float = 0.75

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tips = _load_tips()
	tip_label.text = tips[tip_index]
	ResourceLoader.load_threaded_request(TARGET_SCENE_PATH)

func _process(delta: float) -> void:
	total_elapsed += delta
	tip_elapsed += delta
	if tip_elapsed >= 1.4:
		tip_elapsed = 0.0
		tip_index = (tip_index + 1) % tips.size()
		tip_label.text = tips[tip_index]

	if scene_changed:
		return

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(TARGET_SCENE_PATH, progress)
	var progress_value: float = 0.0
	if not progress.is_empty():
		progress_value = clampf(float(progress[0]), 0.0, 1.0)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_bar.value = maxf(progress_bar.value, progress_value * 100.0)
		progress_label.text = "Cargando recursos... %d%%" % int(round(progress_bar.value))
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		progress_bar.value = 100.0
		progress_label.text = "Entrando en partida..."
		if total_elapsed >= MIN_LOADING_TIME:
			var packed_scene: Resource = ResourceLoader.load_threaded_get(TARGET_SCENE_PATH)
			if packed_scene is PackedScene:
				scene_changed = true
				get_tree().change_scene_to_packed(packed_scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		progress_label.text = "Error al cargar la partida"
		push_error("No se pudo cargar la escena principal: %s" % TARGET_SCENE_PATH)
	else:
		progress_bar.value = maxf(progress_bar.value, 5.0)
		progress_label.text = "Preparando recursos..."

func _load_tips() -> Array[String]:
	var file: FileAccess = FileAccess.open(TIPS_PATH, FileAccess.READ)
	if not file:
		return ["Consejo: preparate para gobernar con paciencia y observa el mapa con atencion."]

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
		return ["Consejo: preparate para gobernar con paciencia y observa el mapa con atencion."]

	var loaded_tips: Array[String] = []
	for entry in parsed:
		loaded_tips.append(str(entry))

	if loaded_tips.is_empty():
		loaded_tips.append("Consejo: preparate para gobernar con paciencia y observa el mapa con atencion.")
	return loaded_tips
