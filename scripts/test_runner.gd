extends Node

const PROVINCES_PATH: String = "res://data/provinces_with_gid.json"
const COUNTRIES_PATH: String = "res://data/countries.json"
const TIPS_PATH: String = "res://data/loading_tips.json"

var passed: int = 0
var failed: int = 0

# Runs the full test suite when the scene starts.
# Ejecuta toda la batería de tests al iniciar la escena.
func _ready() -> void:
	_run_all_tests()
	print("")
	print("Tests completados. OK: %d | ERROR: %d" % [passed, failed])
	if failed > 0:
		push_error("Han fallado %d tests." % failed)

# Executes every grouped test case in a fixed order.
# Ejecuta cada grupo de tests en un orden fijo.
func _run_all_tests() -> void:
	_test_province_data_schema()
	_test_country_data_schema()
	_test_province_manager_color_resolution()
	_test_province_manager_owner_set_get()
	_test_province_manager_save_roundtrip()
	_test_province_manager_mining_limits()
	_test_province_manager_overlay_builders()
	_test_nation_manager_load_and_lookup()
	_test_nation_manager_owner_transfer()
	_test_nation_manager_save_roundtrip()
	_test_loading_tips_loader()
	_test_textures_helpers()
	_test_scene_resources_load()

# Records one boolean assertion result and logs it.
# Registra el resultado de una aserción booleana y lo muestra.
func _assert_true(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[OK] %s" % message)
	else:
		failed += 1
		push_error("[ERROR] %s" % message)

# Compares two values and forwards the result to the generic assertion helper.
# Compara dos valores y delega el resultado al helper genérico de aserciones.
func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s | esperado=%s actual=%s" % [message, str(expected), str(actual)])

# Loads and parses one JSON file from disk.
# Carga y parsea un archivo JSON desde disco.
func _load_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(text)

# Creates a temporary JSON file used by save/load roundtrip tests.
# Crea un archivo JSON temporal usado por los tests de guardar/cargar.
func _create_temp_json_file(file_name: String, data: Variant) -> String:
	var dir_path: String = "user://tests"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path: String = "%s/%s" % [dir_path, file_name]
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return file_path

# Validates the province JSON base schema.
# Valida el esquema base del JSON de provincias.
func _test_province_data_schema() -> void:
	var data: Variant = _load_json(PROVINCES_PATH)
	_assert_true(typeof(data) == TYPE_ARRAY and data.size() > 0, "El JSON de provincias carga y contiene elementos")
	if typeof(data) != TYPE_ARRAY or data.is_empty():
		return

	var first: Dictionary = data[0]
	_assert_true(first.has("gid"), "Cada provincia tiene gid")
	_assert_true(first.has("nombre"), "Cada provincia tiene nombre")
	_assert_true(first.has("color"), "Cada provincia tiene color")
	_assert_true(first.has("population"), "Cada provincia tiene bloque population")
	_assert_true(first.has("buildings"), "Cada provincia tiene bloque buildings")
	_assert_true(first.has("resources"), "Cada provincia tiene bloque resources")
	_assert_true(first.has("cultivable_land"), "Cada provincia tiene bloque cultivable_land")
	_assert_true(typeof(first["buildings"]) == TYPE_DICTIONARY and first["buildings"].has("mining_limits"), "Cada provincia tiene mining_limits provisionales")
	_assert_true(typeof(first["resources"]) == TYPE_DICTIONARY and first["resources"].has("mining"), "Cada provincia tiene bloque resources.mining")
	_assert_true(typeof(first["resources"]) == TYPE_DICTIONARY and first["resources"].has("agricultural"), "Cada provincia tiene bloque resources.agricultural")

# Validates the country JSON base schema.
# Valida el esquema base del JSON de países.
func _test_country_data_schema() -> void:
	var data: Variant = _load_json(COUNTRIES_PATH)
	_assert_true(typeof(data) == TYPE_ARRAY and data.size() > 0, "El JSON de paises carga y contiene elementos")
	if typeof(data) != TYPE_ARRAY or data.is_empty():
		return

	var first: Dictionary = data[0]
	_assert_true(first.has("id"), "Cada pais tiene id")
	_assert_true(first.has("name"), "Cada pais tiene name")
	_assert_true(first.has("color"), "Cada pais tiene color")
	_assert_true(first.has("provinces"), "Cada pais tiene lista de provincias")

# Checks exact and tolerant province color resolution.
# Comprueba la resolución de colores de provincia exacta y con tolerancia.
func _test_province_manager_color_resolution() -> void:
	var manager: ProvinceManager = ProvinceManager.new()
	manager.load_from_file(PROVINCES_PATH)
	_assert_true(manager.provinces_by_gid.size() > 0, "ProvinceManager carga provincias")
	_assert_equal(manager.get_gid_by_color(Color.from_rgba8(206, 181, 20, 255)), "ES-0006", "ProvinceManager resuelve color exacto")
	_assert_equal(manager.get_gid_by_color(Color(207.0 / 255.0, 181.0 / 255.0, 20.0 / 255.0, 1.0)), "ES-0006", "ProvinceManager resuelve color con tolerancia")

# Checks manual owner assignment in ProvinceManager.
# Comprueba la asignación manual de dueño en ProvinceManager.
func _test_province_manager_owner_set_get() -> void:
	var manager: ProvinceManager = ProvinceManager.new()
	manager.load_from_file(PROVINCES_PATH)
	manager.set_province_owner("ES-0001", "ES")
	_assert_equal(manager.get_province_owner("ES-0001"), "ES", "ProvinceManager guarda owner manual")

# Verifies ProvinceManager save/load roundtrip behavior.
# Verifica el comportamiento de guardar/cargar de ProvinceManager.
func _test_province_manager_save_roundtrip() -> void:
	var manager: ProvinceManager = ProvinceManager.new()
	manager.load_from_file(PROVINCES_PATH)
	manager.set_province_owner("ES-0001", "ES")
	var temp_path: String = _create_temp_json_file("province_roundtrip.json", [])
	var saved: bool = manager.save_to_file(temp_path)
	_assert_true(saved, "ProvinceManager guarda JSON temporal")
	var reloaded: ProvinceManager = ProvinceManager.new()
	reloaded.load_from_file(temp_path)
	_assert_equal(reloaded.get_province_owner("ES-0001"), "ES", "ProvinceManager recupera owner tras guardar/cargar")
	_assert_true(reloaded.provinces_by_gid["ES-0001"].has("population"), "ProvinceManager conserva estructura population")

# Verifies temporary mining building caps and construction limits.
# Verifica los límites temporales de edificios mineros y su restricción.
func _test_province_manager_mining_limits() -> void:
	var manager: ProvinceManager = ProvinceManager.new()
	manager.load_from_file(PROVINCES_PATH)
	_assert_true(manager.get_mining_building_limit("ES-0006", "carbon") > 0, "ProvinceManager expone limite para edificios mineros")
	_assert_true(manager.can_build_mining_building("ES-0006", "carbon"), "ProvinceManager permite construir si hay hueco")
	var first_build_ok: bool = manager.add_mining_building("ES-0006", "carbon")
	var second_build_ok: bool = manager.add_mining_building("ES-0006", "carbon")
	var third_build_ok: bool = manager.add_mining_building("ES-0006", "carbon")
	_assert_true(first_build_ok, "ProvinceManager construye primer edificio minero")
	_assert_true(second_build_ok, "ProvinceManager construye hasta el limite provisional")
	_assert_true(not third_build_ok, "ProvinceManager bloquea construccion por encima del limite")

# Validates owner overlay and selection overlay image builders.
# Valida los constructores de imagen para overlay de dueño y selección.
func _test_province_manager_overlay_builders() -> void:
	var manager: ProvinceManager = ProvinceManager.new()
	manager.provinces_by_gid = {
		"A": {"gid": "A", "nombre": "A", "color": Color.from_rgba8(10, 20, 30, 255), "owner": "ES"},
		"B": {"gid": "B", "nombre": "B", "color": Color.from_rgba8(40, 50, 60, 255), "owner": null}
	}
	manager.color_to_gid = {
		Color.from_rgba8(10, 20, 30, 255): "A",
		Color.from_rgba8(40, 50, 60, 255): "B"
	}
	manager.rgb_to_gid = {
		manager._rgb_key_from_ints(10, 20, 30): "A",
		manager._rgb_key_from_ints(40, 50, 60): "B"
	}

	var image: Image = Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.from_rgba8(10, 20, 30, 255))
	image.set_pixel(1, 0, Color.from_rgba8(40, 50, 60, 255))
	var texture: ImageTexture = ImageTexture.create_from_image(image)

	var nation_manager: NationManager = NationManager.new()
	nation_manager.nations["ES"]["provinces"] = ["A"]
	nation_manager.province_to_nation["A"] = "ES"

	var overlay: Image = manager.recolor_overlay_from_color_map(texture, nation_manager)
	_assert_true(overlay.get_pixel(0, 0).a > 0.0, "ProvinceManager pinta overlay del propietario")
	_assert_equal(overlay.get_pixel(1, 0).a, 0.0, "ProvinceManager deja transparente provincia sin owner")

	var selection: Image = manager.build_selection_overlay(texture, "A")
	_assert_true(selection.get_pixel(0, 0).a > 0.0, "ProvinceManager pinta seleccion de provincia")
	_assert_equal(selection.get_pixel(1, 0).a, 0.0, "ProvinceManager no pinta otras provincias en seleccion")

