extends Control

const TARGET_SCENE_PATH := "res://scenes/Main.tscn"

func _ready() -> void:
	ResourceLoader.load_threaded_request(TARGET_SCENE_PATH)

func _process(_delta: float) -> void:
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(TARGET_SCENE_PATH, progress)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed_scene := ResourceLoader.load_threaded_get(TARGET_SCENE_PATH)
		if packed_scene is PackedScene:
			get_tree().change_scene_to_packed(packed_scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("No se pudo cargar la escena principal: %s" % TARGET_SCENE_PATH)
