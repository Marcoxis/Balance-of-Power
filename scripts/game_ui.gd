extends CanvasLayer

class_name GameUI

signal resume_requested
signal return_to_main_menu_requested
signal quit_requested
signal time_pause_toggled
signal time_speed_selected(speed: int)
signal event_option_selected(event_id: String, option_id: String, consequences: Dictionary)

var province_info_panel: PanelContainer = null
var province_info_title: Label = null
var province_info_population: Label = null
var province_info_owner: Label = null
var province_info_cultivable_land: Label = null
var province_info_buildings: Label = null
var province_info_resources: Label = null
var province_info_extra: Label = null
var terrain_title_label: Label = null
var terrain_placeholder_label: Label = null
var municipalities_title_label: Label = null
var municipalities_placeholder_label: Label = null

var pause_menu_panel: PanelContainer = null
var pause_menu_title_label: Label = null
var pause_menu_buttons: Array[Button] = []

var event_popup_panel: PanelContainer = null
var event_popup_title_label: Label = null
var event_popup_image: TextureRect = null
var event_popup_text_label: Label = null
var event_popup_options_container: VBoxContainer = null
var current_event_id: String = ""

var debug_panel: PanelContainer = null
var debug_title_label: Label = null
var debug_country_colors_checkbox: CheckBox = null
var debug_show_sea_checkbox: CheckBox = null

var hover_name_panel: PanelContainer = null
var hover_name_label: Label = null

var top_menu_panel: PanelContainer = null
var top_menu_buttons: Array[Button] = []
var top_menu_title_keys: Array[String] = []

var technology_panel: PanelContainer = null
var technology_title_label: Label = null
var technology_tab_container: TabContainer = null
var technology_section_labels: Array[Label] = []
var technology_tab_labels: Array[Label] = []
var technology_tab_title_keys: Array[String] = []

var top_bar_panel: PanelContainer = null
var date_label: Label = null
var speed_buttons: Array[Button] = []
var pause_toggle_button: Button = null

var intro_overlay: Control = null
var intro_skip: Label = null
var intro_fade_rect: ColorRect = null
var intro_top_bar: ColorRect = null
var intro_bottom_bar: ColorRect = null
var intro_tween: Tween = null
var intro_skip_requested: bool = false
var intro_original_camera_position: Vector2 = Vector2.ZERO
var intro_original_camera_zoom: Vector2 = Vector2.ONE
var intro_camera: Camera2D = null

var province_info_dragging: bool = false
var province_info_drag_offset: Vector2 = Vector2.ZERO
var intro_active: bool = false
var current_selected_gid: String = ""
var current_selected_name: String = ""
var current_selected_payload: Dictionary = {}
var current_speed: int = 3
var current_time_paused: bool = true

const INTRO_ANIMATION_DURATION: float = 3.8

# Builds the UI tree and subscribes to language changes.
# Construye el ?rbol de UI y se suscribe a cambios de idioma.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)
	_create_ui()
	_apply_language()

# Updates intro-only animated hints each frame.
# Actualiza en cada frame las pistas animadas que solo usa la intro.
func _process(_delta: float) -> void:
	if intro_active:
		_update_intro_skip_hint()
		if intro_skip_requested:
			_end_intro_animation()

# Returns the current visible viewport size.
# Devuelve el tama?o visible actual del viewport.
func _get_viewport_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size

# Returns the current mouse position in viewport coordinates.
# Devuelve la posici?n actual del rat?n en coordenadas del viewport.
func _get_mouse_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_mouse_position()

# Creates every runtime UI panel used during gameplay.
# Crea todos los paneles de UI en tiempo de ejecuci?n usados durante la partida.
func _create_ui() -> void:
	_create_province_info_panel()
	_create_pause_menu()
	_create_event_popup()
	_create_debug_panel()
	_create_hover_name_panel()
	_create_top_menu()
	_create_technology_panel()
	_create_top_bar()
	_create_intro_overlay()

