extends Camera2D

@export var velocidad_teclado := 1200.0       # Velocidad con WASD
@export var velocidad_arrastre := 1.0         # Velocidad al arrastrar con ratón
@export var paso_zoom := 0.1                  # Incremento de zoom con la rueda
@export var zoom_min := 0.25                   # Zoom mínimo
@export var zoom_max := 4                  # Zoom máximo

var arrastrando := false
var ultima_pos_raton := Vector2.ZERO

func _process(delta):
	var direccion := Vector2.ZERO

	# Mover con WASD
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
	# Arrastrar cámara con botón izquierdo
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			arrastrando = event.pressed
			ultima_pos_raton = event.position

		# Zoom con rueda del ratón
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom -= Vector2(paso_zoom, paso_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom += Vector2(paso_zoom, paso_zoom)

			# Limitar el zoom
			zoom.x = clamp(zoom.x, zoom_min, zoom_max)
			zoom.y = clamp(zoom.y, zoom_min, zoom_max)

	# Mover cámara arrastrando
	elif event is InputEventMouseMotion and arrastrando:
		var delta_mov: Vector2 = event.position - ultima_pos_raton
		position -= delta_mov * velocidad_arrastre * zoom.x
		ultima_pos_raton = event.position
