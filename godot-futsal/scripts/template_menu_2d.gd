extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const ROLE_KEYS: Array[String] = ["GK", "Cierre", "Ala Izq", "Ala Der", "Pivot"]

@onready var status_label: Label = $Margin/Layout/Footer/StatusLabel
@onready var team_name_input: LineEdit = $Margin/Layout/Header/ConfigPanel/ConfigForm/TeamNameInput
@onready var primary_input: LineEdit = $Margin/Layout/Header/ConfigPanel/ConfigForm/PrimaryColorInput
@onready var secondary_input: LineEdit = $Margin/Layout/Header/ConfigPanel/ConfigForm/SecondaryColorInput
@onready var formation_input: LineEdit = $Margin/Layout/Header/ConfigPanel/ConfigForm/FormationInput
@onready var rating_label: Label = $Margin/Layout/Header/Meta/RatingLabel
@onready var chemistry_label: Label = $Margin/Layout/Header/Meta/ChemistryLabel
@onready var completion_label: Label = $Margin/Layout/Header/Meta/CompletionLabel
@onready var profile_photo_preview: TextureRect = $Margin/Layout/Header/Meta/ProfilePhotoPreview
@onready var profile_photo_button: Button = $Margin/Layout/Header/Meta/ProfilePhotoButton
@onready var country_filter: OptionButton = $Margin/Layout/Header/Meta/CountryFilter
@onready var league_filter: OptionButton = $Margin/Layout/Header/Meta/LeagueFilter
@onready var crest_select: OptionButton = $Margin/Layout/Header/Meta/CrestSelect
@onready var crest_preview_label: Label = $Margin/Layout/Header/Meta/CrestPreview
@onready var profile_photo_dialog: FileDialog = $ProfilePhotoDialog

@onready var gk_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/GKCard/VBox/PlayerSelect
@onready var cierre_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/CierreCard/VBox/PlayerSelect
@onready var ala_izq_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/AlaIzqCard/VBox/PlayerSelect
@onready var ala_der_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/AlaDerCard/VBox/PlayerSelect
@onready var pivot_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/PivotCard/VBox/PlayerSelect

@onready var gk_card: PanelContainer = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/GKCard
@onready var cierre_card: PanelContainer = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/CierreCard
@onready var ala_izq_card: PanelContainer = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/AlaIzqCard
@onready var ala_der_card: PanelContainer = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/AlaDerCard
@onready var pivot_card: PanelContainer = $Margin/Layout/SquadArea/PitchPanel/PitchCanvas/PivotCard

@onready var selected_name_label: Label = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/NameLabel
@onready var selected_role_label: Label = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/RoleLabel
@onready var selected_stats_label: Label = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/StatsLabel
@onready var bench_list: ItemList = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/BenchList

var role_options: Dictionary = {}
var role_cards: Dictionary = {}
var selected_crest_id := ""

func _ready() -> void:
	role_options = {
		"GK": gk_option,
		"Cierre": cierre_option,
		"Ala Izq": ala_izq_option,
		"Ala Der": ala_der_option,
		"Pivot": pivot_option
	}
	role_cards = {
		"GK": gk_card,
		"Cierre": cierre_card,
		"Ala Izq": ala_izq_card,
		"Ala Der": ala_der_card,
		"Pivot": pivot_card
	}

	$Margin/Layout/Footer/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$Margin/Layout/Footer/Buttons/BackButton.pressed.connect(_on_back_pressed)
	profile_photo_button.pressed.connect(func() -> void: profile_photo_dialog.popup_centered_ratio(0.75))
	profile_photo_dialog.file_selected.connect(_on_profile_photo_selected)
	country_filter.item_selected.connect(_on_country_filter_changed)
	league_filter.item_selected.connect(_on_league_filter_changed)
	crest_select.item_selected.connect(_on_crest_selected)

	for role in ROLE_KEYS:
		var option: OptionButton = role_options[role]
		option.item_selected.connect(_on_role_selection_changed.bind(role))
		_populate_role_option(role, option)

	_populate_country_filter()
	_load_current_values()
	_refresh_team_meta()
	_refresh_bench_preview()
	_show_player_from_role("Pivot")
	_refresh_position_cards()

func _populate_role_option(role: String, option: OptionButton) -> void:
	option.clear()
	option.add_item("Seleccionar...")
	option.set_item_metadata(0, "")

	var players: Array[Dictionary] = MatchConfig.get_players_for_role(role)
	for player in players:
		var name: String = str(player.get("name", ""))
		var ovr: int = int(player.get("ovr", 0))
		var item_text := "%s (%d)" % [name, ovr]
		option.add_item(item_text)
		var idx := option.item_count - 1
		option.set_item_metadata(idx, name)