# Builds the draggable province information window.
# Construye la ventana arrastrable de informaci?n de provincia.
func _create_province_info_panel() -> void:
	province_info_panel = PanelContainer.new()
	province_info_panel.name = "provinceInfoPanel"
	province_info_panel.visible = false
	province_info_panel.offset_right = 430
	province_info_panel.offset_bottom = 540
	add_child(province_info_panel)

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
	province_info_cultivable_land = Label.new()
	content.add_child(province_info_cultivable_land)
	province_info_buildings = Label.new()
	province_info_buildings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(province_info_buildings)
	province_info_resources = Label.new()
	province_info_resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(province_info_resources)

	terrain_title_label = Label.new()
	content.add_child(terrain_title_label)

	var terrain_placeholder: PanelContainer = PanelContainer.new()
	terrain_placeholder.custom_minimum_size = Vector2(360, 90)
	content.add_child(terrain_placeholder)

	terrain_placeholder_label = Label.new()
	terrain_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terrain_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	terrain_placeholder_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	terrain_placeholder.add_child(terrain_placeholder_label)

	municipalities_title_label = Label.new()
	content.add_child(municipalities_title_label)

	var municipalities_placeholder: PanelContainer = PanelContainer.new()
	municipalities_placeholder.custom_minimum_size = Vector2(360, 90)
	content.add_child(municipalities_placeholder)

	municipalities_placeholder_label = Label.new()
	municipalities_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	municipalities_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	municipalities_placeholder_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	municipalities_placeholder.add_child(municipalities_placeholder_label)

	province_info_extra = Label.new()
	province_info_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(province_info_extra)

	province_info_panel.position = _clamp_panel_to_viewport(Vector2(24, _get_viewport_size().y - 564), province_info_panel)

# Builds the pause menu shown when the game is paused.
# Construye el men? de pausa mostrado cuando el juego est? en pausa.
func _create_pause_menu() -> void:
	pause_menu_panel = PanelContainer.new()
	pause_menu_panel.name = "pauseMenuPanel"
	pause_menu_panel.visible = false
	pause_menu_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_menu_panel.offset_right = 340
	pause_menu_panel.offset_bottom = 360
	add_child(pause_menu_panel)

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

	pause_menu_title_label = Label.new()
	pause_menu_title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(pause_menu_title_label)

	var button_defs: Array = [
		{"key": "game.resume", "callback": func() -> void: emit_signal("resume_requested")},
		{"key": "menu.debugger", "callback": func() -> void: toggle_debug_panel()},
		{"key": "menu.options", "callback": func() -> void: show_coming_soon_popup(Localization.t("menu.options"))},
		{"key": "game.quit_to_menu", "callback": func() -> void: emit_signal("return_to_main_menu_requested")},
		{"key": "game.quit_game", "callback": func() -> void: emit_signal("quit_requested")}
	]

	pause_menu_buttons.clear()
	for button_def in button_defs:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(280, 48)
		button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		button.pressed.connect(button_def["callback"])
		button.set_meta("translation_key", str(button_def["key"]))
		content.add_child(button)
		pause_menu_buttons.append(button)

# Builds the in-game debug settings window with toggle options.
# Construye la ventana ingame de ajustes debug con opciones conmutables.
func _create_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "debugPanel"
	debug_panel.visible = false
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_panel.offset_right = 360
	debug_panel.offset_bottom = 220
	add_child(debug_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.97)
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
	debug_panel.add_theme_stylebox_override("panel", panel_style)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	debug_panel.add_child(content)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	debug_title_label = Label.new()
	debug_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_title_label.add_theme_font_size_override("font_size", 24)
	header.add_child(debug_title_label)

	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func() -> void:
		hide_debug_panel()
	)
	header.add_child(close_button)

	debug_country_colors_checkbox = CheckBox.new()
	debug_country_colors_checkbox.toggled.connect(func(value: bool) -> void:
		DebugSettings.set_show_country_colors(value)
	)
	content.add_child(debug_country_colors_checkbox)

	debug_show_sea_checkbox = CheckBox.new()
	debug_show_sea_checkbox.toggled.connect(func(value: bool) -> void:
		DebugSettings.set_show_sea(value)
	)
	content.add_child(debug_show_sea_checkbox)

