extends Control

const MATCH_SCENE := "res://scenes/Main3D.tscn"

@onready var status_label: Label = $Margin/Layout/StatusLabel
@onready var team_name_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/TeamNameInput
@onready var primary_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/PrimaryColorInput
@onready var secondary_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/SecondaryColorInput
@onready var formation_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/FormationInput

func _ready() -> void:
	$Margin/Layout/Buttons/CreateTemplateButton.pressed.connect(_on_create_template_pressed)
	$Margin/Layout/Buttons/PlayButton.pressed.connect(_on_play_pressed)
	$Margin/Layout/Buttons/QuitButton.pressed.connect(_on_quit_pressed)
	_refresh_status()

func _on_create_template_pressed() -> void:
	MatchConfig.set_template(
		team_name_input.text,
		primary_input.text,
		secondary_input.text,
		formation_input.text
	)
	status_label.text = "Plantilla guardada: %s (%s)" % [MatchConfig.team_name, MatchConfig.formation]

func _on_play_pressed() -> void:
	if not MatchConfig.template_ready:
		status_label.text = "Primero creá una plantilla antes de jugar."
		return
	get_tree().change_scene_to_file(MATCH_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _refresh_status() -> void:
	if MatchConfig.template_ready:
		status_label.text = "Plantilla actual: %s" % MatchConfig.team_name
	else:
		status_label.text = "Creá tu plantilla y luego jugá."
