extends Control

const PROFILE_MENU_SCENE := "res://scenes/ProfileMenu2D.tscn"
const DEFAULT_LOGO_PATH := "res://assets/default_profile_logo.png"
const LEAGUE_LOGO_SIZE := Vector2i(576, 192)
const CLUB_LOGO_SIZE := Vector2i.ZERO
const COUNTRY_LOGO_SIZE := Vector2i(120, 72)

@onready var country_name_label: Label = $Margin/VBox/TopBar/TopRow/CountryName
@onready var country_logo_rect: TextureRect = $Margin/VBox/TopBar/TopRow/CountryLogo
@onready var club_name_label: Label = $Margin/VBox/Card/ClubName
@onready var club_logo_rect: TextureRect = $Margin/VBox/Card/ClubLogo
@onready var league_name_label: Label = $Margin/VBox/BottomBar/BottomVBox/LeagueName
@onready var league_logo_rect: TextureRect = $Margin/VBox/BottomBar/BottomVBox/LeagueLogo
@onready var status_label: Label = $Margin/VBox/Status

var clubs: Array[Dictionary] = []
var selected_index := 0

func _ready() -> void:
	$Margin/VBox/Card/CardVBox/CenterRow/LeftArrow.pressed.connect(func() -> void: _move_selection(-1))
	$Margin/VBox/Card/CardVBox/CenterRow/RightArrow.pressed.connect(func() -> void: _move_selection(1))
	$Margin/VBox/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$Margin/VBox/Buttons/BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file(PROFILE_MENU_SCENE))
	_load_clubs()

func _get_auth_service() -> Node:
	return get_node_or_null("/root/AuthService")

func _load_clubs() -> void:
	var auth := _get_auth_service()
	if auth == null or not auth.is_authenticated():
		status_label.text = "Inicia sesión para elegir escudo"
		return
	var clubs_result: Dictionary = await auth.list_uft_clubs()
	if not clubs_result.get("ok", false):
		status_label.text = "Error cargando clubes"
		return
	var rows: Variant = clubs_result.get("json", [])
	if rows is Array:
		for row in rows:
			if row is Dictionary and bool(row.get("active", true)):
				clubs.append(row)
	if clubs.is_empty():
		status_label.text = "No hay clubes activos"
		return
	var profile_result: Dictionary = await auth.get_profile_logo()
	if profile_result.get("ok", false):
		var current_logo := str(profile_result.get("profile", {}).get("logo_id", ""))
		for i in range(clubs.size()):
			if str(clubs[i].get("id", "")) == current_logo:
				selected_index = i
				break
	_update_view()

func _move_selection(delta: int) -> void:
	if clubs.is_empty():
		return
	selected_index = (selected_index + delta + clubs.size()) % clubs.size()
	_update_view()

func _update_view() -> void:
	if clubs.is_empty():
		return
	var club: Dictionary = clubs[selected_index]
	country_name_label.text = str(club.get("country_name", ""))
	club_name_label.text = str(club.get("name", ""))
	league_name_label.text = str(club.get("league_name", ""))
	await _set_remote_or_default(country_logo_rect, str(club.get("country_logo_url", "")), COUNTRY_LOGO_SIZE)
	await _set_remote_or_default(club_logo_rect, str(club.get("logo_url", "")), CLUB_LOGO_SIZE)
	await _set_remote_or_default(league_logo_rect, str(club.get("league_logo_url", "")), LEAGUE_LOGO_SIZE)
	status_label.text = "Usa las flechas para elegir club"

func _set_remote_or_default(target: TextureRect, url: String, forced_size: Vector2i) -> void:
	if url.strip_edges().is_empty():
		target.texture = _load_local(DEFAULT_LOGO_PATH)
		return
	if not (url.begins_with("http://") or url.begins_with("https://")):
		target.texture = _load_local(url)
		return
	var texture := await _fetch_remote_texture(url, forced_size)
	if texture != null:
		target.texture = texture
	else:
		target.texture = _load_local(DEFAULT_LOGO_PATH)

func _fetch_remote_texture(url: String, forced_size: Vector2i) -> Texture2D:
	var http := HTTPRequest.new()
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		return null
	var data: Array = await http.request_completed
	http.queue_free()
	if int(data[0]) != HTTPRequest.RESULT_SUCCESS:
		return null
	if int(data[1]) < 200 or int(data[1]) >= 300:
		return null
	var body: PackedByteArray = data[3]
	var image := Image.new()
	var err := image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		err = image.load_webp_from_buffer(body)
	if err != OK:
		return null
	if forced_size.x > 0 and forced_size.y > 0:
		image.resize(forced_size.x, forced_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _load_local(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	return null

func _on_save_pressed() -> void:
	if clubs.is_empty():
		status_label.text = "No hay clubes disponibles"
		return
	var auth := _get_auth_service()
	if auth == null or not auth.is_authenticated():
		status_label.text = "Sesión inválida"
		return
	var club_id := str(clubs[selected_index].get("id", ""))
	var result: Dictionary = await auth.set_profile_logo(club_id, "")
	if result.get("ok", false):
		status_label.text = "Escudo guardado ✅"
	else:
		status_label.text = "Error guardando escudo"
