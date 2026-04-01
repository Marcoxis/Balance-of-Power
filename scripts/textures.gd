extends Node2D

# patch: force reload timestamp (2026-03-31)

@onready var white_map: TextureRect = $whiteMap
@onready var color_map: TextureRect = $colorMap

# Overlay donde pintaremos colores por propietario
var owner_overlay: TextureRect = null
var selection_overlay: TextureRect = null
var ui_layer: CanvasLayer = null
var province_name_label: Label = null

# Managers (se crearan en tiempo de ejecucion)
var province_manager: ProvinceManager = null
var nation_manager: NationManager = null

var provincias: Dictionary = {}
var provincias_por_rgb: Dictionary = {}
var color_map_image: Image = null
var province_pixels_by_gid: Dictionary = {}
var owner_overlay_image: Image = null
var selection_overlay_image: Image = null
var previous_selected_gid := ""
var selected_province_gid := ""
var blink_time := 0.0

# Ajustes visuales del parpadeo de la provincia seleccionada.
const SELECTION_BLINK_SPEED := 3.2
const SELECTION_MIN_ALPHA := 0.38
const SELECTION_MAX_ALPHA := 0.62

func _rgb_key(r: int, g: int, b: int) -> int:
	return (r << 16) | (g << 8) | b

func _get_exact_gid_at_pixel(x: int, y: int) -> String:
	if color_map_image == null:
		return ""

	var c: Color = color_map_image.get_pixel(x, y)
	var r: int = int(round(c.r * 255.0))
	var g: int = int(round(c.g * 255.0))
	var b: int = int(round(c.b * 255.0))
	return province_manager.rgb_to_gid.get(_rgb_key(r, g, b), "")

func _build_color_lookup_cache() -> Dictionary:
	var color_lookup: Dictionary = {}
	if color_map_image == null or province_manager == null:
		return color_lookup

	var width := color_map_image.get_width()
	var height := color_map_image.get_height()

	for y in range(height):
		for x in range(width):
			var c: Color = color_map_image.get_pixel(x, y)
			var r: int = int(round(c.r * 255.0))
			var g: int = int(round(c.g * 255.0))
			var b: int = int(round(c.b * 255.0))
			var rgb_key := _rgb_key(r, g, b)
			if color_lookup.has(rgb_key):
				continue

			var gid: String = province_manager.rgb_to_gid.get(rgb_key, "")
			if gid == "":
				gid = province_manager.get_gid_by_color(c)
			color_lookup[rgb_key] = gid

	return color_lookup

func _get_province_info_at_pixel(x: int, y: int) -> Variant:
	if color_map_image == null:
		return null
	if x < 0 or y < 0 or x >= color_map_image.get_width() or y >= color_map_image.get_height():
		return null

	# Primero intentamos resolver por color exacto; si falla, usamos el lookup tolerante del manager.
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

	# Si el click cae en el borde, buscamos unos pocos pixeles alrededor.
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
	# Crear y configurar managers
	province_manager = ProvinceManager.new()
	add_child(province_manager)
	province_manager.load_from_file("res://data/provinces_with_gid.json")

	nation_manager = NationManager.new()
	add_child(nation_manager)

	# Reutilizamos la carga ya hecha por ProvinceManager para no parsear el JSON dos veces.
	provincias.clear()
	provincias_por_rgb.clear()
	for gid in province_manager.provinces_by_gid.keys():
		var province_data: Dictionary = province_manager.provinces_by_gid[gid]
		var color: Color = province_data.get("color", Color.BLACK)
		var rgb_key := _rgb_key(
			int(round(color.r * 255.0)),
			int(round(color.g * 255.0)),
			int(round(color.b * 255.0))
		)
		var province_info := {
			"gid": province_data.get("gid", ""),
			"nombre": province_data.get("nombre", "")
		}
		provincias[color] = province_info
		provincias_por_rgb[rgb_key] = province_info

	if color_map.texture != null:
		color_map_image = color_map.texture.get_image()
		_build_province_pixel_cache()

	# Overlay persistente para pintar el color del propietario sobre el mapa base.
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

	if selection_overlay == null:
		# Overlay independiente para la provincia seleccionada; se anima cambiando su alpha.
		selection_overlay = TextureRect.new()
		selection_overlay.name = "selectionOverlay"
		selection_overlay.anchor_left = white_map.anchor_left
		selection_overlay.anchor_top = white_map.anchor_top
		selection_overlay.anchor_right = white_map.anchor_right
		selection_overlay.anchor_bottom = white_map.anchor_bottom
		selection_overlay.position = white_map.position
		selection_overlay.size = white_map.size
		selection_overlay.expand = true
		selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_overlay.self_modulate = Color(1, 1, 1, 0)
		add_child(selection_overlay)

	_create_selection_ui()

	# Generamos la textura de propietarios una vez, ya apoyados en la cache de pixeles.
	call_deferred("_refresh_owner_overlay")

