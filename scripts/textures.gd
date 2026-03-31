extends Node2D

# patch: force reload timestamp (2026-03-31)

@onready var white_map: TextureRect = $whiteMap
@onready var color_map: TextureRect = $colorMap

# Overlay donde pintaremos colores por propietario
var owner_overlay: TextureRect = null

# Managers (se crearan en tiempo de ejecucion)
var province_manager: ProvinceManager = null
var nation_manager: NationManager = null

var provincias: Dictionary = {}
var provincias_por_rgb: Dictionary = {}
var color_map_image: Image = null

func _rgb_key(r: int, g: int, b: int) -> int:
	return (r << 16) | (g << 8) | b

func _get_province_info_at_pixel(x: int, y: int) -> Variant:
	if color_map_image == null:
		return null
	if x < 0 or y < 0 or x >= color_map_image.get_width() or y >= color_map_image.get_height():
		return null

	var c: Color = color_map_image.get_pixel(x, y)
	var r: int = int(round(c.r * 255.0))
	var g: int = int(round(c.g * 255.0))
	var b: int = int(round(c.b * 255.0))
	var info = provincias_por_rgb.get(_rgb_key(r, g, b), null)
	if info != null:
		return {"info": info, "rgb": [r, g, b]}

	if province_manager != null:
		var gid_tolerante := province_manager.get_gid_by_color(c)
		if gid_tolerante != "" and province_manager.provinces_by_gid.has(gid_tolerante):
			return {"info": province_manager.provinces_by_gid[gid_tolerante], "rgb": [r, g, b]}

	return null

func _get_nearby_province_info(x: int, y: int, radius: int = 3) -> Variant:
	var direct = _get_province_info_at_pixel(x, y)
	if direct != null:
		return direct

	for dist in range(1, radius + 1):
		for oy in range(-dist, dist + 1):
			for ox in range(-dist, dist + 1):
				if abs(ox) != dist and abs(oy) != dist:
					continue
				var candidate = _get_province_info_at_pixel(x + ox, y + oy)
				if candidate != null:
					return candidate

	return null

# Funcion para comparar colores con tolerancia
func colores_iguales(c1: Color, c2: Color, tolerancia: float = 0.01) -> bool:
	return abs(c1.r - c2.r) < tolerancia \
		and abs(c1.g - c2.g) < tolerancia \
		and abs(c1.b - c2.b) < tolerancia

func _ready():
	# Cargar provincias desde JSON externo (usar fichero con GID)
	var file = FileAccess.open("res://data/provinces_with_gid.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var parse_result = JSON.parse_string(json_text)
		var data = null
		if typeof(parse_result) == TYPE_DICTIONARY and parse_result.has("error"):
			if parse_result.error == OK:
				data = parse_result.result
			else:
				push_error("Error al parsear provinces_with_gid.json: %s" % parse_result.get("error_string", "error desconocido"))
		else:
			data = parse_result

		if data != null:
			for p in data:
				var r = int(p["color"][0])
				var g = int(p["color"][1])
				var b = int(p["color"][2])
				var color = Color.from_rgba8(r, g, b, 255)
				var rgb_key = (r << 16) | (g << 8) | b
				var province_info = {
					"gid": p.get("gid", ""),
					"nombre": p.get("nombre", "")
				}
				provincias[color] = province_info
				provincias_por_rgb[rgb_key] = province_info
		file.close()
	else:
		push_error("No se encontro provinces_with_gid.json en res://data")

	# Crear y configurar managers
	province_manager = ProvinceManager.new()
	add_child(province_manager)
	province_manager.load_from_file("res://data/provinces_with_gid.json")

	nation_manager = NationManager.new()
	add_child(nation_manager)

	if color_map.texture != null:
		color_map_image = color_map.texture.get_image()

	# Crear overlay si no existe
	if owner_overlay == null:
		owner_overlay = TextureRect.new()
		owner_overlay.name = "ownerOverlay"
		owner_overlay.anchor_left = white_map.anchor_left
		owner_overlay.anchor_top = white_map.anchor_top
		owner_overlay.anchor_right = white_map.anchor_right
		owner_overlay.anchor_bottom = white_map.anchor_bottom
		owner_overlay.size_flags_horizontal = white_map.size_flags_horizontal
		owner_overlay.size_flags_vertical = white_map.size_flags_vertical
		owner_overlay.position = white_map.position
		owner_overlay.size = white_map.size
		owner_overlay.expand = true
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		owner_overlay.material = mat
		owner_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(owner_overlay)

	# Diferir la generacion del overlay para no bloquear el primer frame.
	call_deferred("_refresh_owner_overlay")

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var pos_local: Vector2 = white_map.get_local_mouse_position()
		var tex_size: Vector2 = color_map.texture.get_size()

		var x: int = int(pos_local.x * tex_size.x / white_map.size.x)
		var y: int = int(pos_local.y * tex_size.y / white_map.size.y)

		if x < 0 or y < 0 or x >= tex_size.x or y >= tex_size.y:
			return

		var result = _get_nearby_province_info(x, y, 4)
		if result != null:
			var info = result.get("info", {})
			var rgb = result.get("rgb", [0, 0, 0])
			var gid = info.get("gid", "(sin gid)")
			var nombre = info.get("nombre", "(sin nombre)")
			print("(R:%d, G:%d, B:%d) -- Provincia: %s (%s)" % [rgb[0], rgb[1], rgb[2], nombre, gid])
		else:
			print("Provincia no identificada cerca de (%d, %d)" % [x, y])

func _refresh_owner_overlay() -> void:
	# Genera la textura overlay a partir del color_map y los datos de owner
	if province_manager == null or nation_manager == null:
		return
	if color_map.texture == null:
		return

	var out_img: Image = province_manager.recolor_overlay_from_color_map(color_map.texture, nation_manager)
	var tex := ImageTexture.create_from_image(out_img)
	if owner_overlay:
		owner_overlay.texture = tex

func set_province_owner_by_gid(gid: String, owner_id: String) -> void:
	if province_manager:
		province_manager.set_province_owner(gid, owner_id)
		_refresh_owner_overlay()
		var save_ok = province_manager.save_to_file("res://data/provinces_with_gid.json")
		if not save_ok:
			push_warning("No se pudo guardar el estado de provincias en JSON")
