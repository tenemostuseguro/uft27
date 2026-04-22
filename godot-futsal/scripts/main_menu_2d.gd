extends Control

const MATCH_MODE_SCENE := "res://scenes/MatchModeMenu2D.tscn"
const TEMPLATE_SCENE := "res://scenes/TemplateMenu2D.tscn"
const PROFILE_SCENE := "res://scenes/ProfileMenu2D.tscn"
const HELP_SCENE := "res://scenes/HelpMenu2D.tscn"
const SETTINGS_SCENE := "res://scenes/SettingsMenu2D.tscn"
const CHANGELOG_SCENE := "res://scenes/ChangelogMenu2D.tscn"
const UFT_SCENE := "res://scenes/UFTMenu2D.tscn"
const DEFAULT_LOGO_PATH := "res://assets/default_profile_logo.png"

@onready var status_label: Label = $MainRow/CenterArea/StatusLabel
@onready var game_label: Label = $TopBar/TopRow/GameLabel
@onready var build_label: Label = $TopBar/TopRow/BuildLabel
@onready var profile_logo_rect: TextureRect = $MainRow/LeftVisual/LeftVBox/ProfileLogo

func _ready() -> void:
	$MainRow/CenterArea/Grid/KickoffCard/KickoffVBox/PlayButton.pressed.connect(_on_play_pressed)
	$MainRow/CenterArea/Grid/KickoffCard/KickoffVBox/QuickMatchButton.pressed.connect(_on_quick_match_pressed)
	$MainRow/CenterArea/Grid/TemplateButton.pressed.connect(_on_template_pressed)
	$MainRow/LeftVisual/LeftVBox/ProfileButton.pressed.connect(_on_profile_pressed)
	$MainRow/CenterArea/Grid/RightTiles/UFTTile/UFTVBox/UFTButton.pressed.connect(_on_uft_pressed)
	$MainRow/CenterArea/Grid/RightTiles/BottomNews/NewsVBox/ChangeLogButton.pressed.connect(_on_changelog_pressed)
	$MainRow/CenterArea/Grid/RightTiles/BottomNews/NewsVBox/TemplateSmall.pressed.connect(_on_template_pressed)
	$TopBar/TopRow/HelpButton.pressed.connect(_on_help_pressed)
	$TopBar/TopRow/SettingsButton.pressed.connect(_on_settings_pressed)
	$TopBar/TopRow/QuitButton.pressed.connect(_on_quit_pressed)
	game_label.text = MatchConfig.GAME_NAME
	build_label.text = MatchConfig.get_build_label()
	_refresh_status()
	_load_profile_logo()

func _on_play_pressed() -> void:
	if not MatchConfig.template_ready:
		status_label.text = "Antes de jugar, crea tu plantilla."
		return
	get_tree().change_scene_to_file(MATCH_MODE_SCENE)

func _on_template_pressed() -> void:
	get_tree().change_scene_to_file(TEMPLATE_SCENE)

func _on_profile_pressed() -> void:
	get_tree().change_scene_to_file(PROFILE_SCENE)

func _on_changelog_pressed() -> void:
	get_tree().change_scene_to_file(CHANGELOG_SCENE)

func _on_uft_pressed() -> void:
	get_tree().change_scene_to_file(UFT_SCENE)

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

func _load_profile_logo() -> void:
	var auth = _get_auth_service()
	if auth == null or not auth.is_authenticated():
		_apply_profile_logo_texture(_load_local_texture(DEFAULT_LOGO_PATH))
		return
	var profile_result: Dictionary = await auth.get_profile_logo()
	if not profile_result.get("ok", false):
		_apply_profile_logo_texture(_load_local_texture(DEFAULT_LOGO_PATH))
		return
	var profile: Dictionary = profile_result.get("profile", {})
	var image_url: String = str(profile.get("resolved_image_url", ""))
	if image_url.is_empty():
		image_url = DEFAULT_LOGO_PATH
	_load_logo_texture(image_url)

func _load_logo_texture(path_or_url: String) -> void:
	profile_logo_rect.texture = null
	if path_or_url.strip_edges().is_empty():
		_apply_profile_logo_texture(_load_local_texture(DEFAULT_LOGO_PATH))
		return
	if _is_remote_path(path_or_url):
		_request_remote_texture(path_or_url)
		return
	_apply_profile_logo_texture(_load_local_texture(path_or_url))

func _request_remote_texture(url: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		_apply_profile_logo_texture(_load_local_texture(DEFAULT_LOGO_PATH))
		return
	var completed: Array = await http.request_completed
	http.queue_free()
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		_apply_profile_logo_texture(_load_local_texture(DEFAULT_LOGO_PATH))
		return
	var image := Image.new()
	var body: PackedByteArray = completed[3]
	var err := image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		err = image.load_webp_from_buffer(body)
	if err != OK:
		_apply_profile_logo_texture(_load_local_texture(DEFAULT_LOGO_PATH))
		return
	_apply_profile_logo_texture(ImageTexture.create_from_image(image))

func _apply_profile_logo_texture(texture: Texture2D) -> void:
	if texture != null:
		profile_logo_rect.texture = texture
	else:
		profile_logo_rect.texture = _load_local_texture(DEFAULT_LOGO_PATH)

func _load_local_texture(path: String) -> Texture2D:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource is Texture2D:
		return resource
	var image := Image.load_from_file(path)
	if image != null:
		return ImageTexture.create_from_image(image)
	return null

func _is_remote_path(path_or_url: String) -> bool:
	return path_or_url.begins_with("http://") or path_or_url.begins_with("https://")