# Builds the reusable event popup used for narrative decisions.
# Construye el popup reutilizable de eventos usado para decisiones narrativas.
func _create_event_popup() -> void:
	event_popup_panel = PanelContainer.new()
	event_popup_panel.name = "eventPopupPanel"
	event_popup_panel.visible = false
	event_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	event_popup_panel.offset_right = 620
	event_popup_panel.offset_bottom = 620
	add_child(event_popup_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
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

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	event_popup_panel.add_child(content)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	event_popup_title_label = Label.new()
	event_popup_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_popup_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_popup_title_label.add_theme_font_size_override("font_size", 28)
	event_popup_title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
	header.add_child(event_popup_title_label)

	var close_button: Button = Button.new()
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

	event_popup_text_label = Label.new()
	event_popup_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_popup_text_label.add_theme_font_size_override("font_size", 18)
	content.add_child(event_popup_text_label)

	event_popup_options_container = VBoxContainer.new()
	event_popup_options_container.add_theme_constant_override("separation", 10)
	content.add_child(event_popup_options_container)

# Builds the small hover tooltip shown over provinces.
# Construye el peque?o tooltip de hover mostrado sobre provincias.
func _create_hover_name_panel() -> void:
	hover_name_panel = PanelContainer.new()
	hover_name_panel.name = "hoverNamePanel"
	hover_name_panel.visible = false
	hover_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hover_name_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.82, 0.78, 0.62, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	hover_name_panel.add_theme_stylebox_override("panel", style)

	hover_name_label = Label.new()
	hover_name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
	hover_name_panel.add_child(hover_name_label)

# Builds the top-left gameplay menu button row.
# Construye la fila de botones del men? de juego arriba a la izquierda.
func _create_top_menu() -> void:
	top_menu_panel = PanelContainer.new()
	top_menu_panel.name = "topMenuPanel"
	top_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	top_menu_panel.anchor_left = 0.0
	top_menu_panel.anchor_top = 0.0
	top_menu_panel.anchor_right = 0.0
	top_menu_panel.anchor_bottom = 0.0
	top_menu_panel.offset_left = 16
	top_menu_panel.offset_top = 16
	top_menu_panel.offset_right = 336
	top_menu_panel.offset_bottom = 88
	add_child(top_menu_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.55, 0.6, 0.7, 0.85)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 10
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 12
	top_menu_panel.add_theme_stylebox_override("panel", panel_style)

	var buttons_box: HBoxContainer = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 10)
	top_menu_panel.add_child(buttons_box)

	var menu_buttons: Array = [
		{"icon": "G", "key": "game.side.government"},
		{"icon": "D", "key": "game.side.diplomacy"},
		{"icon": "C", "key": "game.side.trade"},
		{"icon": "M", "key": "game.side.military"},
		{"icon": "P", "key": "game.side.population"},
		{"icon": "E", "key": "game.side.economy"},
		{"icon": "T", "key": "game.side.technology"}
	]

	top_menu_buttons.clear()
	top_menu_title_keys.clear()
	for button_data in menu_buttons:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(56, 56)
		button.text = str(button_data["icon"])
		button.add_theme_font_size_override("font_size", 26)
		if str(button_data["key"]) == "game.side.technology":
			button.pressed.connect(func() -> void:
				toggle_technology_panel()
			)
		else:
			button.pressed.connect(func(title_key: String = str(button_data["key"]), menu_icon: String = str(button_data["icon"])) -> void:
				show_coming_soon_popup(Localization.t(title_key), menu_icon)
			)
		buttons_box.add_child(button)
		top_menu_buttons.append(button)
		top_menu_title_keys.append(str(button_data["key"]))

# Builds the left-side technology panel and its placeholder tabs.
# Construye el panel lateral izquierdo de tecnolog?a y sus pesta?as placeholder.
func _create_technology_panel() -> void:
	technology_panel = PanelContainer.new()
	technology_panel.name = "technologyPanel"
	technology_panel.visible = false
	technology_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	technology_panel.anchor_left = 0.0
	technology_panel.anchor_top = 0.0
	technology_panel.anchor_right = 0.0
	technology_panel.anchor_bottom = 1.0
	add_child(technology_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.55, 0.6, 0.7, 0.9)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 14
	technology_panel.add_theme_stylebox_override("panel", panel_style)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	technology_panel.add_child(content)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	technology_title_label = Label.new()
	technology_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	technology_title_label.add_theme_font_size_override("font_size", 26)
	technology_title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
	header.add_child(technology_title_label)

	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(func() -> void:
		hide_technology_panel()
	)
	header.add_child(close_button)

	technology_tab_container = TabContainer.new()
	technology_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	technology_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(technology_tab_container)

	technology_tab_title_keys = [
		"game.tech.military",
		"game.tech.economic",
		"game.tech.civil",
		"game.tech.diplomatic"
	]
	technology_section_labels.clear()
	technology_tab_labels.clear()
	for title_key in technology_tab_title_keys:
		var tab_page: MarginContainer = MarginContainer.new()
		tab_page.add_theme_constant_override("margin_left", 10)
		tab_page.add_theme_constant_override("margin_top", 12)
		tab_page.add_theme_constant_override("margin_right", 10)
		tab_page.add_theme_constant_override("margin_bottom", 12)
		technology_tab_container.add_child(tab_page)

		var tab_content: VBoxContainer = VBoxContainer.new()
		tab_content.add_theme_constant_override("separation", 10)
		tab_page.add_child(tab_content)

		var section_title: Label = Label.new()
		section_title.add_theme_font_size_override("font_size", 22)
		section_title.add_theme_color_override("font_color", Color(0.9, 0.87, 0.76, 1.0))
		section_title.text = Localization.t(title_key)
		tab_content.add_child(section_title)
		technology_section_labels.append(section_title)

		var placeholder: PanelContainer = PanelContainer.new()
		placeholder.custom_minimum_size = Vector2(0, 180)
		tab_content.add_child(placeholder)

		var placeholder_style: StyleBoxFlat = StyleBoxFlat.new()
		placeholder_style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
		placeholder_style.border_width_left = 1
		placeholder_style.border_width_top = 1
		placeholder_style.border_width_right = 1
		placeholder_style.border_width_bottom = 1
		placeholder_style.border_color = Color(0.42, 0.48, 0.58, 0.8)
		placeholder_style.corner_radius_top_left = 10
		placeholder_style.corner_radius_top_right = 10
		placeholder_style.corner_radius_bottom_left = 10
		placeholder_style.corner_radius_bottom_right = 10
		placeholder_style.content_margin_left = 16
		placeholder_style.content_margin_top = 16
		placeholder_style.content_margin_right = 16
		placeholder_style.content_margin_bottom = 16
		placeholder.add_theme_stylebox_override("panel", placeholder_style)

		var placeholder_label: Label = Label.new()
		placeholder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.add_child(placeholder_label)
		technology_tab_labels.append(placeholder_label)

	_layout_technology_panel()

