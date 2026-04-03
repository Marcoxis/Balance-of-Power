extends Node2D

# patch: force reload timestamp (2026-03-31)

@onready var white_map: TextureRect = $whiteMap
@onready var color_map: TextureRect = $colorMap

# Overlay donde pintaremos colores por propietario
var owner_overlay: TextureRect = null
var selection_overlay: TextureRect = null
var ui_layer: CanvasLayer = null
var province_info_panel: PanelContainer = null
var province_info_title: Label = null
var province_info_population: Label = null
var province_info_owner: Label = null
var province_info_buildings: Label = null
var province_info_resources: Label = null
var province_info_extra: Label = null
var pause_menu_panel: PanelContainer = null
var province_info_dragging: bool = false
var province_info_drag_offset: Vector2 = Vector2.ZERO

# Managers (se crearan en tiempo de ejecucion)
var province_manager: ProvinceManager = null
var nation_manager: NationManager = null

var provincias: Dictionary = {}
var provincias_por_rgb: Dictionary = {}
var color_map_image: Image = null
var province_pixels_by_gid: Dictionary = {}
var owner_overlay_image: Image = null
var selection_overlay_image: Image = null
var previous_selected_gid: String = ""
var selected_province_gid: String = ""
var blink_time: float = 0.0

# Ajustes visuales del parpadeo de la provincia seleccionada.
const SELECTION_BLINK_SPEED: float = 3.2
const SELECTION_MIN_ALPHA: float = 0.38
const SELECTION_MAX_ALPHA: float = 0.62
const SEA_RGB_KEY: int = (172 << 16) | (201 << 8) | 233

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

	var width: int = color_map_image.get_width()
	var height: int = color_map_image.get_height()

	for y in range(height):
		for x in range(width):
			var c: Color = color_map_image.get_pixel(x, y)
			var r: int = int(round(c.r * 255.0))
			var g: int = int(round(c.g * 255.0))
			var b: int = int(round(c.b * 255.0))
			var rgb_key: int = _rgb_key(r, g, b)
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
	if _rgb_key(r, g, b) == SEA_RGB_KEY:
		return {"info": {"gid": "SEA", "nombre": "Mar", "owner": null}, "rgb": [r, g, b]}
	var info: Variant = provincias_por_rgb.get(_rgb_key(r, g, b), null)
	if info != null:
		return {"info": info, "rgb": [r, g, b]}

	if province_manager != null:
		var gid_tolerante: String = province_manager.get_gid_by_color(c)
		if gid_tolerante != "" and province_manager.provinces_by_gid.has(gid_tolerante):
			return {"info": province_manager.provinces_by_gid[gid_tolerante], "rgb": [r, g, b]}

	return null

