extends Control

const GAME_SCENE := "res://scenes/Main3D.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"

@onready var ip_input: LineEdit = $Margin/VBox/IPInput

func _ready() -> void:
	$Margin/VBox/HostButton.pressed.connect(_on_host_pressed)
	$Margin/VBox/JoinButton.pressed.connect(_on_join_pressed)
	$Margin/VBox/VsAIButton.pressed.connect(_on_vs_ai_pressed)
	$Margin/VBox/BackButton.pressed.connect(_on_back_pressed)

func _on_host_pressed() -> void:
	MatchConfig.set_match_start(MatchConfig.MODE_HOST, ip_input.text)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_join_pressed() -> void:
	MatchConfig.set_match_start(MatchConfig.MODE_JOIN, ip_input.text)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_vs_ai_pressed() -> void:
	MatchConfig.set_match_start(MatchConfig.MODE_VS_AI, ip_input.text)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