# Resizes and positions the technology panel to one quarter of the screen.
# Redimensiona y posiciona el panel de tecnolog?a a un cuarto de la pantalla.
func _layout_technology_panel() -> void:
	if technology_panel == null:
		return
	var viewport_size: Vector2 = _get_viewport_size()
	var panel_width: float = maxf(320.0, floorf(viewport_size.x * 0.25))
	technology_panel.offset_left = 16
	technology_panel.offset_top = 104
	technology_panel.offset_right = 16 + panel_width
	technology_panel.offset_bottom = -16

# Builds the top-right date, speed, and pause controls.
# Construye los controles de fecha, velocidad y pausa arriba a la derecha.
func _create_top_bar() -> void:
	top_bar_panel = PanelContainer.new()
	top_bar_panel.name = "topBarPanel"
	top_bar_panel.anchor_left = 1.0
	top_bar_panel.anchor_top = 0.0
	top_bar_panel.anchor_right = 1.0
	top_bar_panel.anchor_bottom = 0.0
	top_bar_panel.offset_left = -420
	top_bar_panel.offset_top = 16
	top_bar_panel.offset_right = -16
	top_bar_panel.offset_bottom = 86
	add_child(top_bar_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.94)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.58, 0.63, 0.72, 0.88)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 10
	top_bar_panel.add_theme_stylebox_override("panel", panel_style)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	top_bar_panel.add_child(layout)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.add_theme_constant_override("separation", 12)
	layout.add_child(top_row)

	date_label = Label.new()
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_label.add_theme_font_size_override("font_size", 24)
	date_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
	top_row.add_child(date_label)

	pause_toggle_button = Button.new()
	pause_toggle_button.custom_minimum_size = Vector2(52, 34)
	pause_toggle_button.text = "||"
	pause_toggle_button.pressed.connect(func() -> void:
		emit_signal("time_pause_toggled")
	)
	top_row.add_child(pause_toggle_button)

	var speed_row: HBoxContainer = HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_END
	speed_row.add_theme_constant_override("separation", 8)
	layout.add_child(speed_row)

	speed_buttons.clear()
	for speed_value in [1, 2, 3, 4, 5]:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(44, 32)
		button.text = str(speed_value)
		button.pressed.connect(func(value: int = speed_value) -> void:
			emit_signal("time_speed_selected", value)
		)
		speed_row.add_child(button)
		speed_buttons.append(button)

# Builds the intro overlay used by the opening camera animation.
# Construye el overlay de intro usado por la animaci?n inicial de c?mara.
func _create_intro_overlay() -> void:
	intro_overlay = Control.new()
	intro_overlay.name = "introOverlay"
	intro_overlay.visible = false
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(intro_overlay)

	intro_fade_rect = ColorRect.new()
	intro_fade_rect.color = Color(0.01, 0.02, 0.04, 0.68)
	intro_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_overlay.add_child(intro_fade_rect)

	intro_top_bar = ColorRect.new()
	intro_top_bar.color = Color.BLACK
	intro_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	intro_top_bar.custom_minimum_size = Vector2(0, 110)
	intro_overlay.add_child(intro_top_bar)

	intro_bottom_bar = ColorRect.new()
	intro_bottom_bar.color = Color.BLACK
	intro_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	intro_bottom_bar.custom_minimum_size = Vector2(0, 110)
	intro_overlay.add_child(intro_bottom_bar)

	intro_skip = Label.new()
	intro_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	intro_skip.add_theme_font_size_override("font_size", 16)
	intro_skip.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 0.85))
	intro_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	intro_skip.position = Vector2(0, -52)
	intro_overlay.add_child(intro_skip)

