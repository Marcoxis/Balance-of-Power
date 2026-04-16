extends Node

signal settings_changed

var show_country_colors: bool = true
var show_sea: bool = true

# Toggles the political overlay visibility and notifies listeners.
# Activa o desactiva la visibilidad del overlay pol?tico y notifica a los listeners.
func set_show_country_colors(value: bool) -> void:
	if show_country_colors == value:
		return
	show_country_colors = value
	emit_signal("settings_changed")

# Toggles sea rendering and notifies listeners.
# Activa o desactiva el renderizado del mar y notifica a los listeners.
func set_show_sea(value: bool) -> void:
	if show_sea == value:
		return
	show_sea = value
	emit_signal("settings_changed")
