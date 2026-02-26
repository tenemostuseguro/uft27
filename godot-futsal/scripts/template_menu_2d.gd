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

@onready var gk_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/GKCard/VBox/PlayerSelect
@onready var cierre_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/CierreCard/VBox/PlayerSelect
@onready var ala_izq_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/AlaIzqCard/VBox/PlayerSelect
@onready var ala_der_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/AlaDerCard/VBox/PlayerSelect
@onready var pivot_option: OptionButton = $Margin/Layout/SquadArea/PitchPanel/PivotCard/VBox/PlayerSelect

@onready var selected_name_label: Label = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/NameLabel
@onready var selected_role_label: Label = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/RoleLabel
@onready var selected_stats_label: Label = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/StatsLabel
@onready var bench_list: ItemList = $Margin/Layout/SquadArea/PlayerInfo/InfoLayout/BenchList

var role_options: Dictionary = {}

func _ready() -> void:
	role_options = {
		"GK": gk_option,
		"Cierre": cierre_option,
		"Ala Izq": ala_izq_option,
		"Ala Der": ala_der_option,
		"Pivot": pivot_option
	}

	$Margin/Layout/Footer/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$Margin/Layout/Footer/Buttons/BackButton.pressed.connect(_on_back_pressed)

	for role in ROLE_KEYS:
		var option: OptionButton = role_options[role]
		option.item_selected.connect(_on_role_selection_changed.bind(role))
		_populate_role_option(role, option)

	_load_current_values()
	_refresh_team_meta()
	_refresh_bench_preview()
	_show_player_from_role("Pivot")

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
	var complete := true
	for role in ROLE_KEYS:
		if str(lineup.get(role, "")).is_empty():
			complete = false
			break

	var preview_rating := _compute_rating_preview(lineup)
	rating_label.text = "Rating: %d" % preview_rating
	chemistry_label.text = "Chemistry: %d" % (100 if complete else 60)

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
		if count >= 12:
			break

func _on_save_pressed() -> void:
	var lineup: Dictionary = _build_lineup_from_ui()
	MatchConfig.set_template(
		team_name_input.text,
		primary_input.text,
		secondary_input.text,
		formation_input.text,
		lineup
	)

	if MatchConfig.template_ready:
		status_label.text = "Plantilla guardada ✅"
	else:
		status_label.text = "Falta seleccionar jugador en alguna posición"
	_refresh_team_meta()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
