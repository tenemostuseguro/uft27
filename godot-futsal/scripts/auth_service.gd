extends Node

const USERNAME_PATTERN := "^[a-zA-Z0-9_.-]{3,32}$"
const DEFAULT_SUPABASE_URL := "https://tykwhhbhbllwycfggwnq.supabase.co"
const DEFAULT_SUPABASE_ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5a3doaGJoYmxsd3ljZmdnd25xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2MTEwOTYsImV4cCI6MjA4OTE4NzA5Nn0.5GNKzDpUv0r4k6rJaOwy1-nMroD-7bPH5iJus7rznEw"

var access_token := ""
var refresh_token := ""
var user_id := ""
var username := ""

func is_configured() -> bool:
	return not DEFAULT_SUPABASE_URL.is_empty() and not DEFAULT_SUPABASE_ANON_KEY.is_empty()

func is_authenticated() -> bool:
	return not user_id.is_empty() and not username.is_empty()

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
	var endpoint := "%s/rest/v1/rpc/register_player" % DEFAULT_SUPABASE_URL
	var payload := {
		"p_username": normalized_username,
		"p_password_hash": _hash_password(password)
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
	var endpoint := "%s/rest/v1/rpc/authenticate_player" % DEFAULT_SUPABASE_URL
	var payload := {
		"p_username": normalized_username,
		"p_password_hash": _hash_password(password)
	}
	var result := await _request_json(endpoint, HTTPClient.METHOD_POST, payload)
	if not result.get("ok", false):
		return result

	var response_json: Variant = result.get("json", [])
	if response_json is not Array or response_json.size() == 0:
		return {"ok": false, "error": "Usuario o contraseña incorrectos"}

	var row: Dictionary = response_json[0]
	user_id = str(row.get("id", ""))
	username = str(row.get("username", ""))
	access_token = "local_session"
	refresh_token = ""

	if not is_authenticated():
		return {"ok": false, "error": "Respuesta inválida del servidor"}

	return {"ok": true, "username": username}

func get_unread_notifications(limit: int = 10) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configuración interna de auth incompleta"}
	if not is_authenticated():
		return {"ok": true, "notifications": []}

	var endpoint := "%s/rest/v1/rpc/list_player_notifications" % DEFAULT_SUPABASE_URL
	var payload := {
		"p_player_id": user_id,
		"p_limit": limit
	}
	var result := await _request_json(endpoint, HTTPClient.METHOD_POST, payload)
	if not result.get("ok", false):
		return result

	var notifications: Variant = result.get("json", [])
	if notifications is not Array:
		return {"ok": true, "notifications": []}
	return {"ok": true, "notifications": notifications}

func mark_notification_read(notification_id: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configuración interna de auth incompleta"}
	if not is_authenticated():
		return {"ok": false, "error": "No hay sesión activa"}
	if notification_id.strip_edges().is_empty():
		return {"ok": false, "error": "Notificación inválida"}

	var endpoint := "%s/rest/v1/rpc/mark_player_notification_read" % DEFAULT_SUPABASE_URL
	var payload := {
		"p_player_id": user_id,
		"p_notification_id": notification_id.strip_edges()
	}
	return await _request_json(endpoint, HTTPClient.METHOD_POST, payload)


func list_profile_logos() -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configuración interna de auth incompleta"}
	var endpoint := "%s/rest/v1/rpc/list_profile_logos" % DEFAULT_SUPABASE_URL
	var result := await _request_json(endpoint, HTTPClient.METHOD_POST, {})
	if not result.get("ok", false):
		return result
	var logos: Variant = result.get("json", [])
	if logos is not Array:
		return {"ok": true, "logos": []}
	return {"ok": true, "logos": logos}

func get_profile_logo() -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configuración interna de auth incompleta"}
	if not is_authenticated():
		return {"ok": false, "error": "No hay sesión activa"}
	var endpoint := "%s/rest/v1/rpc/get_player_profile_logo" % DEFAULT_SUPABASE_URL
	var payload := {"p_player_id": user_id}
	var result := await _request_json(endpoint, HTTPClient.METHOD_POST, payload)
	if not result.get("ok", false):
		return result
	var rows: Variant = result.get("json", [])
	if rows is not Array or rows.size() == 0:
		return {"ok": true, "profile": {}}
	return {"ok": true, "profile": rows[0]}

func set_profile_logo(logo_id: String, custom_image_url: String = "") -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "Configuración interna de auth incompleta"}
	if not is_authenticated():
		return {"ok": false, "error": "No hay sesión activa"}
	if logo_id.strip_edges().is_empty() and custom_image_url.strip_edges().is_empty():
		return {"ok": false, "error": "Logo inválido"}
	var endpoint := "%s/rest/v1/rpc/set_player_profile_logo" % DEFAULT_SUPABASE_URL
	var payload := {
		"p_player_id": user_id,
		"p_logo_id": null if logo_id.strip_edges().is_empty() else logo_id.strip_edges(),
		"p_custom_image_url": custom_image_url.strip_edges()
	}
	return await _request_json(endpoint, HTTPClient.METHOD_POST, payload)

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

func _hash_password(password: String) -> String:
	var context := HashingContext.new()
	var err := context.start(HashingContext.HASH_SHA256)
	if err != OK:
		return ""
	context.update(password.to_utf8_buffer())
	var digest: PackedByteArray = context.finish()
	return digest.hex_encode()

func _request_json(url: String, method: int, payload: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(payload)
	var headers := PackedStringArray([
		"apikey: %s" % DEFAULT_SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % DEFAULT_SUPABASE_ANON_KEY,
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

	if response_code < 200 or response_code >= 300:
		var parsed_dict: Dictionary = parsed if parsed is Dictionary else {}
		var msg := str(parsed_dict.get("message", parsed_dict.get("msg", parsed_dict.get("error", text))))
		return {"ok": false, "error": msg}

	return {"ok": true, "json": parsed}
