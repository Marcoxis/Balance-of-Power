extends Node


# Simple NationManager: guarda naciones y su color de visualización
class_name NationManager

var nations: Dictionary = {}

func _init():
	# Ejemplo: cargar algunas naciones por defecto (puedes cargarlas desde JSON después)
	nations = {
		"ES": {"name": "España", "color": Color.from_rgba8(234, 175, 12, 200)},
		"PT": {"name": "Portugal", "color": Color.from_rgba8(0, 140, 83, 200)},
		"NEUTRAL": {"name": "Neutral", "color": Color.from_rgba8(220, 220, 220, 0)}
	}

func add_nation(id: String, nation_name: String, color: Color) -> void:
	nations[id] = {"name": nation_name, "color": color}

func get_nation_color(id: String) -> Color:
	if nations.has(id):
		return nations[id]["color"]
	return Color(1,1,1,0)

func get_nation_name(id: String) -> String:
	if nations.has(id):
		return nations[id]["name"]
	return "Desconocido"

func has_nation(id: String) -> bool:
	return nations.has(id)
