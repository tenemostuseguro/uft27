extends Control

const UFT_MENU_SCENE := "res://scenes/UFTMenu2D.tscn"

@onready var status_label: Label = $Margin/VBox/Status
@onready var market_list: ItemList = $Margin/VBox/Body/MarketPanel/MarketVBox/MarketList
@onready var collection_list: ItemList = $Margin/VBox/Body/CollectionPanel/CollectionVBox/CollectionList

var market_listing_ids: Array[String] = []
var collection_card_ids: Array[String] = []

func _ready() -> void:
	_connect_button("Margin/VBox/TopBar/TopRow/Back", _on_back_pressed)
	_connect_button("Margin/VBox/Body/MarketPanel/MarketVBox/BuySelected", _on_buy_market)
	_connect_button("Margin/VBox/Body/CollectionPanel/CollectionVBox/ListSelected", _on_list_selected_card)
	market_list.item_activated.connect(_on_market_item_activated)
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

	market_list.clear()
	market_listing_ids.clear()
	for listing in uft.get_market_listings():
		var card: Dictionary = listing.get("card", {})
		var player: Dictionary = card.get("player", {})
		market_listing_ids.append(str(listing.get("listing_id", "")))
		market_list.add_item("%s (%s) OVR %d - %d coins" % [str(player.get("name", "?")), str(player.get("main_position", "")), int(card.get("ovr", 0)), int(listing.get("price", 0))])

	collection_list.clear()
	collection_card_ids.clear()
	for card in uft.get_collection_cards():
		var player: Dictionary = card.get("player", {})
		collection_card_ids.append(str(card.get("card_id", "")))
		collection_list.add_item("%s (%s) OVR %d [%s]" % [str(player.get("name", "?")), str(player.get("main_position", "")), int(card.get("ovr", 0)), str(card.get("card_type", ""))])

	status_label.text = "Mercado actualizado: %d ofertas" % market_listing_ids.size()

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
	var suggested := int(get_node("/root/UFTManager").get_card_details(card_id).get("suggested_price", 100))
	var result: Dictionary = get_node("/root/UFTManager").list_card_on_market(card_id, max(100, suggested))
	if result.get("ok", false):
		status_label.text = "Carta listada en el mercado."
	else:
		status_label.text = "No se pudo listar: %s" % str(result.get("error", "error"))
	_refresh()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(UFT_MENU_SCENE)
