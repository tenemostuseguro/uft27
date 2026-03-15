extends Node

const EMAIL_DOMAIN := "@uft27.local"
const USERNAME_PATTERN := "^[a-zA-Z0-9_.-]{3,32}$"
const DEFAULT_SUPABASE_URL := "https://tykwhhbhbllwycfggwnq.supabase.co"
const DEFAULT_SUPABASE_ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5a3doaGJoYmxsd3ljZmdnd25xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2MTEwOTYsImV4cCI6MjA4OTE4NzA5Nn0.5GNKzDpUv0r4k6rJaOwy1-nMroD-7bPH5iJus7rznEw"

var access_token := ""
var refresh_token := ""
var user_id := ""
var username := ""

func get_supabase_url() -> String:
	return DEFAULT_SUPABASE_URL

func is_configured() -> bool:
	return not DEFAULT_SUPABASE_URL.is_empty() and not DEFAULT_SUPABASE_ANON_KEY.is_empty()

func is_authenticated() -> bool:
	return not access_token.is_empty() and not user_id.is_empty()

func logout() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	username = ""

func sign_up(user_name: String, password: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configuración interna de auth incompleta"}

	var validation := _validate_username(user_name)
	if not validation.get("ok", false):
		return validation
	if password.length() < 6:
		return {"ok": false, "error": "La contraseña debe tener al menos 6 caracteres"}

	var normalized_username: String = validation.get("username", "")
	var endpoint := "%s/auth/v1/signup" % DEFAULT_SUPABASE_URL
	var payload := {
		"email": _username_to_email(normalized_username),
		"password": password,
		"data": {"username": normalized_username}
	}
	var result := await _request_json(endpoint, HTTPClient.METHOD_POST, payload)
	if not result.get("ok", false):
		return result

	return {"ok": true}

func login(user_name: String, password: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configuración interna de auth incompleta"}
	if password.is_empty():
		return {"ok": false, "error": "Usuario y contraseña son obligatorios"}

	var validation := _validate_username(user_name)
	if not validation.get("ok", false):
		return validation

	var normalized_username: String = validation.get("username", "")
	var endpoint := "%s/auth/v1/token?grant_type=password" % DEFAULT_SUPABASE_URL
	var payload := {
		"email": _username_to_email(normalized_username),
		"password": password
	}
	var result := await _request_json(endpoint, HTTPClient.METHOD_POST, payload)
	if not result.get("ok", false):
		return result

	var json: Dictionary = result.get("json", {})
	access_token = str(json.get("access_token", ""))
	refresh_token = str(json.get("refresh_token", ""))
	var user: Dictionary = json.get("user", {})
	user_id = str(user.get("id", ""))
	username = normalized_username
	if not is_authenticated():
		return {"ok": false, "error": "Respuesta inválida de Supabase"}

	return {"ok": true, "username": username}

func _validate_username(user_name: String) -> Dictionary:
	var normalized_username := user_name.strip_edges().to_lower()
	if normalized_username.length() < 3:
		return {"ok": false, "error": "El usuario debe tener al menos 3 caracteres"}

	var username_regex := RegEx.new()
	var compile_err := username_regex.compile(USERNAME_PATTERN)
	if compile_err != OK:
		return {"ok": false, "error": "Error interno validando usuario"}
	if username_regex.search(normalized_username) == null:
		return {
			"ok": false,
			"error": "Usuario inválido. Usá 3-32 caracteres: letras, números, _, - o ."
		}

	return {"ok": true, "username": normalized_username}

func _username_to_email(user_name: String) -> String:
	return "%s%s" % [user_name, EMAIL_DOMAIN]

func _request_json(url: String, method: int, payload: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(payload)
	var headers := PackedStringArray([
		"apikey: %s" % DEFAULT_SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	])
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "No se pudo iniciar request HTTP (%s)" % err}

	var completed: Array = await http.request_completed
	http.queue_free()
	var response_code: int = completed[1]
	var raw: PackedByteArray = completed[3]
	var text := raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	var parsed_dict: Dictionary = parsed if parsed is Dictionary else {}

	if response_code < 200 or response_code >= 300:
		var msg := str(parsed_dict.get("msg", parsed_dict.get("error_description", parsed_dict.get("error", text))))
		return {"ok": false, "error": msg}

	return {"ok": true, "json": parsed_dict}
