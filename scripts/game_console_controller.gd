extends RefCounted

class_name GameConsoleController

const CONSOLE_MAX_LINES := 28
const CONSOLE_COMMANDS := [
	"help",
	"clear",
	"close",
	"pause",
	"resume",
	"refresh_map",
	"event_test",
	"select",
	"set_owner",
	"get_day_speed",
	"set_day_speed"
]

var scene_tree: SceneTree = null
var console_panel: PanelContainer = null
var console_output: RichTextLabel = null
var console_input: LineEdit = null
var world_camera: Camera2D = null
var pause_menu_panel: PanelContainer = null
var province_manager: ProvinceManager = null
var nation_manager: NationManager = null
var time_controller: GameTimeController = null
var on_refresh_map: Callable = Callable()
var on_open_test_event: Callable = Callable()
var on_select_province: Callable = Callable()
var on_set_owner: Callable = Callable()
var on_resume_game: Callable = Callable()
var console_lines: Array[String] = []

# Configures the console controller with UI references and gameplay callbacks.
# Configura el controlador de consola con referencias de UI y callbacks del juego.
func setup(
	tree_ref: SceneTree,
	panel_ref: PanelContainer,
	output_ref: RichTextLabel,
	input_ref: LineEdit,
	camera_ref: Camera2D,
	pause_panel_ref: PanelContainer,
	province_manager_ref: ProvinceManager,
	nation_manager_ref: NationManager,
	time_controller_ref: GameTimeController,
	refresh_map_callback: Callable,
	open_test_event_callback: Callable,
	select_province_callback: Callable,
	set_owner_callback: Callable,
	resume_game_callback: Callable
) -> void:
	scene_tree = tree_ref
	console_panel = panel_ref
	console_output = output_ref
	console_input = input_ref
	world_camera = camera_ref
	pause_menu_panel = pause_panel_ref
	province_manager = province_manager_ref
	nation_manager = nation_manager_ref
	time_controller = time_controller_ref
	on_refresh_map = refresh_map_callback
	on_open_test_event = open_test_event_callback
	on_select_province = select_province_callback
	on_set_owner = set_owner_callback
	on_resume_game = resume_game_callback

	if console_lines.is_empty():
		append_line("Type 'help' to list available commands.")

# Returns whether the console is currently visible.
# Devuelve si la consola está visible actualmente.
func is_visible() -> bool:
	return console_panel != null and console_panel.visible

# Detects the keyboard shortcut used to toggle the console.
# Detecta el atajo de teclado usado para alternar la consola.
func is_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false

	return key_event.physical_keycode == KEY_QUOTELEFT or key_event.unicode == 186 or key_event.unicode == 170

# Opens the console and focuses its input field.
# Abre la consola y enfoca su campo de entrada.
func show_console() -> void:
	if console_panel == null:
		return
	console_panel.visible = true
	_set_camera_input_enabled(false)
	if console_input != null:
		console_input.editable = true
		console_input.mouse_filter = Control.MOUSE_FILTER_STOP
		console_input.grab_focus()

# Hides the console and clears the current input field.
# Oculta la consola y limpia el campo de entrada actual.
func hide_console() -> void:
	if console_panel == null:
		return
	console_panel.visible = false
	_set_camera_input_enabled(true)
	if console_input != null:
		console_input.text = ""
		console_input.release_focus()

# Toggles the visibility of the console.
# Alterna la visibilidad de la consola.
func toggle_console() -> void:
	if is_visible():
		hide_console()
	else:
		show_console()

# Appends one line to the console output and trims the history.
# Añade una línea a la salida de la consola y recorta el historial.
func append_line(line: String) -> void:
	console_lines.append(line)
	while console_lines.size() > CONSOLE_MAX_LINES:
		console_lines.remove_at(0)
	_refresh_output()

# Handles console-specific input such as tab completion.
# Gestiona entrada específica de consola como el autocompletado con tab.
func on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_TAB:
		_autocomplete_input()
		console_input.accept_event()

# Executes the current command line when submitted.
# Ejecuta la línea de comando actual cuando se envía.
func on_command_submitted(command_text: String) -> void:
	var raw_command: String = command_text.strip_edges()
	if raw_command == "":
		return

	append_line("> " + raw_command)
	if console_input != null:
		console_input.clear()
	_execute_command(raw_command)
	if console_input != null and is_visible():
		console_input.grab_focus()

