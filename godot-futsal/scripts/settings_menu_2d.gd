extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"

@onready var fullscreen_check: CheckBox = $Margin/VBox/FullscreenCheck
@onready var volume_slider: HSlider = $Margin/VBox/MasterVolumeSlider

func _ready() -> void:
	$Margin/VBox/BackButton.pressed.connect(_on_back_pressed)
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), value)
