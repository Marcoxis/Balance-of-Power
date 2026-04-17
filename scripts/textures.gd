extends Node2D

signal event_option_selected(event_id: String, option_id: String, consequences: Dictionary)

@onready var white_map: TextureRect = $whiteMap
@onready var color_map: TextureRect = $colorMap
@onready var world_camera: Camera2D = $Camera2D

# Stores the overlay used to paint political ownership on the map.
# Guarda el overlay usado para pintar la propiedad política en el mapa.
var owner_overlay: TextureRect = null
var selection_overlay: TextureRect = null
var ui_layer: CanvasLayer = null
var province_name_label: Label = null
var province_info_panel: PanelContainer = null
var province_info_title: Label = null
var province_info_population: Label = null
var province_info_owner: Label = null
var province_info_buildings: Label = null
var province_info_resources: Label = null
var province_info_extra: Label = null
var top_bar_panel: PanelContainer = null
var date_label: Label = null
var speed_buttons: Array[Button] = []
var pause_toggle_button: Button = null
var pause_menu_panel: PanelContainer = null
var console_panel: PanelContainer = null
var console_output: RichTextLabel = null
var console_input: LineEdit = null
var event_popup_panel: PanelContainer = null
var event_popup_title: Label = null
var event_popup_image: TextureRect = null
var event_popup_text: Label = null
var event_popup_options: VBoxContainer = null
var current_event_id: String = ""
var console_lines: Array[String] = []

# Holds runtime managers created when the scene boots.
# Guarda los managers creados en tiempo de ejecución al iniciar la escena.
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
var current_game_date: Dictionary = {"day": 1, "month": 1, "year": 1836}
var current_time_speed: int = 3
var time_paused: bool = true
var time_accumulator: float = 0.0
var day_change_speed_multiplier: float = 1.0

# Stores the blink tuning values for the selected province overlay.
# Guarda los valores de ajuste del parpadeo del overlay de provincia seleccionada.
const SELECTION_BLINK_SPEED := 3.2
const SELECTION_MIN_ALPHA := 0.38
const SELECTION_MAX_ALPHA := 0.62
const CONSOLE_MAX_LINES := 28
const SPEED_TO_DAYS_PER_SECOND := {
	1: 0.35,
	2: 0.75,
	3: 1.5,
	4: 3.0,
	5: 6.0
}
const MONTH_NAMES := [
	"",
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December"
]

# Packs one RGB color into a single integer lookup key.
# Empaqueta un color RGB en una única clave entera de búsqueda.
func _rgb_key(r: int, g: int, b: int) -> int:
	return (r << 16) | (g << 8) | b

# Resolves one province id from the exact color stored in one map pixel.
# Resuelve un ID de provincia desde el color exacto almacenado en un píxel del mapa.
func _get_exact_gid_at_pixel(x: int, y: int) -> String:
	if color_map_image == null:
		return ""

	var c: Color = color_map_image.get_pixel(x, y)
	var r: int = int(round(c.r * 255.0))
	var g: int = int(round(c.g * 255.0))
	var b: int = int(round(c.b * 255.0))
	return province_manager.rgb_to_gid.get(_rgb_key(r, g, b), "")

# Builds a cache from raw map colors to province ids for faster scans.
# Construye una caché de colores del mapa a IDs de provincia para escaneos más rápidos.
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
			var rgb_key := _rgb_key(r, g, b)
			if color_lookup.has(rgb_key):
				continue

			var gid: String = province_manager.rgb_to_gid.get(rgb_key, "")
			if gid == "":
				gid = province_manager.get_gid_by_color(c)
			color_lookup[rgb_key] = gid

	return color_lookup

# Returns province info for one exact pixel, with tolerant fallback if needed.
# Devuelve la info de provincia para un píxel exacto, con fallback tolerante si hace falta.
func _get_province_info_at_pixel(x: int, y: int) -> Variant:
	if color_map_image == null:
		return null
	if x < 0 or y < 0 or x >= color_map_image.get_width() or y >= color_map_image.get_height():
		return null

	# First try exact color matching; if that fails, use the manager tolerance fallback.
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

