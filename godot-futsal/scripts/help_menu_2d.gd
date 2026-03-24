extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"

func _ready() -> void:
	$Margin/VBox/BackButton.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