func _process(delta: float) -> void:
	if selection_overlay == null or selected_province_gid == "":
		return

	# El parpadeo se consigue oscilando la opacidad con una senoide.
	blink_time += delta * SELECTION_BLINK_SPEED
	var t := (sin(blink_time) + 1.0) * 0.5
	var alpha := lerpf(SELECTION_MIN_ALPHA, SELECTION_MAX_ALPHA, t)
	selection_overlay.self_modulate = Color(1, 1, 1, alpha)

func _build_province_pixel_cache() -> void:
	if color_map_image == null or province_manager == null:
		return

	province_pixels_by_gid.clear()
	var width: int = color_map_image.get_width()
	var height: int = color_map_image.get_height()
	var color_lookup: Dictionary = _build_color_lookup_cache()

	for y in range(height):
		for x in range(width):
			var c: Color = color_map_image.get_pixel(x, y)
			var r: int = int(round(c.r * 255.0))
			var g: int = int(round(c.g * 255.0))
			var b: int = int(round(c.b * 255.0))
			var gid: String = color_lookup.get(_rgb_key(r, g, b), "")
			if gid == "":
				continue
			if not province_pixels_by_gid.has(gid):
				province_pixels_by_gid[gid] = []
			province_pixels_by_gid[gid].append(Vector2i(x, y))

	owner_overlay_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	selection_overlay_image = Image.create(width, height, false, Image.FORMAT_RGBA8)

func _create_selection_ui() -> void:
	# La UI vive en un CanvasLayer para no moverse con la camara.
	ui_layer = CanvasLayer.new()
	ui_layer.name = "selectionUiLayer"
	add_child(ui_layer)

	var margin := MarginContainer.new()
	margin.name = "selectionMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_left", 24)
	ui_layer.add_child(margin)

	province_name_label = Label.new()
	province_name_label.name = "provinceNameLabel"
	province_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	province_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	province_name_label.text = ""
	province_name_label.self_modulate = Color(1, 1, 1, 0.95)
	province_name_label.add_theme_font_size_override("font_size", 28)
	province_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	province_name_label.add_theme_constant_override("outline_size", 6)
	margin.add_child(province_name_label)

func _set_selected_province(gid: String, nombre: String) -> void:
	selected_province_gid = gid
	blink_time = 0.0

	if province_name_label != null:
		province_name_label.text = nombre

	if selection_overlay == null or selection_overlay_image == null:
		return

	# Reutilizamos la misma imagen y solo limpiamos/pintamos los pixeles de la seleccion anterior y actual.
	if previous_selected_gid != "" and province_pixels_by_gid.has(previous_selected_gid):
		for pixel: Vector2i in province_pixels_by_gid[previous_selected_gid]:
			selection_overlay_image.set_pixel(pixel.x, pixel.y, Color(0, 0, 0, 0))

	if province_pixels_by_gid.has(gid):
		for pixel: Vector2i in province_pixels_by_gid[gid]:
			selection_overlay_image.set_pixel(pixel.x, pixel.y, Color(1, 1, 1, 1))

	selection_overlay.texture = ImageTexture.create_from_image(selection_overlay_image)
	selection_overlay.self_modulate = Color(1, 1, 1, SELECTION_MAX_ALPHA)
	previous_selected_gid = gid

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
			# Seleccion visual + nombre en UI.
			_set_selected_province(gid, nombre)
			print("(R:%d, G:%d, B:%d) -- Provincia: %s (%s)" % [rgb[0], rgb[1], rgb[2], nombre, gid])
		else:
			print("Provincia no identificada cerca de (%d, %d)" % [x, y])

func _refresh_owner_overlay() -> void:
	if province_manager == null or nation_manager == null:
		return
	if owner_overlay == null or owner_overlay_image == null:
		return

	owner_overlay_image.fill(Color(0, 0, 0, 0))

	for gid in province_pixels_by_gid.keys():
		var owner_id = province_manager.get_province_owner(gid)
		if owner_id == null or owner_id == "":
			continue

		var nation_color := nation_manager.get_nation_color(owner_id)
		var overlay_color := Color(nation_color.r, nation_color.g, nation_color.b, 0.7)
		for pixel: Vector2i in province_pixels_by_gid[gid]:
			owner_overlay_image.set_pixel(pixel.x, pixel.y, overlay_color)

	owner_overlay.texture = ImageTexture.create_from_image(owner_overlay_image)

func set_province_owner_by_gid(gid: String, owner_id: String) -> void:
	if province_manager:
		province_manager.set_province_owner(gid, owner_id)
		_refresh_owner_overlay()
		var save_ok = province_manager.save_to_file("res://data/provinces_with_gid.json")
		if not save_ok:
			push_warning("No se pudo guardar el estado de provincias en JSON")
