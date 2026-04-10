extends Node2D

@onready var white_map: TextureRect = $whiteMap
@onready var color_map: TextureRect = $colorMap
@onready var game_camera: Camera2D = $Camera2D

var owner_overlay: TextureRect = null
var selection_overlay: TextureRect = null
var game_ui: GameUI = null

var province_manager: ProvinceManager = null
var nation_manager: NationManager = null

var provincias_por_rgb: Dictionary = {}
var color_map_image: Image = null
var province_pixels_by_gid: Dictionary = {}
var owner_overlay_image: Image = null
var selection_overlay_image: Image = null
var previous_selected_gid: String = ""
var selected_province_gid: String = ""
var blink_time: float = 0.0

var game_date: Dictionary = {"day": 1, "month": 1, "year": 1836}
var game_speed: int = 3
var time_accumulator: float = 0.0
var time_paused: bool = true

const SELECTION_BLINK_SPEED: float = 3.2
const SELECTION_MIN_ALPHA: float = 0.38
const SELECTION_MAX_ALPHA: float = 0.62
const SEA_GID: String = "SEA"
const SEA_RGB_KEY: int = (172 << 16) | (201 << 8) | 233
const CUSTOM_CURSOR_PATH: String = "res://assets/ui/cursor.svg"
const SPEED_TO_SECONDS: Dictionary = {1: 1.6, 2: 1.0, 3: 0.6, 4: 0.3, 5: 0.12}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var cursor_texture: Texture2D = load(CUSTOM_CURSOR_PATH)
	if cursor_texture != null:
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(4, 2))

	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)

	province_manager = ProvinceManager.new()
	add_child(province_manager)
	province_manager.load_from_file("res://data/provinces_with_gid.json")

	nation_manager = NationManager.new()
	add_child(nation_manager)
	nation_manager.load_from_file("res://data/countries.json")

	_rebuild_province_lookup()

	if color_map.texture != null:
		color_map_image = color_map.texture.get_image()
		_build_province_pixel_cache()

	_create_overlays()
	_create_ui()
	_refresh_owner_overlay()
	_refresh_clock_ui()
	game_ui.start_intro(game_camera)

func _process(delta: float) -> void:
	if game_ui == null:
		return

	if game_ui.is_intro_active():
		game_ui.hide_hover_name()
		time_paused = true
	else:
		_update_hover_name()
		_update_game_clock(delta)

	if selection_overlay == null or selected_province_gid == "":
		return

	blink_time += delta * SELECTION_BLINK_SPEED
	var t: float = (sin(blink_time) + 1.0) * 0.5
	var alpha: float = lerpf(SELECTION_MIN_ALPHA, SELECTION_MAX_ALPHA, t)
	selection_overlay.self_modulate = Color(1, 1, 1, alpha)

func _unhandled_input(event: InputEvent) -> void:
	if game_ui == null:
		return

	if game_ui.is_intro_active():
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
				game_ui.request_intro_skip()
				return
		if event is InputEventMouseButton and event.pressed:
			game_ui.request_intro_skip()
			return

	if event.is_action_pressed("ui_cancel"):
		if game_ui.is_province_info_visible():
			game_ui.hide_province_info()
			return

		if game_ui.is_pause_menu_visible():
			_resume_game()
		else:
			time_paused = true
			get_tree().paused = true
			game_ui.set_time_paused(true)
			game_ui.show_pause_menu()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var result: Variant = _get_click_result()
		if result == null:
			return

		var info: Dictionary = result.get("info", {})
		var gid: String = str(info.get("gid", ""))
		var nombre: String = str(info.get("nombre", ""))
		_set_selected_province(gid, nombre)

func _rebuild_province_lookup() -> void:
	provincias_por_rgb.clear()
	for gid in province_manager.provinces_by_gid.keys():
		var province_data: Dictionary = province_manager.provinces_by_gid[gid]
		var color: Color = province_data.get("color", Color.BLACK)
		var rgb_key: int = _rgb_key(
			int(round(color.r * 255.0)),
			int(round(color.g * 255.0)),
			int(round(color.b * 255.0))
		)
		provincias_por_rgb[rgb_key] = {
			"gid": province_data.get("gid", ""),
			"nombre": province_data.get("nombre", "")
		}