# Starts or updates dragging of the province window header.
# Inicia o actualiza el arrastre del encabezado de la ventana de provincia.
func _on_province_info_header_gui_input(event: InputEvent) -> void:
	if province_info_panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		province_info_dragging = event.pressed
		if province_info_dragging:
			province_info_drag_offset = province_info_panel.position - _get_mouse_position()
	elif event is InputEventMouseMotion and province_info_dragging:
		province_info_panel.position = _clamp_panel_to_viewport(_get_mouse_position() + province_info_drag_offset, province_info_panel)

# Clamps a UI panel so it always stays inside the viewport.
# Limita un panel de UI para que siempre permanezca dentro del viewport.
func _clamp_panel_to_viewport(target_position: Vector2, panel: Control) -> Vector2:
	var viewport_size: Vector2 = _get_viewport_size()
	var panel_size: Vector2 = panel.size
	if panel_size == Vector2.ZERO:
		panel_size = panel.get_combined_minimum_size()
	return Vector2(
		clampf(target_position.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x)),
		clampf(target_position.y, 0.0, maxf(0.0, viewport_size.y - panel_size.y))
	)

# Stores the selected province payload and opens the info window.
# Guarda el payload de la provincia seleccionada y abre la ventana de informaci?n.
func set_selected_province(gid: String, payload: Dictionary) -> void:
	current_selected_gid = gid
	current_selected_name = str(payload.get("name", ""))
	current_selected_payload = payload.duplicate(true)
	_show_selected_payload()

# Pushes the current selected province payload into the info controls.
# Vuelca el payload actual de provincia seleccionada en los controles de informaci?n.
func _show_selected_payload() -> void:
	if province_info_panel == null:
		return
	province_info_title.text = current_selected_name
	province_info_population.text = Localization.t("game.province.population", [str(current_selected_payload.get("population", "0"))])
	province_info_owner.text = Localization.t("game.province.country", [str(current_selected_payload.get("owner_name", Localization.t("game.country.unknown")))])
	province_info_cultivable_land.text = Localization.t("game.province.cultivable_land", [str(current_selected_payload.get("cultivable_land", "0"))])
	province_info_buildings.text = Localization.t("game.province.buildings", [str(current_selected_payload.get("buildings", Localization.t("game.province.wip")))])
	province_info_resources.text = Localization.t("game.province.resources", [str(current_selected_payload.get("resources", Localization.t("game.province.wip")))])
	var extra_text: String = str(current_selected_payload.get("extra", Localization.t("game.province.wip")))
	var terrain_text: String = str(current_selected_payload.get("terrain", Localization.t("game.province.wip")))
	var municipalities_text: String = str(current_selected_payload.get("municipalities", Localization.t("game.province.wip")))
	province_info_extra.text = "%s\n%s: %s\n%s: %s" % [extra_text, Localization.t("game.province.terrain"), terrain_text, Localization.t("game.province.municipalities"), municipalities_text]
	province_info_panel.position = _clamp_panel_to_viewport(province_info_panel.position, province_info_panel)
	province_info_panel.visible = true

# Hides the province information window.
# Oculta la ventana de informaci?n de provincia.
func hide_province_info() -> void:
	if province_info_panel != null:
		province_info_dragging = false
		province_info_panel.visible = false

# Returns whether the province information window is open.
# Devuelve si la ventana de informaci?n de provincia est? abierta.
func is_province_info_visible() -> bool:
	return province_info_panel != null and province_info_panel.visible

# Shows the province hover tooltip next to the mouse.
# Muestra el tooltip de hover de provincia junto al rat?n.
func show_hover_name(name: String, mouse_pos: Vector2) -> void:
	if hover_name_panel == null:
		return
	if intro_active or get_tree().paused:
		hover_name_panel.visible = false
		return
	if is_mouse_over_top_menu(mouse_pos):
		hover_name_panel.visible = false
		return
	hover_name_label.text = name
	var panel_size: Vector2 = hover_name_panel.get_combined_minimum_size()
	var viewport_size: Vector2 = _get_viewport_size()
	var desired_position: Vector2 = mouse_pos + Vector2(20, -6)
	hover_name_panel.position = Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, viewport_size.y - panel_size.y))
	)
	hover_name_panel.visible = true