func _get_nearby_province_info(x: int, y: int, radius: int = 3) -> Variant:
	var direct: Variant = _get_province_info_at_pixel(x, y)
	if direct != null:
		return direct

	# Si el click cae en el borde, buscamos unos pocos pixeles alrededor.
	for dist in range(1, radius + 1):
		for oy in range(-dist, dist + 1):
			for ox in range(-dist, dist + 1):
				if abs(ox) != dist and abs(oy) != dist:
					continue
				var candidate: Variant = _get_province_info_at_pixel(x + ox, y + oy)
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
		var rgb_key: int = _rgb_key(
			int(round(color.r * 255.0)),
			int(round(color.g * 255.0)),
			int(round(color.b * 255.0))
		)
		var province_info: Dictionary = {
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
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
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
	var t: float = (sin(blink_time) + 1.0) * 0.5
	var alpha: float = lerpf(SELECTION_MIN_ALPHA, SELECTION_MAX_ALPHA, t)
	selection_overlay.self_modulate = Color(1, 1, 1, alpha)

func _clamp_province_info_panel_position(target_position: Vector2) -> Vector2:
	if province_info_panel == null:
		return target_position

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = province_info_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = province_info_panel.get_combined_minimum_size()
	var max_x: float = maxf(0.0, viewport_size.x - panel_size.x)
	var max_y: float = maxf(0.0, viewport_size.y - panel_size.y)
	return Vector2(
		clampf(target_position.x, 0.0, max_x),
		clampf(target_position.y, 0.0, max_y)
	)

func _on_province_info_header_gui_input(event: InputEvent) -> void:
	if province_info_panel == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		province_info_dragging = event.pressed
		if province_info_dragging:
			province_info_drag_offset = province_info_panel.position - get_global_mouse_position()
	elif event is InputEventMouseMotion and province_info_dragging:
		province_info_panel.position = _clamp_province_info_panel_position(get_global_mouse_position() + province_info_drag_offset)

func _format_population(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count == 3 and i > 0:
			out = "." + out
			count = 0
	return out

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

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "selectionMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_left", 24)
	ui_layer.add_child(margin)

	_create_province_info_panel()
	_create_pause_menu()

func _create_pause_menu() -> void:
	pause_menu_panel = PanelContainer.new()
	pause_menu_panel.name = "pauseMenuPanel"
	pause_menu_panel.visible = false
	pause_menu_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_menu_panel.offset_right = 340
	pause_menu_panel.offset_bottom = 360
	ui_layer.add_child(pause_menu_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.55, 0.6, 0.7, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 18
	pause_menu_panel.add_theme_stylebox_override("panel", panel_style)

	var content: VBoxContainer = VBoxContainer.new()
	content.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	content.add_theme_constant_override("separation", 12)
	pause_menu_panel.add_child(content)

	var title: Label = Label.new()
	title.text = "Menu de pausa"
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)

	var buttons: Array = [
		{"text": "Volver", "action": Callable(self, "_resume_game")},
		{"text": "Opciones", "action": Callable(self, "_show_pause_options_placeholder")},
		{"text": "Salir al menu principal", "action": Callable(self, "_return_to_main_menu")},
		{"text": "Salir del juego", "action": Callable(self, "_quit_game")}
	]

	for button_data in buttons:
		var button: Button = Button.new()
		button.text = button_data["text"]
		button.custom_minimum_size = Vector2(280, 48)
		button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		button.pressed.connect(button_data["action"])
		content.add_child(button)

	call_deferred("_center_pause_menu")

func _create_province_info_panel() -> void:
	province_info_panel = PanelContainer.new()
	province_info_panel.name = "provinceInfoPanel"
	province_info_panel.visible = false
	province_info_panel.offset_right = 430
	province_info_panel.offset_bottom = 540
	ui_layer.add_child(province_info_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.16, 0.94)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.6, 0.65, 0.72, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_bottom = 16
	province_info_panel.add_theme_stylebox_override("panel", panel_style)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "content"
	content.custom_minimum_size = Vector2(398, 508)
	content.add_theme_constant_override("separation", 10)
	province_info_panel.add_child(content)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.custom_minimum_size = Vector2(0, 48)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_province_info_header_gui_input)
	content.add_child(header)

	province_info_title = Label.new()
	province_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	province_info_title.add_theme_font_size_override("font_size", 26)
	province_info_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1))
	header.add_child(province_info_title)

	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func() -> void:
		province_info_dragging = false
		province_info_panel.visible = false
	)
	header.add_child(close_button)

	province_info_population = Label.new()
	content.add_child(province_info_population)

	province_info_owner = Label.new()
	content.add_child(province_info_owner)

	province_info_buildings = Label.new()
	province_info_buildings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(province_info_buildings)

	province_info_resources = Label.new()
	province_info_resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(province_info_resources)

	var terrain_title: Label = Label.new()
	terrain_title.text = "Foto del terreno"
	content.add_child(terrain_title)

	var terrain_placeholder: PanelContainer = PanelContainer.new()
	terrain_placeholder.custom_minimum_size = Vector2(360, 90)
	content.add_child(terrain_placeholder)

	var terrain_label: Label = Label.new()
	terrain_label.text = "Se esta trabajando en ello"
	terrain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terrain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	terrain_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	terrain_placeholder.add_child(terrain_label)

	var municipalities_title: Label = Label.new()
	municipalities_title.text = "Foto de los municipios"
	content.add_child(municipalities_title)

	var municipalities_placeholder: PanelContainer = PanelContainer.new()
	municipalities_placeholder.custom_minimum_size = Vector2(360, 90)
	content.add_child(municipalities_placeholder)

	var municipalities_label: Label = Label.new()
	municipalities_label.text = "Se esta trabajando en ello"
	municipalities_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	municipalities_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	municipalities_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	municipalities_placeholder.add_child(municipalities_label)

	province_info_panel.position = _clamp_province_info_panel_position(Vector2(24, get_viewport_rect().size.y - 564))

	province_info_extra = Label.new()
	province_info_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(province_info_extra)

