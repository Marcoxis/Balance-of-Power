extends Control

const LOADING_SCENE_PATH := "res://scenes/LoadingScreen.tscn"

@onready var main_menu: PanelContainer = $MainLayout/CenterWrap/MainMenuPanel
@onready var singleplayer_menu: PanelContainer = $MainLayout/CenterWrap/SingleplayerPanel
@onready var options_menu: PanelContainer = $MainLayout/CenterWrap/OptionsPanel
@onready var popup: AcceptDialog = $Popup

func _ready() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	main_menu.visible = true
	singleplayer_menu.visible = false
	options_menu.visible = false

func _show_singleplayer_menu() -> void:
	main_menu.visible = false
	singleplayer_menu.visible = true
	options_menu.visible = false

func _show_options_menu() -> void:
	main_menu.visible = false
	singleplayer_menu.visible = false
	options_menu.visible = true

func _show_coming_soon(title: String) -> void:
	popup.title = title
	popup.dialog_text = "Proximamente"
	popup.popup_centered()

func _on_singleplayer_pressed() -> void:
	_show_singleplayer_menu()

func _on_multiplayer_pressed() -> void:
	_show_coming_soon("Multiplayer")

func _on_options_pressed() -> void:
	_show_options_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)

func _on_load_game_pressed() -> void:
	_show_coming_soon("Cargar partida")

func _on_back_pressed() -> void:
	_show_main_menu()

func _on_graphics_pressed() -> void:
	_show_coming_soon("Graficos")

func _on_sound_pressed() -> void:
	_show_coming_soon("Sonido")

func _on_controls_pressed() -> void:
	_show_coming_soon("Controles")

func _on_accessibility_pressed() -> void:
	_show_coming_soon("Accesibilidad")