func _create_overlays() -> void:
	owner_overlay = TextureRect.new()
	owner_overlay.name = "ownerOverlay"
	owner_overlay.anchor_left = white_map.anchor_left
	owner_overlay.anchor_top = white_map.anchor_top
	owner_overlay.anchor_right = white_map.anchor_right
	owner_overlay.anchor_bottom = white_map.anchor_bottom
	owner_overlay.position = white_map.position
	owner_overlay.size = white_map.size
	owner_overlay.expand = true
	owner_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owner_material: CanvasItemMaterial = CanvasItemMaterial.new()
	owner_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	owner_overlay.material = owner_material
	add_child(owner_overlay)

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

func _create_ui() -> void:
	game_ui = GameUI.new()
	add_child(game_ui)
	game_ui.resume_requested.connect(_resume_game)
	game_ui.return_to_main_menu_requested.connect(_return_to_main_menu)
	game_ui.quit_requested.connect(_quit_game)
	game_ui.time_pause_toggled.connect(_toggle_time_pause)
	game_ui.time_speed_selected.connect(_set_game_speed)

func _rgb_key(r: int, g: int, b: int) -> int:
	return (r << 16) | (g << 8) | b

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

func _build_province_pixel_cache() -> void:
	if color_map_image == null:
		return

	province_pixels_by_gid.clear()
	var width: int = color_map_image.get_width()
	var height: int = color_map_image.get_height()
	var color_lookup: Dictionary = _build_color_lookup_cache()

	for y in range(height):
		for x in range(width):
			var c: Color = color_map_image.get_pixel(x, y)
			var rgb_key: int = _rgb_key(
				int(round(c.r * 255.0)),
				int(round(c.g * 255.0)),
				int(round(c.b * 255.0))
			)
			var gid: String = color_lookup.get(rgb_key, "")
			if gid == "":
				continue
			if not province_pixels_by_gid.has(gid):
				province_pixels_by_gid[gid] = []
			province_pixels_by_gid[gid].append(Vector2i(x, y))

	owner_overlay_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	selection_overlay_image = Image.create(width, height, false, Image.FORMAT_RGBA8)

func _get_province_info_at_pixel(x: int, y: int) -> Variant:
	if color_map_image == null:
		return null
	if x < 0 or y < 0 or x >= color_map_image.get_width() or y >= color_map_image.get_height():
		return null

	var c: Color = color_map_image.get_pixel(x, y)
	var r: int = int(round(c.r * 255.0))
	var g: int = int(round(c.g * 255.0))
	var b: int = int(round(c.b * 255.0))
	var rgb_key: int = _rgb_key(r, g, b)
	if rgb_key == SEA_RGB_KEY:
		return {"info": {"gid": SEA_GID, "nombre": Localization.t("game.sea")}, "rgb": [r, g, b]}

	var info: Variant = provincias_por_rgb.get(rgb_key, null)
	if info != null:
		return {"info": info, "rgb": [r, g, b]}

	var gid_tolerante: String = province_manager.get_gid_by_color(c)
	if gid_tolerante != "" and province_manager.provinces_by_gid.has(gid_tolerante):
		return {"info": province_manager.provinces_by_gid[gid_tolerante], "rgb": [r, g, b]}
	return null

func _get_nearby_province_info(x: int, y: int, radius: int = 3) -> Variant:
	var direct: Variant = _get_province_info_at_pixel(x, y)
	if direct != null:
		return direct
	for dist in range(1, radius + 1):
		for oy in range(-dist, dist + 1):
			for ox in range(-dist, dist + 1):
				if abs(ox) != dist and abs(oy) != dist:
					continue
				var candidate: Variant = _get_province_info_at_pixel(x + ox, y + oy)
				if candidate != null:
					return candidate
	return null

func _get_click_result() -> Variant:
	var pos_local: Vector2 = white_map.get_local_mouse_position()
	var tex_size: Vector2 = color_map.texture.get_size()
	var x: int = int(pos_local.x * tex_size.x / white_map.size.x)
	var y: int = int(pos_local.y * tex_size.y / white_map.size.y)
	if x < 0 or y < 0 or x >= tex_size.x or y >= tex_size.y:
		return null
	return _get_nearby_province_info(x, y, 4)

