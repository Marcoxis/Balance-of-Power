extends RefCounted

class_name GameTimeController

const SPEED_TO_DAYS_PER_SECOND := {
	1: 0.35,
	2: 0.75,
	3: 1.5,
	4: 3.0,
	5: 6.0
}

const MONTH_NAMES := [
	"",
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December"
]

var current_game_date: Dictionary = {"day": 1, "month": 1, "year": 1836}
var current_time_speed: int = 3
var time_paused: bool = true
var time_accumulator: float = 0.0
var day_change_speed_multiplier: float = 1.0

# Advances the internal game date according to the selected speed.
# Hace avanzar la fecha interna del juego según la velocidad seleccionada.
func process_time(delta: float, tree_paused: bool) -> bool:
	if time_paused or tree_paused:
		return false

	var days_per_second: float = float(SPEED_TO_DAYS_PER_SECOND.get(current_time_speed, 1.0)) * day_change_speed_multiplier
	time_accumulator += delta * days_per_second

	var changed: bool = false
	while time_accumulator >= 1.0:
		time_accumulator -= 1.0
		_advance_one_day()
		changed = true

	return changed

# Returns the formatted date text shown in the top bar.
# Devuelve el texto de fecha formateado que se muestra en la barra superior.
func get_date_text() -> String:
	var day: int = int(current_game_date["day"])
	var month: int = int(current_game_date["month"])
	var year: int = int(current_game_date["year"])
	return "%02d %s %d" % [day, MONTH_NAMES[month], year]

# Updates the visible date label with the current internal date.
# Actualiza la etiqueta visible de fecha con la fecha interna actual.
func update_date_label(date_label: Label) -> void:
	if date_label != null:
		date_label.text = get_date_text()

# Updates the pause button and speed button state.
# Actualiza el estado del botón de pausa y de los botones de velocidad.
func update_controls(pause_button: Button, speed_buttons: Array[Button], gameplay_paused: bool) -> void:
	if pause_button != null:
		pause_button.text = ">" if time_paused and not gameplay_paused else "||"

	for i in range(speed_buttons.size()):
		speed_buttons[i].disabled = (i + 1) == current_time_speed

# Toggles whether the in-game time is paused.
# Alterna si el tiempo del juego está pausado.
func toggle_pause() -> void:
	time_paused = not time_paused

# Sets the current time speed tier.
# Establece el nivel actual de velocidad del tiempo.
func set_speed(speed: int) -> void:
	current_time_speed = clampi(speed, 1, 5)

# Sets the global multiplier for day changes.
# Establece el multiplicador global para el cambio de día.
func set_multiplier(value: float) -> void:
	day_change_speed_multiplier = maxf(0.01, value)

# Returns the current global multiplier for day changes.
# Devuelve el multiplicador global actual del cambio de día.
func get_multiplier() -> float:
	return day_change_speed_multiplier

# Advances the calendar by one day and wraps month and year values.
# Avanza el calendario un día y ajusta mes y año cuando corresponde.
func _advance_one_day() -> void:
	current_game_date["day"] = int(current_game_date["day"]) + 1

	var month: int = int(current_game_date["month"])
	var max_days: int = _get_days_in_month(month, int(current_game_date["year"]))
	if int(current_game_date["day"]) > max_days:
		current_game_date["day"] = 1
		current_game_date["month"] = month + 1

	if int(current_game_date["month"]) > 12:
		current_game_date["month"] = 1
		current_game_date["year"] = int(current_game_date["year"]) + 1

# Returns how many days a given month has.
# Devuelve cuántos días tiene un mes dado.
func _get_days_in_month(month: int, year: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			if _is_leap_year(year):
				return 29
			return 28
		_:
			return 30

# Checks whether one year is leap.
# Comprueba si un año es bisiesto.
func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
