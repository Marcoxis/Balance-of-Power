extends CanvasLayer

class_name GameUI

signal resume_requested
signal return_to_main_menu_requested
signal quit_requested
signal time_pause_toggled
signal time_speed_selected(speed: int)

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

var hover_name_panel: PanelContainer = null
var hover_name_label: Label = null

var top_menu_panel: PanelContainer = null
var top_menu_buttons: Array[Button] = []
var top_menu_title_keys: Array[String] = []

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)
	_create_ui()
	_apply_language()

func _process(_delta: float) -> void:
	if intro_active:
		_update_intro_skip_hint()
		if intro_skip_requested:
			_end_intro_animation()

func _create_ui() -> void:
	_create_province_info_panel()
	_create_pause_menu()
	_create_hover_name_panel()
	_create_top_menu()
	_create_top_bar()
	_create_intro_overlay()

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

	province_info_panel.position = _clamp_panel_to_viewport(Vector2(24, get_viewport_rect().size.y - 564), province_info_panel)

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
		button.pressed.connect(func(title_key: String = str(button_data["key"]), menu_icon: String = str(button_data["icon"])) -> void:
			show_coming_soon_popup(Localization.t(title_key), menu_icon)
		)
		buttons_box.add_child(button)
		top_menu_buttons.append(button)
		top_menu_title_keys.append(str(button_data["key"]))

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

func _on_province_info_header_gui_input(event: InputEvent) -> void:
	if province_info_panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		province_info_dragging = event.pressed
		if province_info_dragging:
			province_info_drag_offset = province_info_panel.position - get_global_mouse_position()
	elif event is InputEventMouseMotion and province_info_dragging:
		province_info_panel.position = _clamp_panel_to_viewport(get_global_mouse_position() + province_info_drag_offset, province_info_panel)

func _clamp_panel_to_viewport(target_position: Vector2, panel: Control) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = panel.size
	if panel_size == Vector2.ZERO:
		panel_size = panel.get_combined_minimum_size()
	return Vector2(
		clampf(target_position.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x)),
		clampf(target_position.y, 0.0, maxf(0.0, viewport_size.y - panel_size.y))
	)

func set_selected_province(gid: String, payload: Dictionary) -> void:
	current_selected_gid = gid
	current_selected_name = str(payload.get("name", ""))
	current_selected_payload = payload.duplicate(true)
	_show_selected_payload()

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

func hide_province_info() -> void:
	if province_info_panel != null:
		province_info_dragging = false
		province_info_panel.visible = false

func is_province_info_visible() -> bool:
	return province_info_panel != null and province_info_panel.visible

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
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired_position: Vector2 = mouse_pos + Vector2(20, -6)
	hover_name_panel.position = Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, viewport_size.y - panel_size.y))
	)
	hover_name_panel.visible = true

func hide_hover_name() -> void:
	if hover_name_panel != null:
		hover_name_panel.visible = false

func is_mouse_over_top_menu(mouse_pos: Vector2) -> bool:
	if top_menu_panel == null:
		return false
	return Rect2(top_menu_panel.global_position, top_menu_panel.size).has_point(mouse_pos)

func show_pause_menu() -> void:
	if pause_menu_panel != null:
		pause_menu_panel.visible = true
		center_pause_menu()
	hide_hover_name()

func hide_pause_menu() -> void:
	if pause_menu_panel != null:
		pause_menu_panel.visible = false

func is_pause_menu_visible() -> bool:
	return pause_menu_panel != null and pause_menu_panel.visible

func center_pause_menu() -> void:
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

func set_game_date_text(date_text: String) -> void:
	if date_label != null:
		date_label.text = date_text

func set_game_speed(speed: int) -> void:
	current_speed = speed
	for i in range(speed_buttons.size()):
		speed_buttons[i].disabled = (i + 1) == current_speed

func set_time_paused(value: bool) -> void:
	current_time_paused = value
	if pause_toggle_button != null:
		if current_time_paused and not is_pause_menu_visible():
			pause_toggle_button.text = ">"
			pause_toggle_button.tooltip_text = Localization.t("game.resume_time")
		else:
			pause_toggle_button.text = "||"
			pause_toggle_button.tooltip_text = Localization.t("game.pause_time")

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

func is_intro_active() -> bool:
	return intro_active

func request_intro_skip() -> void:
	intro_skip_requested = true

func _update_intro_skip_hint() -> void:
	if intro_skip == null:
		return
	intro_skip.modulate.a = 0.55 + (sin(Time.get_ticks_msec() / 180.0) + 1.0) * 0.18

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

func _on_language_changed(_language_code: String) -> void:
	_apply_language()