func _update_hover_name() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if game_ui.is_mouse_over_top_menu(mouse_pos):
		game_ui.hide_hover_name()
		return

	var white_rect: Rect2 = Rect2(white_map.global_position, white_map.size)
	if not white_rect.has_point(mouse_pos):
		game_ui.hide_hover_name()
		return

	var pos_local: Vector2 = white_map.get_local_mouse_position()
	var tex_size: Vector2 = color_map.texture.get_size()
	var x: int = int(pos_local.x * tex_size.x / white_map.size.x)
	var y: int = int(pos_local.y * tex_size.y / white_map.size.y)
	if x < 0 or y < 0 or x >= tex_size.x or y >= tex_size.y:
		game_ui.hide_hover_name()
		return

	var result: Variant = _get_nearby_province_info(x, y, 2)
	if result == null:
		game_ui.hide_hover_name()
		return

	var info: Dictionary = result.get("info", {})
	var nombre: String = str(info.get("nombre", ""))
	if nombre == "":
		game_ui.hide_hover_name()
		return
	game_ui.show_hover_name(nombre, mouse_pos)

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

func _get_population_value(province_data: Dictionary) -> int:
	if province_data.has("population"):
		var population_data: Variant = province_data.get("population", {})
		if typeof(population_data) == TYPE_DICTIONARY:
			return int(population_data.get("value", 0))
	return int(province_data.get("population_1835", 0))

func _format_status_list_field(field_value: Variant) -> String:
	if typeof(field_value) == TYPE_DICTIONARY:
		var field_data: Dictionary = field_value
		var entries: Array = field_data.get("entries", [])
		if not entries.is_empty():
			var values: Array[String] = []
			for entry in entries:
				values.append(str(entry))
			return ", ".join(values)
		return str(field_data.get("status", Localization.t("game.province.wip")))
	if typeof(field_value) == TYPE_ARRAY:
		var values: Array[String] = []
		for entry in field_value:
			values.append(str(entry))
		return ", ".join(values)
	return str(field_value)

func _get_building_count(province_data: Dictionary) -> int:
	var buildings_data: Variant = province_data.get("buildings", {})
	if typeof(buildings_data) == TYPE_DICTIONARY:
		var entries: Variant = buildings_data.get("entries", [])
		if typeof(entries) == TYPE_ARRAY:
			var mining_limits: Dictionary = buildings_data.get("mining_limits", {})
			var count: int = 0
			for entry in entries:
				if typeof(entry) == TYPE_DICTIONARY:
					if str(entry.get("category", "")) == "mining":
						continue
					count += 1
					continue
				var building_id: String = str(entry)
				if mining_limits.has(building_id):
					continue
				count += 1
			return count
	return 0

func _format_cultivable_land(province_data: Dictionary) -> String:
	var cultivable_data: Variant = province_data.get("cultivable_land", 0)
	var base_value: int = 0
	if typeof(cultivable_data) == TYPE_DICTIONARY:
		base_value = int(cultivable_data.get("base", 0))
	else:
		base_value = int(cultivable_data)
	return str(maxi(0, base_value - _get_building_count(province_data)))

func _build_province_ui_payload(gid: String, nombre: String) -> Dictionary:
	var province_data: Dictionary = {}
	if gid != SEA_GID:
		province_data = province_manager.provinces_by_gid.get(gid, {})

	var owner_id: Variant = nation_manager.get_province_owner(gid)
	var owner_name: String = Localization.t("game.country.unknown")
	if gid == SEA_GID:
		owner_name = Localization.t("game.country.none")
	elif owner_id != null and owner_id != "":
		owner_name = nation_manager.get_nation_name(owner_id)

	var population: int = 0 if gid == SEA_GID else _get_population_value(province_data)
	return {
		"name": nombre,
		"population": _format_population(population),
		"owner_name": owner_name,
		"cultivable_land": "0" if gid == SEA_GID else _format_cultivable_land(province_data),
		"buildings": _format_status_list_field(province_data.get("buildings", Localization.t("game.province.wip"))),
		"resources": _format_status_list_field(province_data.get("resources", Localization.t("game.province.wip"))),
		"terrain": str(province_data.get("terrain_image", Localization.t("game.province.wip"))),
		"municipalities": str(province_data.get("municipalities_image", Localization.t("game.province.wip"))),
		"extra": str(province_data.get("extra_info", Localization.t("game.province.wip")))
	}