func _load_current_values() -> void:
	team_name_input.text = MatchConfig.team_name
	primary_input.text = MatchConfig.primary_color.to_html()
	secondary_input.text = MatchConfig.secondary_color.to_html()
	formation_input.text = MatchConfig.formation

	for role in ROLE_KEYS:
		var saved_name: String = str(MatchConfig.selected_lineup.get(role, ""))
		_select_player_by_name(role_options[role], saved_name)

	selected_crest_id = MatchConfig.selected_crest_id
	_select_filter_for_saved_crest()
	_refresh_crest_preview()
	_load_profile_photo_preview(MatchConfig.profile_photo_path)

	if MatchConfig.template_ready:
		status_label.text = "Editá y guardá tu plantilla"
	else:
		status_label.text = "Elegí un jugador por posición"

func _select_player_by_name(option: OptionButton, player_name: String) -> void:
	if player_name.is_empty():
		option.select(0)
		return
	for i in range(option.item_count):
		var meta: String = str(option.get_item_metadata(i))
		if meta == player_name:
			option.select(i)
			return
	option.select(0)

func _on_role_selection_changed(_index: int, role: String) -> void:
	_show_player_from_role(role)
	_refresh_team_meta()
	_refresh_bench_preview()
	_refresh_position_cards()

func _show_player_from_role(role: String) -> void:
	var option: OptionButton = role_options[role]
	var selected_index: int = option.get_selected()
	if selected_index < 0:
		selected_index = 0
	var player_name: String = str(option.get_item_metadata(selected_index))
	if player_name.is_empty():
		selected_name_label.text = "Jugador: -"
		selected_role_label.text = "Posición: %s" % role
		selected_stats_label.text = "PAC - | SHO - | PAS -\nDRI - | DEF - | PHY -"
		return

	var player: Dictionary = MatchConfig.find_player_by_name(player_name)
	selected_name_label.text = "Jugador: %s (OVR %d)" % [player_name, int(player.get("ovr", 0))]
	selected_role_label.text = "Posición: %s" % role
	selected_stats_label.text = "PAC %d | SHO %d | PAS %d\nDRI %d | DEF %d | PHY %d" % [
		int(player.get("pac", 0)),
		int(player.get("sho", 0)),
		int(player.get("pas", 0)),
		int(player.get("dri", 0)),
		int(player.get("def", 0)),
		int(player.get("phy", 0))
	]

func _build_lineup_from_ui() -> Dictionary:
	var lineup: Dictionary = {}
	for role in ROLE_KEYS:
		var option: OptionButton = role_options[role]
		var selected_index: int = option.get_selected()
		if selected_index < 0:
			selected_index = 0
		lineup[role] = str(option.get_item_metadata(selected_index))
	return lineup

func _refresh_team_meta() -> void:
	var lineup: Dictionary = _build_lineup_from_ui()
	var complete_count := 0
	for role in ROLE_KEYS:
		if not str(lineup.get(role, "")).is_empty():
			complete_count += 1

	var complete := complete_count == ROLE_KEYS.size() and not selected_crest_id.is_empty()
	var preview_rating := _compute_rating_preview(lineup)
	rating_label.text = "Rating: %d" % preview_rating
	chemistry_label.text = "Chemistry: %d" % (100 if complete else 40 + complete_count * 12)
	completion_label.text = "Posiciones completas: %d/%d | Escudo: %s" % [complete_count, ROLE_KEYS.size(), "OK" if not selected_crest_id.is_empty() else "Falta"]

func _compute_rating_preview(lineup: Dictionary) -> int:
	var total := 0
	var count := 0
	for role in ROLE_KEYS:
		var name: String = str(lineup.get(role, ""))
		if name.is_empty():
			continue
		var player: Dictionary = MatchConfig.find_player_by_name(name)
		if player.is_empty():
			continue
		total += int(player.get("ovr", 0))
		count += 1
	if count == 0:
		return 0
	return int(round(float(total) / float(count)))

func _refresh_bench_preview() -> void:
	bench_list.clear()
	var selected_names: Dictionary = {}
	var lineup: Dictionary = _build_lineup_from_ui()
	for role in ROLE_KEYS:
		var name: String = str(lineup.get(role, ""))
		if not name.is_empty():
			selected_names[name] = true

	var count := 0
	for player in MatchConfig.player_pool:
		var name: String = str(player.get("name", ""))
		if selected_names.has(name):
			continue
		bench_list.add_item("%s  OVR %d" % [name, int(player.get("ovr", 0))])
		count += 1
		if count >= 14:
			break

