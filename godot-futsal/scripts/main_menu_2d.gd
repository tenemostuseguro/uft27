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
	var loaded_image: Image = Image.load_from_file(image_url)
	if loaded_image != null:
		notification_image_rect.texture = ImageTexture.create_from_image(loaded_image)
		return
	if image_url.begins_with("http://") or image_url.begins_with("https://"):
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(_on_notification_image_downloaded.bind(http))
		var req_err: int = http.request(image_url)
		if req_err != OK:
			http.queue_free()

func _on_notification_image_downloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var image := Image.new()
	var err: int = image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		return
	notification_image_rect.texture = ImageTexture.create_from_image(image)

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