func _set_selected_province(gid: String, nombre: String) -> void:
	selected_province_gid = gid
	blink_time = 0.0
	game_ui.set_selected_province(gid, _build_province_ui_payload(gid, nombre))

	if selection_overlay == null or selection_overlay_image == null:
		return
	if previous_selected_gid != "" and province_pixels_by_gid.has(previous_selected_gid):
		for pixel: Vector2i in province_pixels_by_gid[previous_selected_gid]:
			selection_overlay_image.set_pixel(pixel.x, pixel.y, Color(0, 0, 0, 0))
	if province_pixels_by_gid.has(gid):
		for pixel: Vector2i in province_pixels_by_gid[gid]:
			selection_overlay_image.set_pixel(pixel.x, pixel.y, Color(1, 1, 1, 1))
	selection_overlay.texture = ImageTexture.create_from_image(selection_overlay_image)
	selection_overlay.self_modulate = Color(1, 1, 1, SELECTION_MAX_ALPHA)
	previous_selected_gid = gid

func _refresh_owner_overlay() -> void:
	if owner_overlay == null or owner_overlay_image == null:
		return
	owner_overlay_image.fill(Color(0, 0, 0, 0))
	for gid in province_pixels_by_gid.keys():
		var owner_id: Variant = nation_manager.get_province_owner(gid)
		if owner_id == null or owner_id == "":
			continue
		var nation_color: Color = nation_manager.get_nation_color(owner_id)
		var overlay_color: Color = Color(nation_color.r, nation_color.g, nation_color.b, 0.7)
		for pixel: Vector2i in province_pixels_by_gid[gid]:
			owner_overlay_image.set_pixel(pixel.x, pixel.y, overlay_color)
	owner_overlay.texture = ImageTexture.create_from_image(owner_overlay_image)

func set_province_owner_by_gid(gid: String, owner_id: String) -> void:
	nation_manager.set_province_owner(gid, owner_id)
	_refresh_owner_overlay()
	var save_ok: bool = nation_manager.save_to_file("res://data/countries.json")
	if not save_ok:
		push_warning("No se pudo guardar el estado de paises en JSON")

func _format_game_date() -> String:
	return "%d %s %d" % [
		int(game_date.get("day", 1)),
		Localization.get_month_name(int(game_date.get("month", 1))),
		int(game_date.get("year", 1836))
	]

func _refresh_clock_ui() -> void:
	if game_ui == null:
		return
	game_ui.set_game_date_text(_format_game_date())
	game_ui.set_game_speed(game_speed)
	game_ui.set_time_paused(time_paused)

func _update_game_clock(delta: float) -> void:
	if get_tree().paused or time_paused:
		_refresh_clock_ui()
		return
	time_accumulator += delta
	var seconds_per_day: float = float(SPEED_TO_SECONDS.get(game_speed, 0.6))
	while time_accumulator >= seconds_per_day:
		time_accumulator -= seconds_per_day
		_advance_game_day()

func _advance_game_day() -> void:
	game_date["day"] = int(game_date.get("day", 1)) + 1
	if int(game_date["day"]) > 30:
		game_date["day"] = 1
		game_date["month"] = int(game_date.get("month", 1)) + 1
		if int(game_date["month"]) > 12:
			game_date["month"] = 1
			game_date["year"] = int(game_date.get("year", 1836)) + 1
	_refresh_clock_ui()

func _set_game_speed(speed_value: int) -> void:
	game_speed = clampi(speed_value, 1, 5)
	_refresh_clock_ui()

func _toggle_time_pause() -> void:
	time_paused = not time_paused
	_refresh_clock_ui()

func _resume_game() -> void:
	get_tree().paused = false
	time_paused = false
	game_ui.hide_pause_menu()
	_refresh_clock_ui()

func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _quit_game() -> void:
	get_tree().quit()

func _on_language_changed(_language_code: String) -> void:
	_refresh_clock_ui()
	if selected_province_gid != "" and game_ui != null and game_ui.is_province_info_visible():
		var province_name: String = Localization.t("game.sea") if selected_province_gid == SEA_GID else str(province_manager.provinces_by_gid[selected_province_gid].get("nombre", selected_province_gid))
		game_ui.set_selected_province(selected_province_gid, _build_province_ui_payload(selected_province_gid, province_name))
