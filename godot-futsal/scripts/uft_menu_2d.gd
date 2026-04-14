extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const GAME_SCENE := "res://scenes/Main3D.tscn"

@onready var summary_label: Label = $Margin/VBox/Summary
@onready var status_label: Label = $Margin/VBox/Status
@onready var collection_list: ItemList = $Margin/VBox/Row/Collection
@onready var market_list: ItemList = $Margin/VBox/Row/Market

var market_listing_ids: Array[String] = []
var collection_card_ids: Array[String] = []

func _ready() -> void:
	var squad_btn := get_node_or_null("Margin/VBox/Buttons/SquadBattle")
	var champs_btn := get_node_or_null("Margin/VBox/Buttons/Champions")
	var bronze_btn := get_node_or_null("Margin/VBox/Buttons/OpenBronze")
	var event_btn := get_node_or_null("Margin/VBox/Buttons/OpenEvent")
	var claim_btn := get_node_or_null("Margin/VBox/Buttons/ClaimPass")
	var buy_market_btn := get_node_or_null("Margin/VBox/Buttons/BuyMarket")
	var list_market_btn := get_node_or_null("Margin/VBox/Buttons/ListSelected")
	var back_btn := get_node_or_null("Margin/VBox/Buttons2/Back")
	if squad_btn != null:
		squad_btn.pressed.connect(_on_squad_battle_pressed)
	if champs_btn != null:
		champs_btn.pressed.connect(_on_champions_pressed)
	if bronze_btn != null:
		bronze_btn.pressed.connect(_on_open_bronze)
	if event_btn != null:
		event_btn.pressed.connect(_on_open_event)
	if claim_btn != null:
		claim_btn.pressed.connect(_on_claim_pass)
	if buy_market_btn != null:
		buy_market_btn.pressed.connect(_on_buy_market)
	if list_market_btn != null:
		list_market_btn.pressed.connect(_on_list_selected_card)
	if back_btn != null:
		back_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	market_list.item_activated.connect(_on_market_item_activated)
	_refresh()

func _refresh() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var sum: Dictionary = uft.get_summary()
	summary_label.text = "Club: %s | Coins: %d | Points: %d | XP: %d | División: %d" % [str(sum.get("club_name", "")), int(sum.get("coins", 0)), int(sum.get("points", 0)), int(sum.get("season_xp", 0)), int(sum.get("division", 10))]
	collection_list.clear()
	collection_card_ids.clear()
	for card in uft.get_collection_cards():
		var player: Dictionary = card.get("player", {})
		collection_card_ids.append(str(card.get("card_id", "")))
		collection_list.add_item("%s (%s) OVR %d [%s]" % [str(player.get("name", "?")), str(player.get("main_position", "")), int(card.get("ovr", 0)), str(card.get("card_type", ""))])
	market_list.clear()
	market_listing_ids.clear()
	for listing in uft.get_market_listings():
		var card: Dictionary = listing.get("card", {})
		var player: Dictionary = card.get("player", {})
		market_listing_ids.append(str(listing.get("listing_id", "")))
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
	var status := "OK"
	if not result.get("ok", false):
		status = str(result.get("error", "error"))
	status_label.text = "Sobre Bronce: %s" % status
	_refresh()

func _on_open_event() -> void:
	var result: Dictionary = get_node("/root/UFTManager").open_pack("event_pack")
	var status := "OK"
	if not result.get("ok", false):
		status = str(result.get("error", "error"))
	status_label.text = "Sobre Evento: %s" % status
	_refresh()

func _on_claim_pass() -> void:
	var result: Dictionary = get_node("/root/UFTManager").claim_battle_pass(1, false)
	var status := "Reclamado"
	if not result.get("ok", false):
		status = str(result.get("error", "error"))
	status_label.text = "Pase: %s" % status
	_refresh()

func _on_buy_market() -> void:
	var index := market_list.get_selected_items()
	if index.is_empty():
		status_label.text = "Selecciona una carta del mercado para comprar."
		return
	_buy_market_listing_at(index[0])

func _on_market_item_activated(index: int) -> void:
	_buy_market_listing_at(index)

func _buy_market_listing_at(index: int) -> void:
	if index < 0 or index >= market_listing_ids.size():
		status_label.text = "Oferta inválida."
		return
	var listing_id := market_listing_ids[index]
	var result: Dictionary = get_node("/root/UFTManager").buy_market_listing(listing_id)
	if result.get("ok", false):
		status_label.text = "Compra realizada: %s" % str(result.get("card_id", ""))
	else:
		status_label.text = "Compra fallida: %s" % str(result.get("error", "error"))
	_refresh()

func _on_list_selected_card() -> void:
	var selected := collection_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Selecciona una carta de tu colección para listar."
		return
	var index := int(selected[0])
	if index < 0 or index >= collection_card_ids.size():
		status_label.text = "Carta inválida."
		return
	var card_id := collection_card_ids[index]
	var price := int(get_node("/root/UFTManager").get_card_details(card_id).get("suggested_price", 100))
	var result: Dictionary = get_node("/root/UFTManager").list_card_on_market(card_id, max(100, price))
	if result.get("ok", false):
		status_label.text = "Carta listada en el mercado."
	else:
		status_label.text = "No se pudo listar: %s" % str(result.get("error", "error"))
	_refresh()
