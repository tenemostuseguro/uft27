extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const GAME_SCENE := "res://scenes/Main3D.tscn"

@onready var summary_label: Label = $Margin/VBox/Summary
@onready var status_label: Label = $Margin/VBox/Status
@onready var collection_list: ItemList = $Margin/VBox/Collection
@onready var market_list: ItemList = $Margin/VBox/Market

func _ready() -> void:
	$Margin/VBox/Buttons/SquadBattle.pressed.connect(_on_squad_battle_pressed)
	$Margin/VBox/Buttons/Champions.pressed.connect(_on_champions_pressed)
	$Margin/VBox/Buttons/OpenBronze.pressed.connect(_on_open_bronze)
	$Margin/VBox/Buttons/OpenEvent.pressed.connect(_on_open_event)
	$Margin/VBox/Buttons/ClaimPass.pressed.connect(_on_claim_pass)
	$Margin/VBox/Buttons/Back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	_refresh()

func _refresh() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var sum: Dictionary = uft.get_summary()
	summary_label.text = "Club: %s | Coins: %d | Points: %d | XP: %d | División: %d" % [str(sum.get("club_name", "")), int(sum.get("coins", 0)), int(sum.get("points", 0)), int(sum.get("season_xp", 0)), int(sum.get("division", 10))]
	collection_list.clear()
	for card in uft.get_collection_cards():
		var player: Dictionary = card.get("player", {})
		collection_list.add_item("%s (%s) OVR %d [%s]" % [str(player.get("name", "?")), str(player.get("main_position", "")), int(card.get("ovr", 0)), str(card.get("card_type", ""))])
	market_list.clear()
	for listing in uft.get_market_listings():
		var card: Dictionary = listing.get("card", {})
		var player: Dictionary = card.get("player", {})
		market_list.add_item("%s - %d coins" % [str(player.get("name", "?")), int(listing.get("price", 0))])

func _on_squad_battle_pressed() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	var valid: Dictionary = uft.validate_lineup()
	if not valid.get("ok", false):
		status_label.text = str(valid.get("error", "Lineup inválida"))
		return
	uft.start_mode(uft.MODE_SQUAD_BATTLE)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_champions_pressed() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	var valid: Dictionary = uft.validate_lineup()
	if not valid.get("ok", false):
		status_label.text = str(valid.get("error", "Lineup inválida"))
		return
	uft.start_mode(uft.MODE_CHAMPIONS)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_open_bronze() -> void:
	var result: Dictionary = get_node("/root/UFTManager").open_pack("bronze_pack")
	status_label.text = "Sobre Bronce: %s" % ("OK" if result.get("ok", false) else str(result.get("error", "error")))
	_refresh()

func _on_open_event() -> void:
	var result: Dictionary = get_node("/root/UFTManager").open_pack("event_pack")
	status_label.text = "Sobre Evento: %s" % ("OK" if result.get("ok", false) else str(result.get("error", "error")))
	_refresh()

func _on_claim_pass() -> void:
	var result: Dictionary = get_node("/root/UFTManager").claim_battle_pass(1, false)
	status_label.text = "Pase: %s" % ("Reclamado" if result.get("ok", false) else str(result.get("error", "error")))
	_refresh()