func _refresh_position_cards() -> void:
	for role in ROLE_KEYS:
		var option: OptionButton = role_options[role]
		var selected_index: int = option.get_selected()
		if selected_index < 0:
			selected_index = 0
		var has_player := not str(option.get_item_metadata(selected_index)).is_empty()
		var card: PanelContainer = role_cards[role]
		card.modulate = Color(0.95, 1.0, 0.95, 1.0) if has_player else Color(1.0, 0.8, 0.8, 1.0)

func _on_save_pressed() -> void:
	var lineup: Dictionary = _build_lineup_from_ui()
	MatchConfig.set_template(
		team_name_input.text,
		primary_input.text,
		secondary_input.text,
		formation_input.text,
		lineup,
		selected_crest_id,
		MatchConfig.profile_photo_path
	)

	if MatchConfig.template_ready:
		status_label.text = "Plantilla guardada ✅"
	elif selected_crest_id.is_empty():
		status_label.text = "Debes seleccionar un escudo"
	else:
		status_label.text = "Falta seleccionar jugador en alguna posición"
	_refresh_team_meta()
	_refresh_position_cards()


func _populate_country_filter() -> void:
	country_filter.clear()
	for country in MatchConfig.get_available_countries():
		country_filter.add_item(country)
	if country_filter.item_count > 0:
		country_filter.select(0)
		_populate_league_filter(str(country_filter.get_item_text(0)))

func _populate_league_filter(country: String) -> void:
	league_filter.clear()
	for league in MatchConfig.get_leagues_for_country(country):
		league_filter.add_item(league)
	if league_filter.item_count > 0:
		league_filter.select(0)
		_populate_crest_select(country, str(league_filter.get_item_text(0)))
	else:
		crest_select.clear()

func _populate_crest_select(country: String, league: String) -> void:
	crest_select.clear()
	crest_select.add_item("Seleccionar escudo...")
	crest_select.set_item_metadata(0, "")
	for crest in MatchConfig.get_crests(country, league):
		var item := "%s %s" % [str(crest.get("crest", "⚽")), str(crest.get("team", ""))]
		crest_select.add_item(item)
		var idx := crest_select.item_count - 1
		crest_select.set_item_metadata(idx, str(crest.get("id", "")))
	_select_saved_crest_in_current_list()

func _select_saved_crest_in_current_list() -> void:
	if selected_crest_id.is_empty():
		crest_select.select(0)
		return
	for i in range(crest_select.item_count):
		if str(crest_select.get_item_metadata(i)) == selected_crest_id:
			crest_select.select(i)
			return
	crest_select.select(0)

func _select_filter_for_saved_crest() -> void:
	if selected_crest_id.is_empty():
		return
	var crest := MatchConfig.find_crest_by_id(selected_crest_id)
	if crest.is_empty():
		return
	var country := str(crest.get("country", ""))
	var league := str(crest.get("league", ""))
	for i in range(country_filter.item_count):
		if country_filter.get_item_text(i) == country:
			country_filter.select(i)
			break
	_populate_league_filter(country)
	for j in range(league_filter.item_count):
		if league_filter.get_item_text(j) == league:
			league_filter.select(j)
			break
	_populate_crest_select(country, league)

func _on_country_filter_changed(index: int) -> void:
	var country := str(country_filter.get_item_text(index))
	_populate_league_filter(country)
	_refresh_crest_preview()
	_refresh_team_meta()

func _on_league_filter_changed(index: int) -> void:
	if country_filter.item_count == 0:
		return
	var country := str(country_filter.get_item_text(country_filter.get_selected()))
	var league := str(league_filter.get_item_text(index))
	_populate_crest_select(country, league)
	_refresh_crest_preview()
	_refresh_team_meta()

func _on_crest_selected(index: int) -> void:
	selected_crest_id = str(crest_select.get_item_metadata(index))
	MatchConfig.set_selected_crest(selected_crest_id)
	_refresh_crest_preview()
	_refresh_team_meta()

func _refresh_crest_preview() -> void:
	if selected_crest_id.is_empty():
		crest_preview_label.text = "Escudo: -"
		return
	var crest := MatchConfig.find_crest_by_id(selected_crest_id)
	if crest.is_empty():
		crest_preview_label.text = "Escudo: -"
		return
	crest_preview_label.text = "Escudo: %s %s (%s - %s)" % [
		str(crest.get("crest", "⚽")),
		str(crest.get("team", "")),
		str(crest.get("country", "")),
		str(crest.get("league", ""))
	]

func _on_profile_photo_selected(path: String) -> void:
	MatchConfig.set_profile_photo(path)
	_load_profile_photo_preview(path)

func _load_profile_photo_preview(path: String) -> void:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		profile_photo_preview.texture = null
		return
	var image := Image.new()
	if image.load(path) != OK:
		profile_photo_preview.texture = null
		return
	var tex := ImageTexture.create_from_image(image)
	profile_photo_preview.texture = tex

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
