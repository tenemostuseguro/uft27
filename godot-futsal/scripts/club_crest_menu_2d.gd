extends Control

const PROFILE_MENU_SCENE := "res://scenes/ProfileMenu2D.tscn"
const DEFAULT_LOGO_PATH := "res://assets/default_profile_logo.png"
const LEAGUE_LOGO_SIZE := Vector2i(576, 192)
const CLUB_LOGO_SIZE := Vector2i.ZERO
const COUNTRY_LOGO_SIZE := Vector2i(120, 72)

@onready var country_name_label: Label = $Margin/VBox/TopBar/TopRow/CountryName
@onready var country_logo_rect: TextureRect = $Margin/VBox/TopBar/TopRow/CountryLogo
@onready var club_name_label: Label = $Margin/VBox/Card/CardVBox/ClubName
@onready var club_logo_rect: TextureRect = $Margin/VBox/Card/CardVBox/CenterRow/ClubLogo
@onready var league_name_label: Label = $Margin/VBox/BottomBar/BottomVBox/LeagueRow/LeagueName
@onready var league_logo_rect: TextureRect = $Margin/VBox/BottomBar/BottomVBox/LeagueLogo
@onready var status_label: Label = $Margin/VBox/Status

var render_token := 0
var texture_cache: Dictionary = {}

var countries: Array[Dictionary] = []
var selected_country_idx := 0
var selected_league_idx := 0
var selected_club_idx := 0

func _ready() -> void:
	$Margin/VBox/TopBar/TopRow/CountryLeftArrow.pressed.connect(func() -> void: _move_country(-1))
	$Margin/VBox/TopBar/TopRow/CountryRightArrow.pressed.connect(func() -> void: _move_country(1))
	$Margin/VBox/BottomBar/BottomVBox/LeagueRow/LeagueLeftArrow.pressed.connect(func() -> void: _move_league(-1))
	$Margin/VBox/BottomBar/BottomVBox/LeagueRow/LeagueRightArrow.pressed.connect(func() -> void: _move_league(1))
	$Margin/VBox/Card/CardVBox/CenterRow/LeftArrow.pressed.connect(func() -> void: _move_club(-1))
	$Margin/VBox/Card/CardVBox/CenterRow/RightArrow.pressed.connect(func() -> void: _move_club(1))
	$Margin/VBox/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$Margin/VBox/Buttons/BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file(PROFILE_MENU_SCENE))
	_load_hierarchy()

func _get_auth_service() -> Node:
	return get_node_or_null("/root/AuthService")

func _load_hierarchy() -> void:
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
		_build_hierarchy(rows)
	if countries.is_empty():
		status_label.text = "No hay clubes activos"
		return

	var profile_result: Dictionary = await auth.get_profile_logo()
	if profile_result.get("ok", false):
		var selected_logo := str(profile_result.get("profile", {}).get("logo_id", ""))
		_preselect_by_club_id(selected_logo)
	_update_view()

func _build_hierarchy(rows: Array) -> void:
	var map := {}
	for row in rows:
		if row is not Dictionary:
			continue
		if not bool(row.get("active", true)):
			continue
		var country_name := str(row.get("country_name", "Sin país"))
		var league_name := str(row.get("league_name", "Sin liga"))
		if not map.has(country_name):
			map[country_name] = {
				"name": country_name,
				"logo_url": _pick_first_url(row, ["country_logo_url", "country_logo", "country_flag_url"]),
				"leagues": {}
			}
		var country: Dictionary = map[country_name]
		var leagues: Dictionary = country.get("leagues", {})
		if not leagues.has(league_name):
			leagues[league_name] = {
				"name": league_name,
				"logo_url": _pick_first_url(row, ["league_logo_url", "league_logo", "league_image_url"]),
				"clubs": []
			}
		var league: Dictionary = leagues[league_name]
		var clubs: Array = league.get("clubs", [])
		clubs.append({
			"id": str(row.get("id", "")),
			"name": str(row.get("name", "Club")),
			"logo_url": _pick_first_url(row, ["logo_url", "club_logo_url", "image_url"])
		})
		league["clubs"] = clubs
		leagues[league_name] = league
		country["leagues"] = leagues
		map[country_name] = country

	countries.clear()
	var country_names := map.keys()
	country_names.sort()
	for country_name in country_names:
		var country: Dictionary = map[country_name]
		var league_names := (country.get("leagues", {}) as Dictionary).keys()
		league_names.sort()
		var leagues_array: Array[Dictionary] = []
		for league_name in league_names:
			var league: Dictionary = (country.get("leagues", {}) as Dictionary)[league_name]
			leagues_array.append(league)
		country["leagues_array"] = leagues_array
		countries.append(country)

