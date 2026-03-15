extends Control

const MATCH_MODE_SCENE := "res://scenes/MatchModeMenu2D.tscn"
const TEMPLATE_SCENE := "res://scenes/TemplateMenu2D.tscn"
const PROFILE_SCENE := "res://scenes/ProfileMenu2D.tscn"
const HELP_SCENE := "res://scenes/HelpMenu2D.tscn"
const SETTINGS_SCENE := "res://scenes/SettingsMenu2D.tscn"

@onready var status_label: Label = $Margin/Layout/StatusLabel

func _ready() -> void:
	$Margin/Layout/Buttons/PlayButton.pressed.connect(_on_play_pressed)
	$Margin/Layout/Buttons/QuickMatchButton.pressed.connect(_on_quick_match_pressed)
	$Margin/Layout/Buttons/TemplateButton.pressed.connect(_on_template_pressed)
	$Margin/Layout/Buttons/ProfileButton.pressed.connect(_on_profile_pressed)
	$Margin/Layout/Buttons/HelpButton.pressed.connect(_on_help_pressed)
	$Margin/Layout/Buttons/SettingsButton.pressed.connect(_on_settings_pressed)
	$Margin/Layout/Buttons/QuitButton.pressed.connect(_on_quit_pressed)
	_refresh_status()

func _on_play_pressed() -> void:
	if not MatchConfig.template_ready:
		status_label.text = "Antes de jugar, creá tu plantilla."
		return
	get_tree().change_scene_to_file(MATCH_MODE_SCENE)

func _on_template_pressed() -> void:
	get_tree().change_scene_to_file(TEMPLATE_SCENE)

func _on_profile_pressed() -> void:
	get_tree().change_scene_to_file(PROFILE_SCENE)

func _on_quick_match_pressed() -> void:
	MatchConfig.template_ready = false
	status_label.text = "Entrando en partido rápido..."
	get_tree().change_scene_to_file(MATCH_MODE_SCENE)

func _on_help_pressed() -> void:
	get_tree().change_scene_to_file(HELP_SCENE)

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _refresh_status() -> void:
	if MatchConfig.template_ready:
		status_label.text = "Plantilla lista: %s (%s)" % [MatchConfig.team_name, MatchConfig.formation]
	else:
		status_label.text = "No hay plantilla creada todavía."
