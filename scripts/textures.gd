extends Node2D

@onready var white_map: TextureRect = $whiteMap
@onready var color_map: TextureRect = $colorMap

var provincias: Dictionary = {}

# Función para comparar colores con tolerancia
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
		# JSON.parse_string puede devolver un objeto con campos (.error, .result)
		# o directamente un Array según la versión/estado; manejar ambos casos.
		var data = null
		if typeof(parse_result) == TYPE_DICTIONARY and parse_result.has("error"):
			if parse_result.error == OK:
				data = parse_result.result
			else:
				push_error("Error al parsear provinces_with_gid.json: %s" % parse_result.get("error_string", "error desconocido"))
		else:
			# Si no viene el objeto esperado, asumir que la propia parse_result es la lista de provincias
			data = parse_result

		if data != null:
			for p in data:
				var r = int(p["color"][0])
				var g = int(p["color"][1])
				var b = int(p["color"][2])
				var color = Color.from_rgba8(r, g, b, 255)
				provincias[color] = {
					"gid": p.get("gid", ""),
					"nombre": p.get("nombre", "")
				}
		# cerramos el fichero arriba, no hay más acción necesaria aquí
		file.close()
	else:
		push_error("No se encontró provincias.json en res://")

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

		var img: Image = color_map.texture.get_image()
		var c: Color = img.get_pixel(x, y)

		var r: int = int(c.r * 255)
		var g: int = int(c.g * 255)
		var b: int = int(c.b * 255)

		var clave: Color = Color.from_rgba8(r, g, b, 255)

		# Buscar provincia usando tolerancia
		var encontrada := false
		for key_color in provincias.keys():
			if colores_iguales(key_color, clave):
				var info = provincias[key_color]
				var gid = info.get("gid", "(sin gid)")
				var nombre = info.get("nombre", "(sin nombre)")
				print("(R:%d, G:%d, B:%d) -- Provincia: %s (%s)" % [r, g, b, nombre, gid])
				encontrada = true
				break

		if not encontrada:
			print("(R:%d, G:%d, B:%d) -- Provincia no identificada" % [r, g, b])