# Hides the province hover tooltip.
# Oculta el tooltip de hover de provincia.
func hide_hover_name() -> void:
	if hover_name_panel != null:
		hover_name_panel.visible = false

# Checks whether the mouse is over UI that should block province hover.
# Comprueba si el rat?n est? sobre UI que debe bloquear el hover de provincias.
func is_mouse_over_top_menu(mouse_pos: Vector2) -> bool:
	if top_menu_panel != null and Rect2(top_menu_panel.global_position, top_menu_panel.size).has_point(mouse_pos):
		return true
	if technology_panel != null and technology_panel.visible and Rect2(technology_panel.global_position, technology_panel.size).has_point(mouse_pos):
		return true
	if debug_panel != null and debug_panel.visible and Rect2(debug_panel.global_position, debug_panel.size).has_point(mouse_pos):
		return true
	if event_popup_panel != null and event_popup_panel.visible and Rect2(event_popup_panel.global_position, event_popup_panel.size).has_point(mouse_pos):
		return true
	return false

# Returns whether an event popup is currently open.
# Devuelve si actualmente hay un popup de evento abierto.
func is_event_popup_visible() -> bool:
	return event_popup_panel != null and event_popup_panel.visible

# Clears every option row from the current event popup.
# Limpia todas las filas de opciones del popup de evento actual.
func _clear_event_popup_options() -> void:
	if event_popup_options_container == null:
		return
	for child in event_popup_options_container.get_children():
		child.queue_free()

# Formats consequence data into a short readable string for the UI.
# Formatea los datos de consecuencias en una cadena corta legible para la UI.
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

# Shows a configurable event popup with image, text, options, and consequences.
# Muestra un popup de evento configurable con imagen, texto, opciones y consecuencias.
func show_event_popup(event_data: Dictionary) -> void:
	if event_popup_panel == null:
		return

	current_event_id = str(event_data.get("id", ""))
	event_popup_title_label.text = str(event_data.get("title", "Event"))
	event_popup_text_label.text = str(event_data.get("text", ""))
	_clear_event_popup_options()

	var image_texture: Texture2D = null
	var image_value: Variant = event_data.get("image_texture", null)
	if image_value is Texture2D:
		image_texture = image_value
	elif event_data.has("image_path"):
		var loaded_resource: Resource = load(str(event_data.get("image_path", "")))
		if loaded_resource is Texture2D:
			image_texture = loaded_resource

	if event_popup_image != null:
		event_popup_image.texture = image_texture
		event_popup_image.visible = image_texture != null

	var options: Array = event_data.get("options", [])
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option_data: Dictionary = option_value
		var option_row: VBoxContainer = VBoxContainer.new()
		option_row.add_theme_constant_override("separation", 4)
		event_popup_options_container.add_child(option_row)

		var option_button: Button = Button.new()
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
			var consequences_label: Label = Label.new()
			consequences_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			consequences_label.self_modulate = Color(0.76, 0.8, 0.86, 0.88)
			consequences_label.text = _format_event_consequences(option_data.get("consequences", {}))
			option_row.add_child(consequences_label)

	_center_event_popup()
	event_popup_panel.visible = true
	hide_hover_name()
	hide_pause_menu()
	hide_debug_panel()
	hide_technology_panel()

# Hides the current event popup and clears its selected id.
# Oculta el popup de evento actual y limpia su id seleccionado.
func hide_event_popup() -> void:
	if event_popup_panel != null:
		event_popup_panel.visible = false
	current_event_id = ""

