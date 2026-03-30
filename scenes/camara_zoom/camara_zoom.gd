extends Camera2D

@export var velocidad := 600.0

func _process(delta):
	var direccion := Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		direccion.x += 1
	if Input.is_action_pressed("ui_left"):
		direccion.x -= 1
	if Input.is_action_pressed("ui_down"):
		direccion.y += 1
	if Input.is_action_pressed("ui_up"):
		direccion.y -= 1

	position += direccion.normalized() * velocidad * delta