# Searches a small area around the click so border clicks still resolve a province.
# Busca una pequeña zona alrededor del clic para que los bordes también resuelvan provincia.
func _get_nearby_province_info(x: int, y: int, radius: int = 3) -> Variant:
	var direct = _get_province_info_at_pixel(x, y)
	if direct != null:
		return direct

	# If the click lands on a border, search a few nearby pixels.
	# Si el click cae en el borde, buscamos unos pocos píxeles alrededor.
	for dist in range(1, radius + 1):
		for oy in range(-dist, dist + 1):
			for ox in range(-dist, dist + 1):
				if abs(ox) != dist and abs(oy) != dist:
					continue
				var candidate = _get_province_info_at_pixel(x + ox, y + oy)
				if candidate != null:
					return candidate

	return null

# Compares two colors using a small tolerance window.
# Compara dos colores usando una pequeña ventana de tolerancia.
func colores_iguales(c1: Color, c2: Color, tolerancia: float = 0.01) -> bool:
	return abs(c1.r - c2.r) < tolerancia \
		and abs(c1.g - c2.g) < tolerancia \
		and abs(c1.b - c2.b) < tolerancia

# Boots managers, caches, overlays, and base UI for the map scene.
# Inicializa managers, cachés, overlays y la UI base para la escena del mapa.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create and configure runtime managers.
	# Crear y configurar managers.
	province_manager = ProvinceManager.new()
	add_child(province_manager)
	province_manager.load_from_file("res://data/provinces_with_gid.json")

	nation_manager = NationManager.new()
	add_child(nation_manager)

	if not DebugSettings.settings_changed.is_connected(_apply_debug_settings):
		DebugSettings.settings_changed.connect(_apply_debug_settings)

	# Reuse ProvinceManager data so the province JSON is not parsed twice.
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

	# Persistent overlay used to paint owner colors over the base map.
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
		# Separate overlay for the selected province; animation only changes alpha.
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

	# Build the ownership texture once using the cached province pixels.
	# Generamos la textura de propietarios una vez, ya apoyados en la caché de píxeles.
	call_deferred("_refresh_owner_overlay")
	call_deferred("_apply_debug_settings")

# Updates the selection blink animation every frame.
# Actualiza la animación de parpadeo de selección en cada frame.
func _process(delta: float) -> void:
	_update_game_time(delta)

	if selection_overlay == null or selected_province_gid == "":
		return

	# Blink is driven by a sine wave that oscillates the overlay opacity.
	# El parpadeo se consigue oscilando la opacidad con una senoide.
	blink_time += delta * SELECTION_BLINK_SPEED
	var t := (sin(blink_time) + 1.0) * 0.5
	var alpha := lerpf(SELECTION_MIN_ALPHA, SELECTION_MAX_ALPHA, t)
	selection_overlay.self_modulate = Color(1, 1, 1, alpha)

# Formats population values with thousands separators.
# Formatea valores de población con separadores de miles.
func _format_population(value: int) -> String:
	var text := str(value)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count == 3 and i > 0:
			out = "." + out
			count = 0
	return out

# Advances the in-game date according to the selected speed.
# Hace avanzar la fecha del juego según la velocidad seleccionada.
func _update_game_time(delta: float) -> void:
	if time_paused or get_tree().paused:
		return

	var days_per_second: float = float(SPEED_TO_DAYS_PER_SECOND.get(current_time_speed, 1.0)) * day_change_speed_multiplier
	time_accumulator += delta * days_per_second

	while time_accumulator >= 1.0:
		time_accumulator -= 1.0
		_advance_one_day()

# Advances the calendar by one day and wraps month and year values.
# Avanza el calendario un día y ajusta mes y año cuando toca.
func _advance_one_day() -> void:
	current_game_date["day"] = int(current_game_date["day"]) + 1

	var month: int = int(current_game_date["month"])
	var max_days: int = _get_days_in_month(month, int(current_game_date["year"]))
	if int(current_game_date["day"]) > max_days:
		current_game_date["day"] = 1
		current_game_date["month"] = month + 1

	if int(current_game_date["month"]) > 12:
		current_game_date["month"] = 1
		current_game_date["year"] = int(current_game_date["year"]) + 1

	_update_date_label()

