extends Control

const MATCH_MODE_SCENE := "res://scenes/MatchModeMenu2D.tscn"
const TEMPLATE_SCENE := "res://scenes/TemplateMenu2D.tscn"
const PROFILE_SCENE := "res://scenes/ProfileMenu2D.tscn"
const HELP_SCENE := "res://scenes/HelpMenu2D.tscn"
const SETTINGS_SCENE := "res://scenes/SettingsMenu2D.tscn"
const CHANGELOG_SCENE := "res://scenes/ChangelogMenu2D.tscn"

@onready var status_label: Label = $MainRow/RightPanel/RightVBox/StatusLabel
@onready var game_label: Label = $TopBar/TopRow/GameLabel
@onready var build_label: Label = $TopBar/TopRow/BuildLabel

func _ready() -> void:
	$MainRow/CenterArea/KickoffCard/KickoffVBox/PlayButton.pressed.connect(_on_play_pressed)
	$MainRow/LeftNav/QuickMatchButton.pressed.connect(_on_quick_match_pressed)
	$MainRow/LeftNav/TemplateButton.pressed.connect(_on_template_pressed)
	$MainRow/LeftNav/ProfileButton.pressed.connect(_on_profile_pressed)
	$MainRow/LeftNav/ChangeLogButton.pressed.connect(_on_changelog_pressed)
	$TopBar/TopRow/HelpButton.pressed.connect(_on_help_pressed)
	$TopBar/TopRow/SettingsButton.pressed.connect(_on_settings_pressed)
	$TopBar/TopRow/QuitButton.pressed.connect(_on_quit_pressed)
	game_label.text = MatchConfig.GAME_NAME
	build_label.text = MatchConfig.get_build_label()
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

func _on_changelog_pressed() -> void:
	get_tree().change_scene_to_file(CHANGELOG_SCENE)

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
	var account := "offline"
	var auth = _get_auth_service()
	if auth != null and auth.is_authenticated():
		account = str(auth.username)
	if MatchConfig.template_ready:
		status_label.text = "Cuenta: %s | Plantilla lista: %s (%s)" % [account, MatchConfig.team_name, MatchConfig.formation]
	else:
		status_label.text = "Cuenta: %s | No hay plantilla creada todavía." % [account]

func _get_auth_service():
	return get_node_or_null("/root/AuthService")
