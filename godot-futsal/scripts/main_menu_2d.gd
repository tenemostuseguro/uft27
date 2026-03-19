extends Control

const MATCH_MODE_SCENE := "res://scenes/MatchModeMenu2D.tscn"
const TEMPLATE_SCENE := "res://scenes/TemplateMenu2D.tscn"
const PROFILE_SCENE := "res://scenes/ProfileMenu2D.tscn"
const HELP_SCENE := "res://scenes/HelpMenu2D.tscn"
const SETTINGS_SCENE := "res://scenes/SettingsMenu2D.tscn"
const CHANGELOG_SCENE := "res://scenes/ChangelogMenu2D.tscn"
const DEFAULT_LOGO_PATH := "res://assets/default_profile_logo.png"

@onready var status_label: Label = $MainRow/RightPanel/RightVBox/StatusLabel
@onready var game_label: Label = $TopBar/TopRow/GameLabel
@onready var build_label: Label = $TopBar/TopRow/BuildLabel
@onready var profile_logo_rect: TextureRect = $MainRow/RightPanel/RightVBox/ProfileLogo
@onready var notification_panel: PanelContainer = $NotificationPanel
@onready var notification_header_label: Label = $NotificationPanel/Margin/VBox/Header
@onready var notification_title_label: Label = $NotificationPanel/Margin/VBox/Body/Left/Title
@onready var notification_body_label: RichTextLabel = $NotificationPanel/Margin/VBox/Body/Left/BodyText
@onready var notification_image_rect: TextureRect = $NotificationPanel/Margin/VBox/Body/Right/Image
@onready var notification_counter_label: Label = $NotificationPanel/Margin/VBox/Footer/Counter
@onready var notification_close_button: Button = $NotificationPanel/Margin/VBox/Footer/CloseButton

var notification_queue: Array[Dictionary] = []
var active_notification: Dictionary = {}

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
	notification_panel.visible = false
	notification_close_button.pressed.connect(_on_notification_close_pressed)
	_refresh_status()
	_load_profile_logo()
	_load_notifications()

func _unhandled_input(event: InputEvent) -> void:
	if notification_panel.visible and event.is_action_pressed("ui_accept"):
		_on_notification_close_pressed()

func _on_play_pressed() -> void:
	if notification_panel.visible:
		return
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
	if notification_panel.visible:
		return
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
		_request_remote_texture(path_or_url, _on_profile_logo_texture_ready)
		return
	_apply_profile_logo_texture(_load_local_texture(path_or_url))

func _on_profile_logo_texture_ready(texture: Texture2D) -> void:
	_apply_profile_logo_texture(texture)

func _apply_profile_logo_texture(texture: Texture2D) -> void:
	if texture != null:
		profile_logo_rect.texture = texture
		return
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

func _request_remote_texture(url: String, callback: Callable) -> void:
	var normalized_url := _normalize_remote_image_url(url)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_remote_texture_downloaded.bind(http, normalized_url, callback))
	if http.request(normalized_url) != OK:
		http.queue_free()
		callback.call(null)

func _on_remote_texture_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, url: String, callback: Callable) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		callback.call(null)
		return
	var texture := _texture_from_http_body(url, headers, body)
	callback.call(texture)

func _texture_from_http_body(url: String, headers: PackedStringArray, body: PackedByteArray) -> Texture2D:
	var mime_type := _extract_content_type(headers).to_lower()
	if mime_type.contains("gif") or url.to_lower().ends_with(".gif"):
		return null
	var image := Image.new()
	var err := image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		err = image.load_webp_from_buffer(body)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

func _extract_content_type(headers: PackedStringArray) -> String:
	for header in headers:
		var normalized := str(header).to_lower()
		if normalized.begins_with("content-type:"):
			return str(header).split(":", true, 1)[1].strip_edges()
	return ""

func _normalize_remote_image_url(url: String) -> String:
	var normalized := url.strip_edges()
	if normalized.to_lower().ends_with(".gif") and normalized.contains("i.imgur.com/"):
		return normalized.substr(0, normalized.length() - 4) + ".png"
	return normalized

func _is_remote_path(path_or_url: String) -> bool:
	return path_or_url.begins_with("http://") or path_or_url.begins_with("https://")

func _load_notifications() -> void:
	var auth: Node = _get_auth_service()
	if auth == null or not auth.is_authenticated():
		return
	var result: Dictionary = await auth.get_unread_notifications(12)
	if not result.get("ok", false):
		status_label.text = "No se pudieron cargar notificaciones"
		return
	var rows: Variant = result.get("notifications", [])
	if rows is not Array:
		return
	notification_queue.clear()
	for row in rows:
		if row is Dictionary:
			notification_queue.append(row)
	if notification_queue.size() > 0:
		_show_next_notification()

func _show_next_notification() -> void:
	if notification_queue.is_empty():
		notification_panel.visible = false
		active_notification = {}
		return
	var next_notification: Dictionary = notification_queue.pop_front()
	active_notification = next_notification
	notification_panel.visible = true
	notification_header_label.text = str(active_notification.get("header", "MENSAJE DEL EQUIPO UFT"))
	notification_title_label.text = str(active_notification.get("title", "Actualización"))
	notification_body_label.text = str(active_notification.get("body", ""))
	notification_counter_label.text = "Pendientes: %d" % (notification_queue.size() + 1)
	_load_notification_image(str(active_notification.get("image_url", "")))

func _load_notification_image(image_url: String) -> void:
	notification_image_rect.texture = null
	if image_url.strip_edges().is_empty():
		return
	if _is_remote_path(image_url):
		_request_remote_texture(image_url, _on_notification_texture_ready)
		return
	notification_image_rect.texture = _load_local_texture(image_url)

func _on_notification_texture_ready(texture: Texture2D) -> void:
	notification_image_rect.texture = texture

func _on_notification_close_pressed() -> void:
	if active_notification.is_empty():
		notification_panel.visible = false
		return
	var auth: Node = _get_auth_service()
	if auth != null and auth.is_authenticated():
		await auth.mark_notification_read(str(active_notification.get("id", "")))
	active_notification = {}
	if notification_queue.size() > 0:
		_show_next_notification()
	else:
		notification_panel.visible = false