func _show_province_info(gid: String, nombre: String) -> void:
	if province_info_panel == null:
		return

	var province_data: Dictionary = {}
	if gid != "SEA":
		province_data = province_manager.provinces_by_gid.get(gid, {})

	var owner_id: Variant = province_manager.get_province_owner(gid)
	var owner_name: String = "Desconocido"
	if gid == "SEA":
		owner_name = "Ninguno"
	if nation_manager != null and owner_id != null and owner_id != "":
		owner_name = nation_manager.get_nation_name(owner_id)

	var population: int = 0 if gid == "SEA" else int(province_data.get("population_1835", 100000))
	var buildings_text: String = str(province_data.get("buildings", "Se esta trabajando en ello"))
	var resources_text: String = str(province_data.get("resources", "Se esta trabajando en ello"))
	var terrain_text: String = str(province_data.get("terrain_image", "Se esta trabajando en ello"))
	var municipalities_text: String = str(province_data.get("municipalities_image", "Se esta trabajando en ello"))
	var extra_text: String = str(province_data.get("extra_info", "Infraestructura: Se esta trabajando en ello\nCultura predominante: Se esta trabajando en ello\nAdministracion local: Se esta trabajando en ello"))
	province_info_title.text = nombre
	province_info_population.text = "Poblacion: %s" % _format_population(population)
	province_info_owner.text = "Pais: %s" % owner_name
	province_info_buildings.text = "Edificios: %s" % buildings_text
	province_info_resources.text = "Recursos disponibles: %s" % resources_text
	province_info_extra.text = "%s\nFoto del terreno: %s\nFoto de los municipios: %s" % [extra_text, terrain_text, municipalities_text]
	province_info_panel.position = _clamp_province_info_panel_position(province_info_panel.position)
	province_info_panel.visible = true

func _center_pause_menu() -> void:
	if pause_menu_panel == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = pause_menu_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = pause_menu_panel.get_combined_minimum_size()

	pause_menu_panel.position = Vector2(
		maxf(0.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(0.0, (viewport_size.y - panel_size.y) * 0.5)
	)

func _resume_game() -> void:
	if pause_menu_panel != null:
		pause_menu_panel.visible = false
	get_tree().paused = false

func _show_pause_options_placeholder() -> void:
	if get_tree().paused:
		get_tree().paused = false
	_show_coming_soon_popup("Opciones")
	get_tree().paused = true

func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _quit_game() -> void:
	get_tree().quit()

func _show_coming_soon_popup(title: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = "Proximamente"
	dialog.ok_button_text = "Aceptar"
	ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

func _set_selected_province(gid: String, nombre: String) -> void:
	selected_province_gid = gid
	blink_time = 0.0

	_show_province_info(gid, nombre)

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
	if event.is_action_pressed("ui_cancel"):
		if pause_menu_panel != null:
			var is_open: bool = pause_menu_panel.visible
			pause_menu_panel.visible = not is_open
			if not is_open:
				_center_pause_menu()
			get_tree().paused = not is_open
			if province_info_panel != null and not is_open:
				province_info_panel.visible = false
		return

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var pos_local: Vector2 = white_map.get_local_mouse_position()
		var tex_size: Vector2 = color_map.texture.get_size()

		var x: int = int(pos_local.x * tex_size.x / white_map.size.x)
		var y: int = int(pos_local.y * tex_size.y / white_map.size.y)

		if x < 0 or y < 0 or x >= tex_size.x or y >= tex_size.y:
			return

		var result: Variant = _get_nearby_province_info(x, y, 4)
		if result != null:
			var info: Dictionary = result.get("info", {})
			var rgb: Array = result.get("rgb", [0, 0, 0])
			var gid: String = info.get("gid", "(sin gid)")
			var nombre: String = info.get("nombre", "(sin nombre)")
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
		var owner_id: Variant = province_manager.get_province_owner(gid)
		if owner_id == null or owner_id == "":
			continue

		var nation_color: Color = nation_manager.get_nation_color(owner_id)
		var overlay_color: Color = Color(nation_color.r, nation_color.g, nation_color.b, 0.7)
		for pixel: Vector2i in province_pixels_by_gid[gid]:
			owner_overlay_image.set_pixel(pixel.x, pixel.y, overlay_color)

	owner_overlay.texture = ImageTexture.create_from_image(owner_overlay_image)

func set_province_owner_by_gid(gid: String, owner_id: String) -> void:
	if province_manager:
		province_manager.set_province_owner(gid, owner_id)
		_refresh_owner_overlay()
		var save_ok: bool = province_manager.save_to_file("res://data/provinces_with_gid.json")
		if not save_ok:
			push_warning("No se pudo guardar el estado de provincias en JSON")
