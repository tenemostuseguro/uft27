extends Node

const EMAIL_DOMAIN := "@uft27.local"

var supabase_url := ""
var supabase_anon_key := ""

var access_token := ""
var refresh_token := ""
var user_id := ""
var username := ""

func configure(url: String, anon_key: String) -> void:
	supabase_url = url.strip_edges().trim_suffix("/")
	supabase_anon_key = anon_key.strip_edges()

func is_configured() -> bool:
	return not supabase_url.is_empty() and not supabase_anon_key.is_empty()

func is_authenticated() -> bool:
	return not access_token.is_empty() and not user_id.is_empty()

func logout() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	username = ""

func sign_up(user_name: String, password: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configura SUPABASE_URL y SUPABASE_ANON_KEY"}
	if user_name.strip_edges().length() < 3:
		return {"ok": false, "error": "El usuario debe tener al menos 3 caracteres"}
	if password.length() < 6:
		return {"ok": false, "error": "La contraseña debe tener al menos 6 caracteres"}

	var endpoint := "%s/auth/v1/signup" % supabase_url
	var payload := {
		"email": _username_to_email(user_name),
		"password": password,
		"data": {"username": user_name.strip_edges()}
	}
	var result := await _request_json(endpoint, HTTPClient.METHOD_POST, payload)
	if not result.get("ok", false):
		return result

	return {"ok": true}

func login(user_name: String, password: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configura SUPABASE_URL y SUPABASE_ANON_KEY"}
	if user_name.strip_edges().is_empty() or password.is_empty():
		return {"ok": false, "error": "Usuario y contraseña son obligatorios"}

	var endpoint := "%s/auth/v1/token?grant_type=password" % supabase_url
	var payload := {
		"email": _username_to_email(user_name),
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
	username = user_name.strip_edges()
	if not is_authenticated():
		return {"ok": false, "error": "Respuesta inválida de Supabase"}

	return {"ok": true, "username": username}

func _username_to_email(user_name: String) -> String:
	return "%s%s" % [user_name.strip_edges().to_lower(), EMAIL_DOMAIN]

func _request_json(url: String, method: int, payload: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(payload)
	var headers := PackedStringArray([
		"apikey: %s" % supabase_anon_key,
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
