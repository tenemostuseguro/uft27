extends Control

const MATCH_SCENE := "res://scenes/Main3D.tscn"
const TEMPLATE_SCENE := "res://scenes/TemplateMenu2D.tscn"

@onready var status_label: Label = $Margin/Layout/StatusLabel

func _ready() -> void:
	$Margin/Layout/Buttons/PlayButton.pressed.connect(_on_play_pressed)
	$Margin/Layout/Buttons/TemplateButton.pressed.connect(_on_template_pressed)
	$Margin/Layout/Buttons/QuitButton.pressed.connect(_on_quit_pressed)
	_refresh_status()

func _on_play_pressed() -> void:
	if not MatchConfig.template_ready:
		status_label.text = "Antes de jugar, creá tu plantilla."
		return
	get_tree().change_scene_to_file(MATCH_SCENE)

func _on_template_pressed() -> void:
	get_tree().change_scene_to_file(TEMPLATE_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _refresh_status() -> void:
	if MatchConfig.template_ready:
		status_label.text = "Plantilla lista: %s (%s)" % [MatchConfig.team_name, MatchConfig.formation]
	else:
		status_label.text = "No hay plantilla creada todavía."