# Checks that NationManager loads countries and resolves ownership.
# Comprueba que NationManager carga países y resuelve propiedad.
func _test_nation_manager_load_and_lookup() -> void:
	var manager: NationManager = NationManager.new()
	manager.load_from_file(COUNTRIES_PATH)
	_assert_true(manager.has_nation("ES"), "NationManager detecta Spain")
	_assert_equal(manager.get_nation_name("ES"), "Spain", "NationManager devuelve nombre de pais")
	_assert_equal(manager.get_province_owner("ES-0001"), "ES", "NationManager resuelve propietario por gid")

# Checks province transfer logic inside NationManager.
# Comprueba la lógica de transferencia de provincias en NationManager.
func _test_nation_manager_owner_transfer() -> void:
	var manager: NationManager = NationManager.new()
	manager.load_from_file(COUNTRIES_PATH)
	manager.set_province_owner("ES-0001", "PT")
	_assert_equal(manager.get_province_owner("ES-0001"), "PT", "NationManager transfiere una provincia")
	_assert_true(not manager.nations["ES"]["provinces"].has("ES-0001"), "NationManager elimina provincia del pais anterior")
	_assert_true(manager.nations["PT"]["provinces"].has("ES-0001"), "NationManager añade provincia al nuevo pais")

# Verifies NationManager save/load roundtrip behavior.
# Verifica el comportamiento de guardar/cargar de NationManager.
func _test_nation_manager_save_roundtrip() -> void:
	var manager: NationManager = NationManager.new()
	manager.load_from_file(COUNTRIES_PATH)
	manager.set_province_owner("PT-0001", "ES")
	var temp_path: String = _create_temp_json_file("nation_roundtrip.json", [])
	var saved: bool = manager.save_to_file(temp_path)
	_assert_true(saved, "NationManager guarda JSON temporal")
	var reloaded: NationManager = NationManager.new()
	reloaded.load_from_file(temp_path)
	_assert_equal(reloaded.get_province_owner("PT-0001"), "ES", "NationManager conserva ownership tras guardar/cargar")

