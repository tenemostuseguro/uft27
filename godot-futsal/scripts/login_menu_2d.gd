extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"

@onready var supabase_url_input: LineEdit = $Center/Card/VBox/SupabaseUrlInput
@onready var anon_key_input: LineEdit = $Center/Card/VBox/AnonKeyInput
@onready var username_input: LineEdit = $Center/Card/VBox/UsernameInput
@onready var password_input: LineEdit = $Center/Card/VBox/PasswordInput
@onready var status_label: Label = $Center/Card/VBox/StatusLabel

func _ready() -> void:
	$Center/Card/VBox/Buttons/LoginButton.pressed.connect(_on_login_pressed)
	$Center/Card/VBox/Buttons/SignUpButton.pressed.connect(_on_signup_pressed)
	$Center/Card/VBox/OfflineButton.pressed.connect(_on_offline_pressed)
	if supabase_url_input.text.strip_edges().is_empty():
		supabase_url_input.text = AuthService.supabase_url
	if anon_key_input.text.strip_edges().is_empty():
		anon_key_input.text = AuthService.supabase_anon_key
	status_label.text = "Supabase listo. Podés registrarte o iniciar sesión."

func _on_login_pressed() -> void:
	_configure_auth_service_from_inputs()
	status_label.text = "Iniciando sesión..."
	var result: Dictionary = await AuthService.login(username_input.text, password_input.text)
	if result.get("ok", false):
		status_label.text = "Sesión iniciada ✅"
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		status_label.text = "Error login: %s" % str(result.get("error", "desconocido"))

func _on_signup_pressed() -> void:
	_configure_auth_service_from_inputs()
	status_label.text = "Creando cuenta..."
	var result: Dictionary = await AuthService.sign_up(username_input.text, password_input.text)
	if result.get("ok", false):
		status_label.text = "Cuenta creada. Ahora iniciá sesión."
	else:
		status_label.text = "Error registro: %s" % str(result.get("error", "desconocido"))

func _on_offline_pressed() -> void:
	AuthService.logout()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
