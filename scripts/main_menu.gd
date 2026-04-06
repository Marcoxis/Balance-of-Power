extends Control

const LOADING_SCENE_PATH: String = "res://scenes/LoadingScreen.tscn"

@onready var title_label: Label = $MainLayout/Header/Title
@onready var subtitle_label: Label = $MainLayout/Header/Subtitle
@onready var main_menu: PanelContainer = $MainLayout/CenterWrap/MainMenuPanel
@onready var singleplayer_menu: PanelContainer = $MainLayout/CenterWrap/SingleplayerPanel
@onready var options_menu: PanelContainer = $MainLayout/CenterWrap/OptionsPanel
@onready var popup: AcceptDialog = $Popup
@onready var language_button: MenuButton = $LanguageButton
@onready var debugger_button: Button = $DebuggerButton

@onready var button_singleplayer: Button = $MainLayout/CenterWrap/MainMenuPanel/MainMenuButtons/Singleplayer
@onready var button_multiplayer: Button = $MainLayout/CenterWrap/MainMenuPanel/MainMenuButtons/Multiplayer
@onready var button_options: Button = $MainLayout/CenterWrap/MainMenuPanel/MainMenuButtons/Options
@onready var button_quit: Button = $MainLayout/CenterWrap/MainMenuPanel/MainMenuButtons/Quit
@onready var button_new_game: Button = $MainLayout/CenterWrap/SingleplayerPanel/SingleplayerButtons/NewGame
@onready var button_load_game: Button = $MainLayout/CenterWrap/SingleplayerPanel/SingleplayerButtons/LoadGame
@onready var button_back: Button = $MainLayout/CenterWrap/SingleplayerPanel/SingleplayerButtons/Back
@onready var button_graphics: Button = $MainLayout/CenterWrap/OptionsPanel/OptionsButtons/Graphics
@onready var button_sound: Button = $MainLayout/CenterWrap/OptionsPanel/OptionsButtons/Sound
@onready var button_controls: Button = $MainLayout/CenterWrap/OptionsPanel/OptionsButtons/Controls
@onready var button_accessibility: Button = $MainLayout/CenterWrap/OptionsPanel/OptionsButtons/Accessibility
@onready var button_options_back: Button = $MainLayout/CenterWrap/OptionsPanel/OptionsButtons/OptionsBack

func _ready() -> void:
	var popup_menu: PopupMenu = language_button.get_popup()
	popup_menu.clear()
	popup_menu.add_item("English", 0)
	popup_menu.add_item("Español", 1)
	popup_menu.id_pressed.connect(_on_language_selected)
	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)
	_apply_language()
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

func _apply_language() -> void:
	title_label.text = Localization.t("menu.main_title")
	subtitle_label.text = Localization.t("menu.main_subtitle")
	button_singleplayer.text = Localization.t("menu.singleplayer")
	button_multiplayer.text = Localization.t("menu.multiplayer")
	button_options.text = Localization.t("menu.options")
	button_quit.text = Localization.t("menu.quit")
	button_new_game.text = Localization.t("menu.new_game")
	button_load_game.text = Localization.t("menu.load_game")
	button_back.text = Localization.t("menu.back")
	button_graphics.text = Localization.t("menu.graphics")
	button_sound.text = Localization.t("menu.sound")
	button_controls.text = Localization.t("menu.controls")
	button_accessibility.text = Localization.t("menu.accessibility")
	button_options_back.text = Localization.t("menu.back")
	debugger_button.tooltip_text = Localization.t("menu.debugger")
	language_button.tooltip_text = Localization.t("menu.translate")
	popup.ok_button_text = Localization.t("ui.ok")

func _show_coming_soon(title: String) -> void:
	popup.title = title
	popup.dialog_text = Localization.t("ui.coming_soon")
	popup.popup_centered()

func _on_singleplayer_pressed() -> void:
	_show_singleplayer_menu()

func _on_multiplayer_pressed() -> void:
	_show_coming_soon(Localization.t("menu.multiplayer"))

func _on_options_pressed() -> void:
	_show_options_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)

func _on_load_game_pressed() -> void:
	_show_coming_soon(Localization.t("menu.load_game"))

func _on_back_pressed() -> void:
	_show_main_menu()

func _on_graphics_pressed() -> void:
	_show_coming_soon(Localization.t("menu.graphics"))

func _on_sound_pressed() -> void:
	_show_coming_soon(Localization.t("menu.sound"))

func _on_controls_pressed() -> void:
	_show_coming_soon(Localization.t("menu.controls"))

func _on_accessibility_pressed() -> void:
	_show_coming_soon(Localization.t("menu.accessibility"))

func _on_debugger_pressed() -> void:
	_show_coming_soon(Localization.t("menu.debugger"))

func _on_language_selected(id: int) -> void:
	match id:
		0:
			Localization.set_language("en")
		1:
			Localization.set_language("es")

func _on_language_changed(_language_code: String) -> void:
	_apply_language()