func _preselect_by_club_id(club_id: String) -> void:
	if club_id.strip_edges().is_empty():
		return
	for cidx in range(countries.size()):
		var country: Dictionary = countries[cidx]
		var leagues: Array[Dictionary] = country.get("leagues_array", [])
		for lidx in range(leagues.size()):
			var clubs: Array = leagues[lidx].get("clubs", [])
			for k in range(clubs.size()):
				if str((clubs[k] as Dictionary).get("id", "")) == club_id:
					selected_country_idx = cidx
					selected_league_idx = lidx
					selected_club_idx = k
					return

func _move_country(delta: int) -> void:
	if countries.is_empty():
		return
	selected_country_idx = (selected_country_idx + delta + countries.size()) % countries.size()
	selected_league_idx = 0
	selected_club_idx = 0
	_update_view()

func _move_league(delta: int) -> void:
	var leagues := _current_leagues()
	if leagues.is_empty():
		return
	selected_league_idx = (selected_league_idx + delta + leagues.size()) % leagues.size()
	selected_club_idx = 0
	_update_view()

func _move_club(delta: int) -> void:
	var clubs := _current_clubs()
	if clubs.is_empty():
		return
	selected_club_idx = (selected_club_idx + delta + clubs.size()) % clubs.size()
	_update_view()

func _current_country() -> Dictionary:
	if countries.is_empty():
		return {}
	selected_country_idx = clamp(selected_country_idx, 0, countries.size() - 1)
	return countries[selected_country_idx]

func _current_leagues() -> Array[Dictionary]:
	var country := _current_country()
	return country.get("leagues_array", [])

func _current_league() -> Dictionary:
	var leagues := _current_leagues()
	if leagues.is_empty():
		return {}
	selected_league_idx = clamp(selected_league_idx, 0, leagues.size() - 1)
	return leagues[selected_league_idx]

func _current_clubs() -> Array:
	var league := _current_league()
	return league.get("clubs", [])

func _current_club() -> Dictionary:
	var clubs := _current_clubs()
	if clubs.is_empty():
		return {}
	selected_club_idx = clamp(selected_club_idx, 0, clubs.size() - 1)
	return clubs[selected_club_idx]

func _update_view() -> void:
	var country := _current_country()
	var league := _current_league()
	var club := _current_club()
	if country.is_empty() or league.is_empty() or club.is_empty():
		status_label.text = "No hay datos para mostrar"
		return

	render_token += 1
	var token := render_token
	country_name_label.text = str(country.get("name", ""))
	league_name_label.text = str(league.get("name", ""))
	club_name_label.text = str(club.get("name", ""))
	club_logo_rect.texture = null

	await _set_remote_or_default(country_logo_rect, str(country.get("logo_url", "")), COUNTRY_LOGO_SIZE, token)
	await _set_remote_or_default(league_logo_rect, str(league.get("logo_url", "")), LEAGUE_LOGO_SIZE, token)
	await _set_remote_or_default(club_logo_rect, str(club.get("logo_url", "")), CLUB_LOGO_SIZE, token)
	status_label.text = "País %d/%d · Liga %d/%d · Club %d/%d" % [selected_country_idx + 1, countries.size(), selected_league_idx + 1, _current_leagues().size(), selected_club_idx + 1, _current_clubs().size()]

func _set_remote_or_default(target: TextureRect, url: String, forced_size: Vector2i, token: int) -> void:
	if token != render_token:
		return
	if url.strip_edges().is_empty():
		target.texture = _load_local(DEFAULT_LOGO_PATH)
		return
	if not (url.begins_with("http://") or url.begins_with("https://")):
		target.texture = _load_local(url)
		return
	if texture_cache.has(url):
		target.texture = texture_cache[url]
		return
	var texture := await _fetch_remote_texture(url, forced_size)
	if token != render_token:
		return
	if texture != null:
		target.texture = texture
		texture_cache[url] = texture
	else:
		target.texture = _load_local(DEFAULT_LOGO_PATH)

func _pick_first_url(row: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		var value := str(row.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""

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
	var club := _current_club()
	if club.is_empty():
		status_label.text = "No hay club seleccionado"
		return
	var auth := _get_auth_service()
	if auth == null or not auth.is_authenticated():
		status_label.text = "Sesión inválida"
		return
	var club_id := str(club.get("id", ""))
	var result: Dictionary = await auth.set_profile_logo(club_id, "")
	if result.get("ok", false):
		status_label.text = "Escudo guardado ✅"
	else:
		status_label.text = "Error guardando escudo"
