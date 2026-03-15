extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"

@onready var photo_preview: TextureRect = $Margin/VBox/Row/PhotoPanel/PhotoVBox/PhotoPreview
@onready var photo_button: Button = $Margin/VBox/Row/PhotoPanel/PhotoVBox/PhotoButton
@onready var country_filter: OptionButton = $Margin/VBox/Row/CrestPanel/CrestVBox/CountryFilter
@onready var league_filter: OptionButton = $Margin/VBox/Row/CrestPanel/CrestVBox/LeagueFilter
@onready var crest_select: OptionButton = $Margin/VBox/Row/CrestPanel/CrestVBox/CrestSelect
@onready var crest_preview: Label = $Margin/VBox/Row/CrestPanel/CrestVBox/CrestPreview
@onready var status_label: Label = $Margin/VBox/Status
@onready var photo_dialog: FileDialog = $PhotoDialog

var selected_crest_id := ""

func _ready() -> void:
	$Margin/VBox/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$Margin/VBox/Buttons/BackButton.pressed.connect(_on_back_pressed)
	photo_button.pressed.connect(func() -> void: photo_dialog.popup_centered_ratio(0.7))
	photo_dialog.file_selected.connect(_on_photo_selected)
	country_filter.item_selected.connect(_on_country_changed)
	league_filter.item_selected.connect(_on_league_changed)
	crest_select.item_selected.connect(_on_crest_changed)

	_populate_countries()
	selected_crest_id = MatchConfig.selected_crest_id
	_select_saved_crest_filters()
	_refresh_crest_preview()
	_load_photo(MatchConfig.profile_photo_path)

func _populate_countries() -> void:
	country_filter.clear()
	for c in MatchConfig.get_available_countries():
		country_filter.add_item(c)
	if country_filter.item_count > 0:
		country_filter.select(0)
		_populate_leagues(str(country_filter.get_item_text(0)))

func _populate_leagues(country: String) -> void:
	league_filter.clear()
	for league in MatchConfig.get_leagues_for_country(country):
		league_filter.add_item(league)
	if league_filter.item_count > 0:
		league_filter.select(0)
		_populate_crests(country, str(league_filter.get_item_text(0)))

func _populate_crests(country: String, league: String) -> void:
	crest_select.clear()
	crest_select.add_item("Seleccionar escudo...")
	crest_select.set_item_metadata(0, "")
	for crest in MatchConfig.get_crests(country, league):
		crest_select.add_item("%s %s" % [str(crest.get("crest", "⚽")), str(crest.get("team", ""))])
		var idx := crest_select.item_count - 1
		crest_select.set_item_metadata(idx, str(crest.get("id", "")))
	_select_saved_crest()

func _select_saved_crest() -> void:
	for i in range(crest_select.item_count):
		if str(crest_select.get_item_metadata(i)) == selected_crest_id:
			crest_select.select(i)
			return
	crest_select.select(0)

func _select_saved_crest_filters() -> void:
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
	_populate_leagues(country)
	for j in range(league_filter.item_count):
		if league_filter.get_item_text(j) == league:
			league_filter.select(j)
			break
	_populate_crests(country, league)

func _on_country_changed(index: int) -> void:
	_populate_leagues(str(country_filter.get_item_text(index)))
	_refresh_crest_preview()

func _on_league_changed(index: int) -> void:
	if country_filter.item_count == 0:
		return
	_populate_crests(str(country_filter.get_item_text(country_filter.get_selected())), str(league_filter.get_item_text(index)))
	_refresh_crest_preview()

func _on_crest_changed(index: int) -> void:
	selected_crest_id = str(crest_select.get_item_metadata(index))
	_refresh_crest_preview()

func _refresh_crest_preview() -> void:
	if selected_crest_id.is_empty():
		crest_preview.text = "Escudo: -"
		return
	var crest := MatchConfig.find_crest_by_id(selected_crest_id)
	if crest.is_empty():
		crest_preview.text = "Escudo: -"
		return
	crest_preview.text = "Escudo: %s %s (%s - %s)" % [str(crest.get("crest", "⚽")), str(crest.get("team", "")), str(crest.get("country", "")), str(crest.get("league", ""))]

func _on_photo_selected(path: String) -> void:
	MatchConfig.set_profile_photo(path)
	_load_photo(path)

func _load_photo(path: String) -> void:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		photo_preview.texture = null
		return
	var image := Image.new()
	if image.load(path) != OK:
		photo_preview.texture = null
		return
	photo_preview.texture = ImageTexture.create_from_image(image)

func _on_save_pressed() -> void:
	if selected_crest_id.is_empty():
		status_label.text = "Debes seleccionar un escudo"
		return
	MatchConfig.set_selected_crest(selected_crest_id)
	status_label.text = "Perfil guardado ✅"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