# Rebuilds the visible console output from the stored history.
# Reconstruye la salida visible de la consola desde el historial guardado.
func _refresh_output() -> void:
	if console_output == null:
		return
	console_output.clear()
	for line in console_lines:
		console_output.append_text("%s\n" % line)
	console_output.scroll_to_line(max(0, console_lines.size() - 1))

# Enables or disables world camera input from the console.
# Activa o desactiva la entrada de la cámara del mundo desde la consola.
func _set_camera_input_enabled(enabled: bool) -> void:
	if world_camera != null:
		world_camera.input_enabled = enabled
		if not enabled:
			world_camera.arrastrando = false

# Autocompletes the current input using commands and known ids.
# Autocompleta la entrada actual usando comandos e ids conocidos.
func _autocomplete_input() -> void:
	if console_input == null:
		return

	var raw_text: String = console_input.text
	var ends_with_space: bool = raw_text.ends_with(" ")
	var stripped_text: String = raw_text.strip_edges()

	if stripped_text == "":
		_show_candidates(CONSOLE_COMMANDS)
		return

	var parts: PackedStringArray = stripped_text.split(" ", false)
	if parts.is_empty():
		return

	var matches: Array[String] = []
	var replacement_text: String = raw_text

	if parts.size() == 1 and not ends_with_space:
		matches = _filter_candidates(CONSOLE_COMMANDS, parts[0].to_lower())
		replacement_text = _build_autocomplete_result(raw_text, parts[0], matches)
	elif parts[0].to_lower() == "select":
		var gid_prefix: String = "" if ends_with_space else parts[parts.size() - 1]
		matches = _get_matching_province_gids(gid_prefix)
		replacement_text = _build_autocomplete_result(raw_text, gid_prefix, matches)
	elif parts[0].to_lower() == "set_owner":
		if parts.size() == 1 and ends_with_space:
			matches = _get_matching_province_gids("")
			_show_candidates(matches)
			return
		if parts.size() == 2 and not ends_with_space:
			var gid_prefix: String = parts[1]
			matches = _get_matching_province_gids(gid_prefix)
			replacement_text = _build_autocomplete_result(raw_text, gid_prefix, matches)
		else:
			var owner_prefix: String = "" if ends_with_space else parts[parts.size() - 1]
			matches = _get_matching_country_ids(owner_prefix)
			replacement_text = _build_autocomplete_result(raw_text, owner_prefix, matches)
	else:
		matches = _filter_candidates(CONSOLE_COMMANDS, parts[0].to_lower())
		if parts.size() == 1:
			replacement_text = _build_autocomplete_result(raw_text, parts[0], matches)

	if replacement_text != raw_text:
		console_input.text = replacement_text
		console_input.caret_column = console_input.text.length()
		return

	if matches.size() > 1:
		_show_candidates(matches)

