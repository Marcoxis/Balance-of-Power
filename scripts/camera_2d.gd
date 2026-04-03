extends Camera2D

@export var velocidad_teclado: float = 1200.0
@export var velocidad_arrastre: float = 1.0
@export var paso_zoom: float = 0.1
@export var zoom_min: float = 0.25
@export var zoom_max: float = 4.0
@export var zoom_referencia_arrastre: float = 1.0
@export var sensibilidad_zoom_arrastre: float = 0.35

var arrastrando: bool = false
var ultima_pos_raton: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	var direccion: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_D):
		direccion.x += 1.0
	if Input.is_key_pressed(KEY_A):
		direccion.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		direccion.y += 1.0
	if Input.is_key_pressed(KEY_W):
		direccion.y -= 1.0

	if direccion != Vector2.ZERO:
		position += direccion.normalized() * velocidad_teclado * delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			arrastrando = event.pressed
			ultima_pos_raton = event.position

		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom -= Vector2(paso_zoom, paso_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom += Vector2(paso_zoom, paso_zoom)

			zoom.x = clampf(zoom.x, zoom_min, zoom_max)
			zoom.y = clampf(zoom.y, zoom_min, zoom_max)

	elif event is InputEventMouseMotion and arrastrando:
		var delta_mov: Vector2 = event.position - ultima_pos_raton
		var zoom_normalizado: float = zoom.x / zoom_referencia_arrastre
		var factor_arrastre: float = lerpf(1.0, zoom_normalizado, sensibilidad_zoom_arrastre)
		position -= delta_mov * velocidad_arrastre * factor_arrastre
		ultima_pos_raton = event.position