# Returns how many days one given month has.
# Devuelve cuántos días tiene un mes concreto.
func _get_days_in_month(month: int, year: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			if _is_leap_year(year):
				return 29
			return 28
		_:
			return 30

# Checks whether one year is leap.
# Comprueba si un año es bisiesto.
func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

# Updates the visible date text in the top bar.
# Actualiza el texto visible de la fecha en la barra superior.
func _update_date_label() -> void:
	if date_label == null:
		return

	var day: int = int(current_game_date["day"])
	var month: int = int(current_game_date["month"])
	var year: int = int(current_game_date["year"])
	date_label.text = "%02d %s %d" % [day, MONTH_NAMES[month], year]

# Updates the time speed selection state and button labels.
# Actualiza el estado de la velocidad del tiempo y las etiquetas de los botones.
func _update_time_controls() -> void:
	if pause_toggle_button != null:
		pause_toggle_button.text = ">" if time_paused else "||"

	for i in range(speed_buttons.size()):
		speed_buttons[i].disabled = (i + 1) == current_time_speed

# Toggles whether the in-game time is paused.
# Alterna si el tiempo del juego está pausado.
func _toggle_time_pause() -> void:
	time_paused = not time_paused
	_update_time_controls()

# Sets the active in-game time speed.
# Establece la velocidad activa del tiempo del juego.
func _set_time_speed(speed: int) -> void:
	current_time_speed = clampi(speed, 1, 5)
	_update_time_controls()

# Sets the global multiplier used to speed up or slow down day changes.
# Establece el multiplicador global usado para acelerar o frenar el cambio de día.
func _set_day_change_speed_multiplier(value: float) -> void:
	day_change_speed_multiplier = maxf(0.01, value)

# Builds the per-province pixel cache used by overlays and selection.
# Construye la caché de píxeles por provincia usada por overlays y selección.
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

# Creates the selection UI layer and its main widgets.
# Crea la capa de UI de selección y sus widgets principales.
func _create_selection_ui() -> void:
	# UI lives in a CanvasLayer so it does not move with the camera.
	# La UI vive en un CanvasLayer para no moverse con la cámara.
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

	_create_top_bar()
	_create_province_info_panel()
	_create_pause_menu()
	_create_console()
	_create_event_popup()

# Creates the top-right time bar with date, speed buttons, and pause toggle.
# Crea la barra superior derecha con fecha, velocidades y botón de pausa.
func _create_top_bar() -> void:
	top_bar_panel = PanelContainer.new()
	top_bar_panel.name = "topBarPanel"
	top_bar_panel.anchor_left = 1.0
	top_bar_panel.anchor_top = 0.0
	top_bar_panel.anchor_right = 1.0
	top_bar_panel.anchor_bottom = 0.0
	top_bar_panel.offset_left = -430
	top_bar_panel.offset_top = 16
	top_bar_panel.offset_right = -16
	top_bar_panel.offset_bottom = 90
	ui_layer.add_child(top_bar_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.62, 0.66, 0.74, 0.92)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 16
	panel_style.content_margin_bottom = 12
	top_bar_panel.add_theme_stylebox_override("panel", panel_style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	top_bar_panel.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	layout.add_child(top_row)

	date_label = Label.new()
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_label.add_theme_font_size_override("font_size", 24)
	date_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
	top_row.add_child(date_label)

	pause_toggle_button = Button.new()
	pause_toggle_button.custom_minimum_size = Vector2(52, 34)
	pause_toggle_button.pressed.connect(_toggle_time_pause)
	top_row.add_child(pause_toggle_button)

	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_END
	speed_row.add_theme_constant_override("separation", 8)
	layout.add_child(speed_row)

	speed_buttons.clear()
	for speed_value in [1, 2, 3, 4, 5]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(44, 32)
		button.text = str(speed_value)
		button.pressed.connect(func(value: int = speed_value) -> void:
			_set_time_speed(value)
		)
		speed_row.add_child(button)
		speed_buttons.append(button)

	_update_date_label()
	_update_time_controls()

# Creates the legacy pause menu used by this map UI implementation.
# Crea el menú de pausa legado usado por esta implementación de UI del mapa.
func _create_pause_menu() -> void:
	pause_menu_panel = PanelContainer.new()
	pause_menu_panel.name = "pauseMenuPanel"
	pause_menu_panel.visible = false
	pause_menu_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_menu_panel.offset_right = 340
	pause_menu_panel.offset_bottom = 360
	pause_menu_panel.position = Vector2(40, 120)
	ui_layer.add_child(pause_menu_panel)

	var panel_style := StyleBoxFlat.new()
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

	var content := VBoxContainer.new()
	content.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	content.add_theme_constant_override("separation", 12)
	pause_menu_panel.add_child(content)

	var title := Label.new()
	title.text = "Menu de pausa"
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)

	var buttons := [
		{"text": "Volver", "action": Callable(self, "_resume_game")},
		{"text": "Opciones", "action": Callable(self, "_show_pause_options_placeholder")},
		{"text": "Salir al menu principal", "action": Callable(self, "_return_to_main_menu")},
		{"text": "Salir del juego", "action": Callable(self, "_quit_game")}
	]

	for button_data in buttons:
		var button := Button.new()
		button.text = button_data["text"]
		button.custom_minimum_size = Vector2(280, 48)
		button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		button.pressed.connect(button_data["action"])
		content.add_child(button)

# Creates the in-game console used to execute quick debug commands.
# Crea la consola ingame usada para ejecutar comandos rápidos de debug.
func _create_console() -> void:
	console_panel = PanelContainer.new()
	console_panel.name = "consolePanel"
	console_panel.visible = false
	console_panel.offset_right = 760
	console_panel.offset_bottom = 280
	console_panel.position = Vector2(24, 24)
	console_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	console_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(console_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.28, 0.78, 0.48, 0.9)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 12
	console_panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.process_mode = Node.PROCESS_MODE_ALWAYS
	console_panel.add_child(content)

	var title := Label.new()
	title.text = "Console"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.72, 0.96, 0.78, 1.0))
	content.add_child(title)

	console_output = RichTextLabel.new()
	console_output.custom_minimum_size = Vector2(730, 190)
	console_output.scroll_active = true
	console_output.bbcode_enabled = false
	console_output.selection_enabled = true
	console_output.fit_content = false
	console_output.process_mode = Node.PROCESS_MODE_ALWAYS
	content.add_child(console_output)

	console_input = LineEdit.new()
	console_input.placeholder_text = "Enter command..."
	console_input.process_mode = Node.PROCESS_MODE_ALWAYS
	console_input.mouse_filter = Control.MOUSE_FILTER_STOP
	console_input.text_submitted.connect(_on_console_command_submitted)
	content.add_child(console_input)

	_append_console_line("Type 'help' to list available commands.")

