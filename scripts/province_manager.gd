extends Node

# patch: force reload timestamp (2026-03-31)

# ProvinceManager: carga provincias, mantiene mapping color->gid y propietario por gid
class_name ProvinceManager

var provinces_by_gid: Dictionary = {} # gid -> data (nombre, color, owner)
var color_to_gid: Dictionary = {} # Color -> gid
var rgb_to_gid: Dictionary = {} # int rgb -> gid

func _rgb_key_from_ints(r: int, g: int, b: int) -> int:
	return (r << 16) | (g << 8) | b

func _rgb_key_from_color(col: Color) -> int:
	var r: int = clampi(int(round(col.r * 255.0)), 0, 255)
	var g: int = clampi(int(round(col.g * 255.0)), 0, 255)
	var b: int = clampi(int(round(col.b * 255.0)), 0, 255)
	return _rgb_key_from_ints(r, g, b)

func load_from_file(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("No se pudo abrir %s" % path)
		return
	var txt: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	var data: Variant = null
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		if parsed.error == OK:
			data = parsed.result
		else:
			push_error("Error parseando %s: %s" % [path, parsed.get("error_string", "error desconocido")])
	else:
		data = parsed

	if data == null:
		f.close()
		return

	provinces_by_gid.clear()
	color_to_gid.clear()
	rgb_to_gid.clear()

	# Guardamos tanto el acceso por gid como el acceso por color para resolver el mapa rapido.
	for p in data:
		var gid: String = p.get("gid", "")
		var nombre: String = p.get("nombre", "")
		var col_arr: Array = p.get("color", [])
		var r: int = int(col_arr[0] if col_arr.size() > 0 else 0)
		var g: int = int(col_arr[1] if col_arr.size() > 1 else 0)
		var b: int = int(col_arr[2] if col_arr.size() > 2 else 0)
		var col: Color = Color.from_rgba8(r, g, b, 255)
		var owner_id: Variant = null
		if typeof(p) == TYPE_DICTIONARY and p.has("owner"):
			owner_id = p.get("owner")
		var province_entry: Dictionary = p.duplicate(true)
		province_entry["gid"] = gid
		province_entry["nombre"] = nombre
		province_entry["color"] = col
		province_entry["owner"] = owner_id
		provinces_by_gid[gid] = province_entry
		color_to_gid[col] = gid
		rgb_to_gid[_rgb_key_from_ints(r, g, b)] = gid

	f.close()

func get_gid_by_color(col: Color, tolerancia: float = 0.01) -> String:
	var exact_gid: String = rgb_to_gid.get(_rgb_key_from_color(col), "")
	if exact_gid != "":
		return exact_gid

	# Fallback con tolerancia por si el color recibido no coincide exactamente.
	for key_color in color_to_gid.keys():
		if abs(key_color.r - col.r) < tolerancia and abs(key_color.g - col.g) < tolerancia and abs(key_color.b - col.b) < tolerancia:
			return color_to_gid[key_color]
	return ""

func set_province_owner(gid: String, owner_id: String) -> void:
	if provinces_by_gid.has(gid):
		provinces_by_gid[gid]["owner"] = owner_id

func save_to_file(path: String) -> bool:
	var arr: Array = []
	for gid in provinces_by_gid.keys():
		var p: Dictionary = provinces_by_gid[gid]
		var col: Color = p.get("color")
		var r: int = int(col.r * 255)
		var g: int = int(col.g * 255)
		var b: int = int(col.b * 255)
		var entry: Dictionary = p.duplicate(true)
		entry["gid"] = p.get("gid", "")
		entry["nombre"] = p.get("nombre", "")
		entry["color"] = [r, g, b]
		if p.get("owner", null) == null:
			entry.erase("owner")
		arr.append(entry)

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("No se pudo abrir para escribir: %s" % path)
		return false
	var json_text: String = JSON.stringify(arr)
	f.store_string(json_text)
	f.close()
	return true

func get_province_owner(gid: String) -> Variant:
	if provinces_by_gid.has(gid):
		return provinces_by_gid[gid].get("owner", null)
	return null

func get_mining_building_limit(gid: String, building_id: String) -> int:
	if not provinces_by_gid.has(gid):
		return 0
	var buildings_data: Variant = provinces_by_gid[gid].get("buildings", {})
	if typeof(buildings_data) != TYPE_DICTIONARY:
		return 0
	var mining_limits: Variant = buildings_data.get("mining_limits", {})
	if typeof(mining_limits) != TYPE_DICTIONARY:
		return 0
	return int(mining_limits.get(building_id, 0))

func get_mining_building_count(gid: String, building_id: String) -> int:
	if not provinces_by_gid.has(gid):
		return 0
	var buildings_data: Variant = provinces_by_gid[gid].get("buildings", {})
	if typeof(buildings_data) != TYPE_DICTIONARY:
		return 0
	var entries: Variant = buildings_data.get("entries", [])
	if typeof(entries) != TYPE_ARRAY:
		return 0
	var count: int = 0
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			if str(entry.get("id", "")) == building_id and str(entry.get("category", "")) == "mining":
				count += 1
		elif str(entry) == building_id:
			count += 1
	return count

func can_build_mining_building(gid: String, building_id: String) -> bool:
	return get_mining_building_count(gid, building_id) < get_mining_building_limit(gid, building_id)

func add_mining_building(gid: String, building_id: String) -> bool:
	if not provinces_by_gid.has(gid):
		return false
	if not can_build_mining_building(gid, building_id):
		return false
	var buildings_data: Variant = provinces_by_gid[gid].get("buildings", {})
	if typeof(buildings_data) != TYPE_DICTIONARY:
		buildings_data = {}
	if not buildings_data.has("entries") or typeof(buildings_data.get("entries")) != TYPE_ARRAY:
		buildings_data["entries"] = []
	var entries: Array = buildings_data["entries"]
	entries.append({
		"id": building_id,
		"category": "mining"
	})
	buildings_data["entries"] = entries
	provinces_by_gid[gid]["buildings"] = buildings_data
	return true

func recolor_overlay_from_color_map(color_map: Texture2D, nation_manager: Node) -> Image:
	# Crea un Image donde cada pixel de la color_map se reemplaza por el color de la nacion propietaria.
	var img: Image = color_map.get_image()
	var out: Image = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			var gid: String = get_gid_by_color(c)
			if gid != "" and provinces_by_gid.has(gid) and provinces_by_gid[gid]["owner"]:
				var owner_id: Variant = provinces_by_gid[gid]["owner"]
				var ncolor: Color = Color(1, 1, 1, 0)
				if nation_manager and nation_manager.has_method("get_nation_color"):
					ncolor = nation_manager.get_nation_color(owner_id)
				out.set_pixel(x, y, Color(ncolor.r, ncolor.g, ncolor.b, 0.7))
			else:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out

func build_selection_overlay(color_map: Texture2D, selected_gid: String, overlay_color: Color = Color(1, 1, 1, 1)) -> Image:
	# Construye una mascara con solo la provincia seleccionada para dibujarla por encima del mapa.
	var img: Image = color_map.get_image()
	var out: Image = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var gid: String = get_gid_by_color(img.get_pixel(x, y))
			if gid == selected_gid:
				out.set_pixel(x, y, overlay_color)
			else:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out
