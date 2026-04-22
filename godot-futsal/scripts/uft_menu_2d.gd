extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const GAME_SCENE := "res://scenes/Main3D.tscn"
const MARKET_SCENE := "res://scenes/UFTMarketMenu2D.tscn"
const SQUAD_SCENE := "res://scenes/UFTSquadMenu2D.tscn"
const POSITIONS: Array[String] = ["POR", "C", "AI", "AD", "P"]

@onready var club_label: Label = $Margin/VBox/TopBar/TopRow/ClubInfo
@onready var currency_label: Label = $Margin/VBox/TopBar/TopRow/Currency
@onready var squad_meta_label: Label = $Margin/VBox/Content/SquadPanel/SquadVBox/SquadMeta
@onready var lineup_text: Label = $Margin/VBox/Content/SquadPanel/SquadVBox/LineupText
@onready var status_label: Label = $Margin/VBox/Status

func _ready() -> void:
	_connect_button("Margin/VBox/BottomTabs/SquadBattle", _on_open_squad_menu)
	_connect_button("Margin/VBox/Content/SquadPanel/SquadVBox/OpenSquadMenu", _on_open_squad_menu)
	_connect_button("Margin/VBox/BottomTabs/Champions", _on_champions_pressed)
	_connect_button("Margin/VBox/BottomTabs/OpenBronze", _on_open_bronze)
	_connect_button("Margin/VBox/BottomTabs/OpenEvent", _on_open_event)
	_connect_button("Margin/VBox/BottomTabs/ClaimPass", _on_claim_pass)
	_connect_button("Margin/VBox/BottomTabs/Back", _on_back_pressed)
	_connect_button("Margin/VBox/Content/PromoPanel/PromoVBox/OpenMarket", _on_open_market_pressed)
	_refresh()

func _connect_button(path: String, callback: Callable) -> void:
	var btn := get_node_or_null(path)
	if btn != null and btn is Button and not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)

func _refresh() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var sum: Dictionary = uft.get_summary()
	club_label.text = "%s · DIV %d" % [str(sum.get("club_name", "Mi Club UFT")), int(sum.get("division", 10))]
	currency_label.text = "Coins %d | Points %d | XP %d" % [int(sum.get("coins", 0)), int(sum.get("points", 0)), int(sum.get("season_xp", 0))]
	var lineup: Dictionary = uft.state.get("lineup", {})
	var text_parts: Array[String] = []
	var total := 0
	var count := 0
	for pos in POSITIONS:
		var card_id := str(lineup.get(pos, ""))
		if card_id.is_empty():
			text_parts.append("%s:-" % pos)
			continue
		var details: Dictionary = uft.get_card_details(card_id)
		var player: Dictionary = details.get("player", {})
		text_parts.append("%s:%s" % [pos, str(player.get("name", "?"))])
		total += int(details.get("ovr", 0))
		count += 1
	lineup_text.text = "  ".join(text_parts)
	var rating: int = int(round(float(total) / float(max(1, count)))) if count > 0 else 0
	squad_meta_label.text = "Rating %d · Chemistry %d" % [rating, count * 20]

func _on_open_squad_menu() -> void:
	get_tree().change_scene_to_file(SQUAD_SCENE)

func _on_champions_pressed() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var valid: Dictionary = uft.validate_lineup()
	if not valid.get("ok", false):
		status_label.text = str(valid.get("error", "Lineup inválida"))
		return
	uft.start_mode(uft.MODE_CHAMPIONS)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_open_bronze() -> void:
	var result: Dictionary = get_node("/root/UFTManager").open_pack("bronze_pack")
	status_label.text = "Pack Bronce: %s" % ("OK" if result.get("ok", false) else str(result.get("error", "error")))
	_refresh()

func _on_open_event() -> void:
	var result: Dictionary = get_node("/root/UFTManager").open_pack("event_pack")
	status_label.text = "Pack Evento: %s" % ("OK" if result.get("ok", false) else str(result.get("error", "error")))
	_refresh()

func _on_claim_pass() -> void:
	var result: Dictionary = get_node("/root/UFTManager").claim_battle_pass(1, false)
	status_label.text = "Pase: %s" % ("Reclamado" if result.get("ok", false) else str(result.get("error", "error")))
	_refresh()

func _on_open_market_pressed() -> void:
	get_tree().change_scene_to_file(MARKET_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