# Executes one console command and writes feedback to the log.
# Ejecuta un comando de consola y escribe feedback en el log.
func _execute_command(raw_command: String) -> void:
	var parts: PackedStringArray = raw_command.split(" ", false)
	if parts.is_empty():
		return

	var command: String = parts[0].to_lower()
	match command:
		"help":
			append_line("help, clear, close, pause, resume, refresh_map, event_test, select <gid>, set_owner <gid> <country_id>, get_day_speed, set_day_speed <value>")
		"clear":
			console_lines.clear()
			_refresh_output()
		"close":
			hide_console()
		"pause":
			if scene_tree != null and scene_tree.paused:
				append_line("Game is already paused.")
			else:
				if pause_menu_panel != null:
					pause_menu_panel.visible = true
				if scene_tree != null:
					scene_tree.paused = true
				append_line("Game paused.")
		"resume":
			if scene_tree != null and not scene_tree.paused:
				append_line("Game is already running.")
			else:
				if on_resume_game.is_valid():
					on_resume_game.call()
				append_line("Game resumed.")
		"refresh_map":
			if on_refresh_map.is_valid():
				on_refresh_map.call()
			append_line("Political overlay refreshed.")
		"get_day_speed":
			if time_controller != null:
				append_line("Day speed multiplier: %s" % str(time_controller.get_multiplier()))
		"set_day_speed":
			if parts.size() < 2:
				append_line("Missing argument: speed multiplier")
				return
			if not parts[1].is_valid_float():
				append_line("Invalid number: %s" % parts[1])
				return
			var new_speed: float = parts[1].to_float()
			if time_controller != null:
				time_controller.set_multiplier(new_speed)
				append_line("Day speed multiplier set to: %s" % str(time_controller.get_multiplier()))
		"event_test":
			if on_open_test_event.is_valid():
				on_open_test_event.call()
			append_line("Test event opened.")
		"select":
			if parts.size() < 2:
				append_line("Missing argument: province gid")
				return
			var gid: String = parts[1]
			if province_manager == null or not province_manager.provinces_by_gid.has(gid):
				append_line("Unknown province gid: %s" % gid)
				return
			if on_select_province.is_valid():
				on_select_province.call(gid)
			append_line("Selected province: %s" % gid)
		"set_owner":
			if parts.size() < 2:
				append_line("Missing argument: province gid")
				return
			if parts.size() < 3:
				append_line("Missing argument: country id")
				return
			var gid: String = parts[1]
			var owner_id: String = parts[2].to_upper()
			if province_manager == null or not province_manager.provinces_by_gid.has(gid):
				append_line("Unknown province gid: %s" % gid)
				return
			if nation_manager == null or not nation_manager.has_nation(owner_id):
				append_line("Unknown country id: %s" % owner_id)
				return
			if on_set_owner.is_valid():
				on_set_owner.call(gid, owner_id)
			append_line("Owner changed: %s -> %s" % [gid, owner_id])
		_:
			append_line("unkow command")

# Filters candidates using a case-insensitive prefix match.
# Filtra candidatos usando una coincidencia por prefijo sin distinguir mayúsculas.
func _filter_candidates(candidates: Array, prefix: String) -> Array[String]:
	var matches: Array[String] = []
	var lowered_prefix: String = prefix.to_lower()
	for candidate_value in candidates:
		var candidate: String = str(candidate_value)
		if candidate.to_lower().begins_with(lowered_prefix):
			matches.append(candidate)
	return matches

# Returns matching province ids for autocomplete.
# Devuelve ids de provincia coincidentes para el autocompletado.
func _get_matching_province_gids(prefix: String) -> Array[String]:
	if province_manager == null:
		return []
	return _filter_candidates(province_manager.provinces_by_gid.keys(), prefix.to_upper())

# Returns matching country ids for autocomplete.
# Devuelve ids de país coincidentes para el autocompletado.
func _get_matching_country_ids(prefix: String) -> Array[String]:
	if nation_manager == null:
		return []
	return _filter_candidates(nation_manager.nations.keys(), prefix.to_upper())

# Builds the completed text after one autocomplete attempt.
# Construye el texto completado tras un intento de autocompletado.
func _build_autocomplete_result(raw_text: String, token: String, matches: Array[String]) -> String:
	if matches.is_empty():
		append_line("unkow command")
		return raw_text

	if matches.size() == 1:
		return raw_text.substr(0, raw_text.length() - token.length()) + matches[0] + " "

	var common_prefix: String = _get_common_prefix(matches)
	if common_prefix.length() > token.length():
		return raw_text.substr(0, raw_text.length() - token.length()) + common_prefix

	_show_candidates(matches)
	return raw_text

# Returns the longest common prefix shared by every provided string.
# Devuelve el prefijo común más largo compartido por todas las cadenas dadas.
func _get_common_prefix(values: Array[String]) -> String:
	if values.is_empty():
		return ""

	var prefix: String = values[0]
	for i in range(1, values.size()):
		var current: String = values[i]
		while not current.begins_with(prefix) and prefix.length() > 0:
			prefix = prefix.substr(0, prefix.length() - 1)
		if prefix == "":
			break
	return prefix

# Prints candidate suggestions in a compact console line.
# Imprime sugerencias candidatas en una línea compacta de consola.
func _show_candidates(matches: Array[String]) -> void:
	if matches.is_empty():
		return
	append_line("Suggestions: %s" % ", ".join(matches))
