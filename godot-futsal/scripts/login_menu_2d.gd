extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"

@onready var username_input: LineEdit = $Center/Card/VBox/UsernameInput
@onready var password_input: LineEdit = $Center/Card/VBox/PasswordInput
@onready var status_label: Label = $Center/Card/VBox/StatusLabel

func _ready() -> void:
	$Center/Card/VBox/Buttons/LoginButton.pressed.connect(_on_login_pressed)
	$Center/Card/VBox/Buttons/SignUpButton.pressed.connect(_on_signup_pressed)
	$Center/Card/VBox/OfflineButton.pressed.connect(_on_offline_pressed)

	var auth = _get_auth_service()
	if auth != null:
		status_label.text = "Servidor listo. Usá usuario y contraseña."
	else:
		status_label.text = "AuthService no está disponible. Revisá autoloads."

func _on_login_pressed() -> void:
	var auth = _get_auth_service()
	if auth == null:
		status_label.text = "AuthService no disponible"
		return
	status_label.text = "Iniciando sesión..."
	var result: Dictionary = await auth.login(username_input.text, password_input.text)
	if result.get("ok", false):
		status_label.text = "Sesión iniciada ✅"
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		status_label.text = "Error login: %s" % str(result.get("error", "desconocido"))

func _on_signup_pressed() -> void:
	var auth = _get_auth_service()
	if auth == null:
		status_label.text = "AuthService no disponible"
		return
	status_label.text = "Creando cuenta..."
	var result: Dictionary = await auth.sign_up(username_input.text, password_input.text)
	if result.get("ok", false):
		status_label.text = "Cuenta creada. Ahora iniciá sesión."
	else:
		status_label.text = "Error registro: %s" % str(result.get("error", "desconocido"))

func _on_offline_pressed() -> void:
	var auth = _get_auth_service()
	if auth != null:
		auth.logout()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _get_auth_service():
	return get_node_or_null("/root/AuthService")
