extends Node

class_name NationManager

var nations: Dictionary = {}
var province_to_nation: Dictionary = {}

func _init() -> void:
	_load_default_nations()

func _load_default_nations() -> void:
	nations = {
		"ES": {"id": "ES", "name": "Spain", "color": Color.from_rgba8(234, 175, 12, 200), "provinces": []},
		"PT": {"id": "PT", "name": "Portugal", "color": Color.from_rgba8(0, 140, 83, 200), "provinces": []},
		"NEUTRAL": {"id": "NEUTRAL", "name": "Neutral", "color": Color.from_rgba8(220, 220, 220, 0), "provinces": []}
	}
	_rebuild_province_index()

func _rebuild_province_index() -> void:
	province_to_nation.clear()
	for nation_id in nations.keys():
		var nation_data: Dictionary = nations[nation_id]
		var nation_provinces: Array = nation_data.get("provinces", [])
		for gid_value in nation_provinces:
			var gid: String = str(gid_value)
			if gid != "":
				province_to_nation[gid] = nation_id

func load_from_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("No se pudo abrir %s" % path)
		_load_default_nations()
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Formato invalido en %s" % path)
		_load_default_nations()
		return

	nations.clear()
	for nation_value in parsed:
		if typeof(nation_value) != TYPE_DICTIONARY:
			continue

		var nation_data: Dictionary = nation_value
		var nation_id: String = str(nation_data.get("id", ""))
		if nation_id == "":
			continue

		var color_data: Array = nation_data.get("color", [220, 220, 220])
		var r: int = int(color_data[0] if color_data.size() > 0 else 220)
		var g: int = int(color_data[1] if color_data.size() > 1 else 220)
		var b: int = int(color_data[2] if color_data.size() > 2 else 220)
		var provinces: Array = nation_data.get("provinces", [])

		nations[nation_id] = {
			"id": nation_id,
			"name": str(nation_data.get("name", nation_id)),
			"color": Color.from_rgba8(r, g, b, 200),
			"provinces": provinces.duplicate(true)
		}

	if not nations.has("NEUTRAL"):
		nations["NEUTRAL"] = {
			"id": "NEUTRAL",
			"name": "Neutral",
			"color": Color.from_rgba8(220, 220, 220, 0),
			"provinces": []
		}

	_rebuild_province_index()

func save_to_file(path: String) -> bool:
	var out: Array = []
	for nation_id in nations.keys():
		var nation_data: Dictionary = nations[nation_id]
		var color: Color = nation_data.get("color", Color.from_rgba8(220, 220, 220, 200))
		out.append({
			"id": nation_id,
			"name": str(nation_data.get("name", nation_id)),
			"color": [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0))],
			"provinces": nation_data.get("provinces", []).duplicate(true)
		})

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("No se pudo abrir para escribir: %s" % path)
		return false

	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	return true

func add_nation(id: String, nation_name: String, color: Color) -> void:
	nations[id] = {"id": id, "name": nation_name, "color": color, "provinces": []}
	_rebuild_province_index()

func get_nation_color(id: String) -> Color:
	if nations.has(id):
		return nations[id]["color"]
	return Color(1, 1, 1, 0)

func get_nation_name(id: String) -> String:
	if nations.has(id):
		return nations[id]["name"]
	return "Unknown"

func has_nation(id: String) -> bool:
	return nations.has(id)

func get_province_owner(gid: String) -> Variant:
	if province_to_nation.has(gid):
		return province_to_nation[gid]
	return null

func set_province_owner(gid: String, owner_id: String) -> void:
	var previous_owner: Variant = get_province_owner(gid)
	if previous_owner != null and nations.has(previous_owner):
		var previous_provinces: Array = nations[previous_owner].get("provinces", [])
		previous_provinces.erase(gid)
		nations[previous_owner]["provinces"] = previous_provinces

	if owner_id == "" or not nations.has(owner_id):
		province_to_nation.erase(gid)
		return

	var new_provinces: Array = nations[owner_id].get("provinces", [])
	if not new_provinces.has(gid):
		new_provinces.append(gid)
	nations[owner_id]["provinces"] = new_provinces
	province_to_nation[gid] = owner_id