# Checks loading tip parsing and translation support.
# Comprueba el parseo de consejos de carga y su soporte de traducción.
func _test_loading_tips_loader() -> void:
	var loading_script: GDScript = load("res://scripts/loading_screen.gd")
	var loading_screen: Control = loading_script.new()
	var tips: Array = loading_screen._load_tips()
	_assert_true(tips.size() > 0, "LoadingScreen carga consejos desde JSON")
	_assert_true(typeof(tips[0]) == TYPE_DICTIONARY, "LoadingScreen devuelve consejos bilingues")
	_assert_true(str(Localization.translate_tip(tips[0])).length() > 0, "LoadingScreen puede traducir un consejo cargado")
	loading_screen.queue_free()

# Validates helper formatting functions exposed by textures.gd.
# Valida funciones helper de formato expuestas por textures.gd.
func _test_textures_helpers() -> void:
	var textures_script: GDScript = load("res://scripts/textures.gd")
	var textures_node: Node2D = textures_script.new()
	_assert_equal(textures_node._format_population(1234567), "1.234.567", "textures.gd formatea poblacion")
	_assert_equal(textures_node._get_population_value({"population": {"year": 1835, "value": 123, "status": "estimated"}}), 123, "textures.gd lee bloque population")
	_assert_equal(textures_node._format_status_list_field({"status": "work in progress", "entries": []}), "work in progress", "textures.gd formatea estado sin entries")
	_assert_equal(textures_node._format_status_list_field({"status": "ok", "entries": ["Port", "Rail"]}), "Port, Rail", "textures.gd formatea entries")
	textures_node.queue_free()

# Confirms that the main scenes can be loaded as resources.
# Confirma que las escenas principales pueden cargarse como recursos.
func _test_scene_resources_load() -> void:
	_assert_true(load("res://scenes/Main.tscn") is PackedScene, "Main.tscn carga como escena")
	_assert_true(load("res://scenes/MainMenu.tscn") is PackedScene, "MainMenu.tscn carga como escena")
	_assert_true(load("res://scenes/LoadingScreen.tscn") is PackedScene, "LoadingScreen.tscn carga como escena")