# Creates the reusable event popup for scripted choices.
# Crea el popup reutilizable de eventos para decisiones guionizadas.
func _create_event_popup() -> void:
	event_popup_panel = PanelContainer.new()
	event_popup_panel.name = "eventPopupPanel"
	event_popup_panel.visible = false
	event_popup_panel.offset_right = 620
	event_popup_panel.offset_bottom = 620
	event_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(event_popup_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.66, 0.62, 0.48, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 18
	event_popup_panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	event_popup_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	event_popup_title = Label.new()
	event_popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_popup_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_popup_title.add_theme_font_size_override("font_size", 28)
	event_popup_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
	header.add_child(event_popup_title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func() -> void:
		hide_event_popup()
	)
	header.add_child(close_button)

	event_popup_image = TextureRect.new()
	event_popup_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_popup_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_popup_image.custom_minimum_size = Vector2(0, 220)
	event_popup_image.visible = false
	content.add_child(event_popup_image)

	event_popup_text = Label.new()
	event_popup_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_popup_text.add_theme_font_size_override("font_size", 18)
	content.add_child(event_popup_text)

	event_popup_options = VBoxContainer.new()
	event_popup_options.add_theme_constant_override("separation", 10)
	content.add_child(event_popup_options)

# Creates the legacy province information panel with placeholders.
# Crea el panel legado de información de provincia con placeholders.
func _create_province_info_panel() -> void:
	province_info_panel = PanelContainer.new()
	province_info_panel.name = "provinceInfoPanel"
	province_info_panel.visible = false
	province_info_panel.offset_right = 430
	province_info_panel.offset_bottom = 540
	province_info_panel.position = Vector2(24, 80)
	ui_layer.add_child(province_info_panel)

	var panel_style := StyleBoxFlat.new()
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

	var content := VBoxContainer.new()
	content.name = "content"
	content.custom_minimum_size = Vector2(398, 508)
	content.add_theme_constant_override("separation", 10)
	province_info_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	province_info_title = Label.new()
	province_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	province_info_title.add_theme_font_size_override("font_size", 26)
	province_info_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1))
	header.add_child(province_info_title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func() -> void:
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

	var terrain_title := Label.new()
	terrain_title.text = "Foto del terreno"
	content.add_child(terrain_title)

	var terrain_placeholder := PanelContainer.new()
	terrain_placeholder.custom_minimum_size = Vector2(360, 90)
	content.add_child(terrain_placeholder)

	var terrain_label := Label.new()
	terrain_label.text = "Se esta trabajando en ello"
	terrain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terrain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	terrain_label.anchors_preset = Control.PRESET_FULL_RECT
	terrain_placeholder.add_child(terrain_label)

	var municipalities_title := Label.new()
	municipalities_title.text = "Foto de los municipios"
	content.add_child(municipalities_title)

	var municipalities_placeholder := PanelContainer.new()
	municipalities_placeholder.custom_minimum_size = Vector2(360, 90)
	content.add_child(municipalities_placeholder)

	var municipalities_label := Label.new()
	municipalities_label.text = "Se esta trabajando en ello"
	municipalities_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	municipalities_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	municipalities_label.anchors_preset = Control.PRESET_FULL_RECT
	municipalities_placeholder.add_child(municipalities_label)

	province_info_extra = Label.new()
	province_info_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(province_info_extra)

# Fills and shows the province information panel for one selection.
# Rellena y muestra el panel de información de provincia para una selección.
func _show_province_info(gid: String, nombre: String) -> void:
	if province_info_panel == null:
		return

	var province_data: Dictionary = province_manager.provinces_by_gid.get(gid, {})

	var owner_id: Variant = province_manager.get_province_owner(gid)
	var owner_name := "Desconocido"
	if nation_manager != null and owner_id != null and owner_id != "":
		owner_name = nation_manager.get_nation_name(owner_id)

	var population: int = int(province_data.get("population_1835", 100000))
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
	province_info_panel.visible = true

# Returns whether the in-game console is currently visible.
# Devuelve si la consola ingame está visible actualmente.
func is_console_visible() -> bool:
	return console_panel != null and console_panel.visible

# Detects the keyboard shortcut used to open or close the console.
# Detecta el atajo de teclado usado para abrir o cerrar la consola.
func _is_console_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false

	return key_event.physical_keycode == KEY_QUOTELEFT or key_event.unicode == 186 or key_event.unicode == 170

# Enables or disables camera input from UI states such as the console.
# Activa o desactiva la entrada de la cámara desde estados de UI como la consola.
func _set_camera_input_enabled(enabled: bool) -> void:
	if world_camera != null:
		world_camera.input_enabled = enabled
		if not enabled:
			world_camera.arrastrando = false

# Opens the console and focuses the input field.
# Abre la consola y enfoca el campo de entrada.
func show_console() -> void:
	if console_panel == null:
		return
	console_panel.visible = true
	_set_camera_input_enabled(false)
	if console_input != null:
		console_input.editable = true
		console_input.mouse_filter = Control.MOUSE_FILTER_STOP
		console_input.grab_focus()

# Hides the console and clears the current input line.
# Oculta la consola y limpia la línea de entrada actual.
func hide_console() -> void:
	if console_panel == null:
		return
	console_panel.visible = false
	_set_camera_input_enabled(true)
	if console_input != null:
		console_input.text = ""
		console_input.release_focus()

# Toggles the console visibility state.
# Alterna el estado visible de la consola.
func toggle_console() -> void:
	if is_console_visible():
		hide_console()
	else:
		show_console()

# Appends one line to the console log and trims old output.
# Añade una línea al log de consola y recorta la salida antigua.
func _append_console_line(line: String) -> void:
	console_lines.append(line)
	while console_lines.size() > CONSOLE_MAX_LINES:
		console_lines.remove_at(0)
	_refresh_console_output()

# Rebuilds the console visible text from the stored lines.
# Reconstruye el texto visible de la consola desde las líneas guardadas.
func _refresh_console_output() -> void:
	if console_output == null:
		return
	console_output.clear()
	for line in console_lines:
		console_output.append_text("%s\n" % line)
	console_output.scroll_to_line(max(0, console_lines.size() - 1))

# Receives submitted console text and dispatches the command parser.
# Recibe el texto enviado por la consola y despacha el parser de comandos.
func _on_console_command_submitted(command_text: String) -> void:
	var raw_command: String = command_text.strip_edges()
	if raw_command == "":
		return

	_append_console_line("> " + raw_command)
	if console_input != null:
		console_input.clear()
	_execute_console_command(raw_command)
	if console_input != null and is_console_visible():
		console_input.grab_focus()

# Executes one console command and prints feedback to the log.
# Ejecuta un comando de consola y escribe feedback en el log.
func _execute_console_command(raw_command: String) -> void:
	var parts: PackedStringArray = raw_command.split(" ", false)
	if parts.is_empty():
		return

	var command: String = parts[0].to_lower()
	match command:
		"help":
			_append_console_line("help, clear, close, pause, resume, refresh_map, event_test, select <gid>, set_owner <gid> <country_id>, get_day_speed, set_day_speed <value>")
		"clear":
			console_lines.clear()
			_refresh_console_output()
		"close":
			hide_console()
		"pause":
			if get_tree().paused:
				_append_console_line("Game is already paused.")
			else:
				if pause_menu_panel != null:
					pause_menu_panel.visible = true
				get_tree().paused = true
				_append_console_line("Game paused.")
		"resume":
			if not get_tree().paused:
				_append_console_line("Game is already running.")
			else:
				_resume_game()
				_append_console_line("Game resumed.")
		"refresh_map":
			_refresh_owner_overlay()
			_append_console_line("Political overlay refreshed.")
		"get_day_speed":
			_append_console_line("Day speed multiplier: %s" % str(day_change_speed_multiplier))
		"set_day_speed":
			if parts.size() < 2:
				_append_console_line("Missing argument: speed multiplier")
				return
			if not parts[1].is_valid_float():
				_append_console_line("Invalid number: %s" % parts[1])
				return
			var new_speed: float = parts[1].to_float()
			_set_day_change_speed_multiplier(new_speed)
			_append_console_line("Day speed multiplier set to: %s" % str(day_change_speed_multiplier))
		"event_test":
			open_event_popup(
				"test_event",
				"Test Event",
				"This is a sample event fired from the console.",
				[
					create_event_option("accept", "Accept", {"prestige": 10}),
					create_event_option("reject", "Reject", {"prestige": -5})
				]
			)
			_append_console_line("Test event opened.")
		"select":
			if parts.size() < 2:
				_append_console_line("Missing argument: province gid")
				return
			var gid: String = parts[1]
			if province_manager == null or not province_manager.provinces_by_gid.has(gid):
				_append_console_line("Unknown province gid: %s" % gid)
				return
			var province_data: Dictionary = province_manager.provinces_by_gid[gid]
			_set_selected_province(gid, str(province_data.get("nombre", gid)))
			_append_console_line("Selected province: %s" % gid)
		"set_owner":
			if parts.size() < 2:
				_append_console_line("Missing argument: province gid")
				return
			if parts.size() < 3:
				_append_console_line("Missing argument: country id")
				return
			var gid: String = parts[1]
			var owner_id: String = parts[2].to_upper()
			if province_manager == null or not province_manager.provinces_by_gid.has(gid):
				_append_console_line("Unknown province gid: %s" % gid)
				return
			if nation_manager == null or not nation_manager.has_nation(owner_id):
				_append_console_line("Unknown country id: %s" % owner_id)
				return
			set_province_owner_by_gid(gid, owner_id)
			_append_console_line("Owner changed: %s -> %s" % [gid, owner_id])
		_:
			_append_console_line("unkow command")

# Returns whether an event popup is currently visible.
# Devuelve si actualmente hay un popup de evento visible.
func is_event_popup_visible() -> bool:
	return event_popup_panel != null and event_popup_panel.visible

# Clears the option rows inside the current event popup.
# Limpia las filas de opciones dentro del popup de evento actual.
func _clear_event_popup_options() -> void:
	if event_popup_options == null:
		return
	for child in event_popup_options.get_children():
		child.queue_free()

# Formats one consequences block into a short readable string.
# Formatea un bloque de consecuencias en una cadena corta legible.
func _format_event_consequences(consequences: Variant) -> String:
	if typeof(consequences) == TYPE_DICTIONARY:
		var parts: Array[String] = []
		for key in (consequences as Dictionary).keys():
			parts.append("%s: %s" % [str(key), str((consequences as Dictionary)[key])])
		return ", ".join(parts)
	if typeof(consequences) == TYPE_ARRAY:
		var parts: Array[String] = []
		for entry in consequences:
			parts.append(str(entry))
		return ", ".join(parts)
	return str(consequences)

# Builds one event option dictionary with id, text, and consequences.
# Construye un diccionario de opción de evento con id, texto y consecuencias.
func create_event_option(option_id: String, option_text: String, consequences: Dictionary = {}) -> Dictionary:
	return {
		"id": option_id,
		"text": option_text,
		"consequences": consequences
	}

# Opens one event popup from simple parameters instead of a full dictionary.
# Abre un popup de evento desde parámetros simples en lugar de un diccionario completo.
func open_event_popup(
	event_id: String,
	title: String,
	body_text: String,
	options: Array = [],
	image_path: String = "",
	image_texture: Texture2D = null
) -> void:
	var event_data: Dictionary = {
		"id": event_id,
		"title": title,
		"text": body_text,
		"options": options
	}

	if image_texture != null:
		event_data["image_texture"] = image_texture
	elif image_path != "":
		event_data["image_path"] = image_path

	show_event_popup(event_data)

# Centers the event popup on screen.
# Centra el popup de evento en pantalla.
func _center_event_popup() -> void:
	if event_popup_panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = event_popup_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = event_popup_panel.get_combined_minimum_size()
	event_popup_panel.position = Vector2(
		maxf(0.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(0.0, (viewport_size.y - panel_size.y) * 0.5)
	)

# Shows one configurable event popup with image, text, options, and consequences.
# Muestra un popup de evento configurable con imagen, texto, opciones y consecuencias.
func show_event_popup(event_data: Dictionary) -> void:
	if event_popup_panel == null:
		return

	current_event_id = str(event_data.get("id", ""))
	event_popup_title.text = str(event_data.get("title", "Event"))
	event_popup_text.text = str(event_data.get("text", ""))
	_clear_event_popup_options()

	var image_texture: Texture2D = null
	var image_value: Variant = event_data.get("image_texture", null)
	if image_value is Texture2D:
		image_texture = image_value
	elif event_data.has("image_path"):
		var loaded_resource: Resource = load(str(event_data.get("image_path", "")))
		if loaded_resource is Texture2D:
			image_texture = loaded_resource

	event_popup_image.texture = image_texture
	event_popup_image.visible = image_texture != null

	var options: Array = event_data.get("options", [])
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option_data: Dictionary = option_value
		var option_row := VBoxContainer.new()
		option_row.add_theme_constant_override("separation", 4)
		event_popup_options.add_child(option_row)

		var option_button := Button.new()
		option_button.text = str(option_data.get("text", "Option"))
		option_button.custom_minimum_size = Vector2(0, 44)
		var option_id: String = str(option_data.get("id", option_button.text.to_snake_case()))
		var consequences_value: Variant = option_data.get("consequences", {})
		var consequences: Dictionary = consequences_value if typeof(consequences_value) == TYPE_DICTIONARY else {}
		option_button.pressed.connect(func() -> void:
			emit_signal("event_option_selected", current_event_id, option_id, consequences)
			hide_event_popup()
		)
		option_row.add_child(option_button)

		if option_data.has("consequences"):
			var consequences_label := Label.new()
			consequences_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			consequences_label.self_modulate = Color(0.76, 0.8, 0.86, 0.88)
			consequences_label.text = _format_event_consequences(option_data.get("consequences", {}))
			option_row.add_child(consequences_label)

	_center_event_popup()
	event_popup_panel.visible = true

# Hides the current event popup and resets its active event id.
# Oculta el popup de evento actual y reinicia su id de evento activo.
func hide_event_popup() -> void:
	if event_popup_panel != null:
		event_popup_panel.visible = false
	current_event_id = ""

# Closes pause mode and resumes gameplay.
# Cierra el modo pausa y reanuda la partida.
func _resume_game() -> void:
	if pause_menu_panel != null:
		pause_menu_panel.visible = false
	get_tree().paused = false
	_update_time_controls()

# Shows the temporary options popup from the pause menu.
# Muestra el popup temporal de opciones desde el menú de pausa.
func _show_pause_options_placeholder() -> void:
	if get_tree().paused:
		get_tree().paused = false
	_show_coming_soon_popup("Opciones")
	get_tree().paused = true

# Returns to the main menu scene.
# Vuelve a la escena del menú principal.
func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# Quits the game from the legacy map UI.
# Sale del juego desde la UI legada del mapa.
func _quit_game() -> void:
	get_tree().quit()

# Shows a simple placeholder popup inside the legacy UI layer.
# Muestra un popup simple de placeholder dentro de la capa de UI legada.
func _show_coming_soon_popup(title: String) -> void:
	var dialog := AcceptDialog.new()
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

# Updates the selected province state and refreshes the selection overlay.
# Actualiza el estado de la provincia seleccionada y refresca el overlay de selección.
func _set_selected_province(gid: String, nombre: String) -> void:
	selected_province_gid = gid
	blink_time = 0.0

	if province_name_label != null:
		province_name_label.text = nombre

	_show_province_info(gid, nombre)

	if selection_overlay == null or selection_overlay_image == null:
		return

	# Reuse the same image and only clear/paint previous and current selection pixels.
	# Reutilizamos la misma imagen y solo limpiamos/pintamos los píxeles de la selección anterior y actual.
	if previous_selected_gid != "" and province_pixels_by_gid.has(previous_selected_gid):
		for pixel: Vector2i in province_pixels_by_gid[previous_selected_gid]:
			selection_overlay_image.set_pixel(pixel.x, pixel.y, Color(0, 0, 0, 0))

	if province_pixels_by_gid.has(gid):
		for pixel: Vector2i in province_pixels_by_gid[gid]:
			selection_overlay_image.set_pixel(pixel.x, pixel.y, Color(1, 1, 1, 1))

	selection_overlay.texture = ImageTexture.create_from_image(selection_overlay_image)
	selection_overlay.self_modulate = Color(1, 1, 1, SELECTION_MAX_ALPHA)
	previous_selected_gid = gid

# Handles pause toggling and province selection clicks.
# Gestiona la activación de pausa y los clics de selección de provincia.
func _input(event: InputEvent) -> void:
	if _is_console_toggle_event(event):
		toggle_console()
		get_viewport().set_input_as_handled()

# Handles pause toggling and province selection clicks.
# Gestiona la activación de pausa y los clics de selección de provincia.
func _unhandled_input(event):
	if is_console_visible():
		if event.is_action_pressed("ui_cancel"):
			hide_console()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return

	if is_event_popup_visible():
		if event.is_action_pressed("ui_cancel"):
			hide_event_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton or event is InputEventKey:
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if pause_menu_panel != null:
			var is_open := pause_menu_panel.visible
			pause_menu_panel.visible = not is_open
			get_tree().paused = not is_open
			if province_info_panel != null and not is_open:
				province_info_panel.visible = false
			_update_time_controls()
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
			# Update visual selection and the UI text for the clicked province.
			# Actualiza la selección visual y el texto de UI para la provincia pulsada.
			_set_selected_province(gid, nombre)
			print("(R:%d, G:%d, B:%d) -- Provincia: %s (%s)" % [rgb[0], rgb[1], rgb[2], nombre, gid])
		else:
			print("Provincia no identificada cerca de (%d, %d)" % [x, y])

# Rebuilds the political ownership overlay for the current country state.
# Reconstruye el overlay político de propiedad para el estado actual de países.
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
	_apply_debug_settings()

# Applies current debug visibility settings to the rendered map layers.
# Aplica los ajustes actuales de visibilidad debug a las capas renderizadas del mapa.
func _apply_debug_settings() -> void:
	if owner_overlay != null:
		owner_overlay.visible = DebugSettings.show_country_colors

	# The current map uses the base texture as land and sea together.
	# El mapa actual usa la textura base para tierra y mar al mismo tiempo.
	if white_map != null:
		white_map.visible = true

# Changes province ownership and persists the province file.
# Cambia la propiedad de la provincia y persiste el archivo de provincias.
func set_province_owner_by_gid(gid: String, owner_id: String) -> void:
	if province_manager:
		province_manager.set_province_owner(gid, owner_id)
		_refresh_owner_overlay()
		var save_ok = province_manager.save_to_file("res://data/provinces_with_gid.json")
		if not save_ok:
			push_warning("No se pudo guardar el estado de provincias en JSON")
