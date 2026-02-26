extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"

@onready var status_label: Label = $Margin/Layout/StatusLabel
@onready var team_name_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/TeamNameInput
@onready var primary_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/PrimaryColorInput
@onready var secondary_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/SecondaryColorInput
@onready var formation_input: LineEdit = $Margin/Layout/TemplatePanel/TemplateForm/FormationInput

func _ready() -> void:
	$Margin/Layout/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$Margin/Layout/Buttons/BackButton.pressed.connect(_on_back_pressed)
	_load_current_values()

func _on_save_pressed() -> void:
	MatchConfig.set_template(
		team_name_input.text,
		primary_input.text,
		secondary_input.text,
		formation_input.text
	)
	status_label.text = "Guardado: %s (%s)" % [MatchConfig.team_name, MatchConfig.formation]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _load_current_values() -> void:
	team_name_input.text = MatchConfig.team_name
	primary_input.text = MatchConfig.primary_color.to_html()
	secondary_input.text = MatchConfig.secondary_color.to_html()
	formation_input.text = MatchConfig.formation
	if MatchConfig.template_ready:
		status_label.text = "Editando plantilla existente"
	else:
		status_label.text = "Creá una plantilla y guardá"
