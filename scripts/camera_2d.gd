extends Camera2D

@export var velocidad_teclado := 1200.0
@export var velocidad_arrastre := 1.0
@export var paso_zoom := 0.1
@export var zoom_min := 0.25
@export var zoom_max := 4.0
@export var zoom_referencia_arrastre := 1.0
@export var sensibilidad_zoom_arrastre := 0.35

var arrastrando := false
var ultima_pos_raton := Vector2.ZERO

func _process(delta):
	var direccion := Vector2.ZERO

	if Input.is_key_pressed(KEY_D):
		direccion.x += 1
	if Input.is_key_pressed(KEY_A):
		direccion.x -= 1
	if Input.is_key_pressed(KEY_S):
		direccion.y += 1
	if Input.is_key_pressed(KEY_W):
		direccion.y -= 1

	if direccion != Vector2.ZERO:
		position += direccion.normalized() * velocidad_teclado * delta

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			arrastrando = event.pressed
			ultima_pos_raton = event.position

		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom -= Vector2(paso_zoom, paso_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom += Vector2(paso_zoom, paso_zoom)

			zoom.x = clamp(zoom.x, zoom_min, zoom_max)
			zoom.y = clamp(zoom.y, zoom_min, zoom_max)

	elif event is InputEventMouseMotion and arrastrando:
		var delta_mov: Vector2 = event.position - ultima_pos_raton
		var zoom_normalizado := zoom.x / zoom_referencia_arrastre
		var factor_arrastre := lerpf(1.0, zoom_normalizado, sensibilidad_zoom_arrastre)
		position -= delta_mov * velocidad_arrastre * factor_arrastre
		ultima_pos_raton = event.position