# Centers the event popup on screen.
# Centra el popup de evento en pantalla.
func _center_event_popup() -> void:
	if event_popup_panel == null:
		return
	var viewport_size: Vector2 = _get_viewport_size()
	var panel_size: Vector2 = event_popup_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = event_popup_panel.get_combined_minimum_size()
	event_popup_panel.position = Vector2(
		maxf(0.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(0.0, (viewport_size.y - panel_size.y) * 0.5)
	)

# Opens or closes the debug panel.
# Abre o cierra el panel de debug.
func toggle_debug_panel() -> void:
	if debug_panel == null:
		return
	if debug_panel.visible:
		hide_debug_panel()
	else:
		show_debug_panel()

# Opens the debug panel and syncs it with current debug settings.
# Abre el panel de debug y lo sincroniza con los ajustes debug actuales.
func show_debug_panel() -> void:
	if debug_panel == null:
		return
	_center_debug_panel()
	if debug_country_colors_checkbox != null:
		debug_country_colors_checkbox.button_pressed = DebugSettings.show_country_colors
	if debug_show_sea_checkbox != null:
		debug_show_sea_checkbox.button_pressed = DebugSettings.show_sea
	debug_panel.visible = true
	hide_hover_name()

# Hides the debug panel.
# Oculta el panel de debug.
func hide_debug_panel() -> void:
	if debug_panel != null:
		debug_panel.visible = false

# Centers the debug panel on screen.
# Centra el panel de debug en pantalla.
func _center_debug_panel() -> void:
	if debug_panel == null:
		return
	var viewport_size: Vector2 = _get_viewport_size()
	var panel_size: Vector2 = debug_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = debug_panel.get_combined_minimum_size()
	debug_panel.position = Vector2(
		maxf(0.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(0.0, (viewport_size.y - panel_size.y) * 0.5)
	)

# Opens or closes the technology panel.
# Abre o cierra el panel de tecnolog?a.
func toggle_technology_panel() -> void:
	if technology_panel == null:
		return
	if technology_panel.visible:
		hide_technology_panel()
	else:
		show_technology_panel()

# Opens the technology panel and refreshes its layout.
# Abre el panel de tecnolog?a y refresca su layout.
func show_technology_panel() -> void:
	if technology_panel == null:
		return
	_layout_technology_panel()
	technology_panel.visible = true
	hide_hover_name()

# Hides the technology panel.
# Oculta el panel de tecnolog?a.
func hide_technology_panel() -> void:
	if technology_panel != null:
		technology_panel.visible = false

# Opens the pause menu and hides panels that should not overlap it.
# Abre el men? de pausa y oculta paneles que no deben superponerse.
func show_pause_menu() -> void:
	if pause_menu_panel != null:
		pause_menu_panel.visible = true
		center_pause_menu()
	hide_technology_panel()
	hide_debug_panel()
	hide_hover_name()

# Hides the pause menu and any debug panel opened from it.
# Oculta el men? de pausa y cualquier panel de debug abierto desde ?l.
func hide_pause_menu() -> void:
	if pause_menu_panel != null:
		pause_menu_panel.visible = false
	hide_debug_panel()

# Returns whether the pause menu is currently visible.
# Devuelve si el men? de pausa est? visible actualmente.
func is_pause_menu_visible() -> bool:
	return pause_menu_panel != null and pause_menu_panel.visible

# Centers the pause menu on screen.
# Centra el men? de pausa en pantalla.
func center_pause_menu() -> void:
	if pause_menu_panel == null:
		return
	var viewport_size: Vector2 = _get_viewport_size()
	var panel_size: Vector2 = pause_menu_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = pause_menu_panel.get_combined_minimum_size()
	pause_menu_panel.position = Vector2(
		maxf(0.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(0.0, (viewport_size.y - panel_size.y) * 0.5)
	)

# Updates the displayed date text.
# Actualiza el texto de fecha mostrado.
func set_game_date_text(date_text: String) -> void:
	if date_label != null:
		date_label.text = date_text

# Updates the selected time speed button state.
# Actualiza el estado del bot?n de velocidad de tiempo seleccionado.
func set_game_speed(speed: int) -> void:
	current_speed = speed
	for i in range(speed_buttons.size()):
		speed_buttons[i].disabled = (i + 1) == current_speed

# Updates the pause button label and tooltip.
# Actualiza la etiqueta y el tooltip del bot?n de pausa.
func set_time_paused(value: bool) -> void:
	current_time_paused = value
	if pause_toggle_button != null:
		if current_time_paused and not is_pause_menu_visible():
			pause_toggle_button.text = ">"
			pause_toggle_button.tooltip_text = Localization.t("game.resume_time")
		else:
			pause_toggle_button.text = "||"
			pause_toggle_button.tooltip_text = Localization.t("game.pause_time")

# Starts the opening camera animation and blocks regular input during it.
# Inicia la animaci?n inicial de c?mara y bloquea la entrada normal durante ella.
func start_intro(camera: Camera2D) -> void:
	if intro_overlay == null or camera == null:
		return
	intro_camera = camera
	intro_active = true
	intro_skip_requested = false
	intro_overlay.visible = true
	hide_hover_name()
	hide_province_info()
	hide_pause_menu()
	intro_camera.input_enabled = false
	intro_original_camera_position = intro_camera.position
	intro_original_camera_zoom = intro_camera.zoom
	intro_camera.position = intro_original_camera_position + Vector2(260, -160)
	intro_camera.zoom = intro_original_camera_zoom + Vector2(0.35, 0.35)
	intro_fade_rect.color = Color(0.01, 0.02, 0.04, 0.68)
	intro_top_bar.color = Color.BLACK
	intro_bottom_bar.color = Color.BLACK
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(intro_camera, "position", intro_original_camera_position, INTRO_ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(intro_camera, "zoom", intro_original_camera_zoom, INTRO_ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(intro_fade_rect, "color:a", 0.0, INTRO_ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(intro_top_bar, "color:a", 0.0, INTRO_ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(intro_bottom_bar, "color:a", 0.0, INTRO_ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.finished.connect(func() -> void:
		if intro_active:
			_end_intro_animation()
	)

# Returns whether the intro sequence is still active.
# Devuelve si la secuencia de intro sigue activa.
func is_intro_active() -> bool:
	return intro_active

# Requests that the intro should be skipped on the next frame.
# Solicita que la intro se salte en el siguiente frame.
func request_intro_skip() -> void:
	intro_skip_requested = true

# Animates the intro skip hint opacity.
# Anima la opacidad de la pista para saltar la intro.
func _update_intro_skip_hint() -> void:
	if intro_skip == null:
		return
	intro_skip.modulate.a = 0.55 + (sin(Time.get_ticks_msec() / 180.0) + 1.0) * 0.18

# Stops the intro sequence and restores normal camera control.
# Detiene la secuencia de intro y restaura el control normal de c?mara.
func _end_intro_animation() -> void:
	if intro_tween != null:
		intro_tween.kill()
		intro_tween = null
	intro_active = false
	intro_skip_requested = false
	if intro_overlay != null:
		intro_overlay.visible = false
	if intro_camera != null:
		intro_camera.position = intro_original_camera_position
		intro_camera.zoom = intro_original_camera_zoom
		intro_camera.input_enabled = true

# Shows a generic popup for not-yet-implemented features.
# Muestra un popup gen?rico para funciones a?n no implementadas.
func show_coming_soon_popup(title: String, icon_label: String = "") -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = title
	if icon_label == "":
		dialog.dialog_text = Localization.t("ui.coming_soon")
	else:
		dialog.dialog_text = "%s\n%s" % [Localization.t("ui.coming_soon"), Localization.t("game.temp_icon", [icon_label])]
	dialog.ok_button_text = Localization.t("ui.ok")
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())

# Refreshes all translated labels and active UI texts.
# Refresca todas las etiquetas traducidas y los textos activos de la UI.
func _apply_language() -> void:
	if intro_skip != null:
		intro_skip.text = Localization.t("game.intro_skip")
	if pause_menu_title_label != null:
		pause_menu_title_label.text = Localization.t("game.pause_menu")
	for button in pause_menu_buttons:
		var key: String = str(button.get_meta("translation_key", ""))
		if key != "":
			button.text = Localization.t(key)
	for i in range(min(top_menu_buttons.size(), top_menu_title_keys.size())):
		top_menu_buttons[i].tooltip_text = Localization.t(top_menu_title_keys[i])
	if technology_title_label != null:
		technology_title_label.text = Localization.t("game.tech.title")
	if debug_title_label != null:
		debug_title_label.text = Localization.t("debug.title")
	if debug_country_colors_checkbox != null:
		debug_country_colors_checkbox.text = Localization.t("debug.country_colors")
	if debug_show_sea_checkbox != null:
		debug_show_sea_checkbox.text = Localization.t("debug.show_sea")
	if technology_tab_container != null:
		for i in range(min(technology_tab_container.get_tab_count(), technology_tab_title_keys.size())):
			technology_tab_container.set_tab_title(i, Localization.t(technology_tab_title_keys[i]))
	if technology_section_labels.size() == technology_tab_title_keys.size():
		for i in range(technology_section_labels.size()):
			technology_section_labels[i].text = Localization.t(technology_tab_title_keys[i])
	if technology_tab_labels.size() == technology_tab_title_keys.size():
		for i in range(technology_tab_labels.size()):
			technology_tab_labels[i].text = Localization.t("game.tech.placeholder", [Localization.t(technology_tab_title_keys[i])])
	if terrain_title_label != null:
		terrain_title_label.text = Localization.t("game.province.terrain")
	if terrain_placeholder_label != null:
		terrain_placeholder_label.text = Localization.t("game.province.wip")
	if municipalities_title_label != null:
		municipalities_title_label.text = Localization.t("game.province.municipalities")
	if municipalities_placeholder_label != null:
		municipalities_placeholder_label.text = Localization.t("game.province.wip")
	set_time_paused(current_time_paused)
	set_game_speed(current_speed)
	if current_selected_gid != "" and is_province_info_visible():
		_show_selected_payload()

# Re-applies translated UI after the language changes.
# Vuelve a aplicar la UI traducida despu?s de que cambie el idioma.
func _on_language_changed(_language_code: String) -> void:
	_apply_language()
