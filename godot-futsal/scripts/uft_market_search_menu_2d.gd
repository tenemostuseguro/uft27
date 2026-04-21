extends Control

const UFT_MARKET_SCENE := "res://scenes/UFTMarketMenu2D.tscn"

@onready var status_label: Label = $Margin/VBox/Status
@onready var search_input: LineEdit = $Margin/VBox/TopRow/SearchInput
@onready var results_list: ItemList = $Margin/VBox/Results
@onready var my_cards_list: ItemList = $Margin/VBox/SellRow/MyCards
@onready var start_price_box: SpinBox = $Margin/VBox/SellRow/SellControls/StartPrice
@onready var buy_now_box: SpinBox = $Margin/VBox/SellRow/SellControls/BuyNowPrice
@onready var duration_box: SpinBox = $Margin/VBox/SellRow/SellControls/DurationSecs

var result_listing_ids: Array[String] = []
var my_card_ids: Array[String] = []

func _ready() -> void:
	_connect_button("Margin/VBox/TopRow/Back", _on_back_pressed)
	_connect_button("Margin/VBox/TopRow/ApplySearch", _on_search_pressed)
	_connect_button("Margin/VBox/SellRow/SellControls/SellSelected", _on_sell_selected_pressed)
	_refresh_my_cards()
	_on_search_pressed()

func _connect_button(path: String, callback: Callable) -> void:
	var btn := get_node_or_null(path)
	if btn != null and btn is Button and not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)

func _on_search_pressed() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	results_list.clear()
	result_listing_ids.clear()
	for listing in uft.get_market_listings({"query": search_input.text}):
		var card: Dictionary = listing.get("card", {})
		var player: Dictionary = card.get("player", {})
		result_listing_ids.append(str(listing.get("listing_id", "")))
		results_list.add_item("%s (%s) OVR %d | Start %d | Bid %d | Buy %d" % [str(player.get("name", "?")), str(player.get("main_position", "")), int(card.get("ovr", 0)), int(listing.get("start_price", 0)), int(listing.get("current_bid", 0)), int(listing.get("buy_now_price", 0))])
	status_label.text = "Resultados: %d" % result_listing_ids.size()

func _refresh_my_cards() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		return
	my_cards_list.clear()
	my_card_ids.clear()
	for card in uft.get_collection_cards():
		var player: Dictionary = card.get("player", {})
		my_card_ids.append(str(card.get("card_id", "")))
		my_cards_list.add_item("%s (%s) OVR %d" % [str(player.get("name", "?")), str(player.get("main_position", "")), int(card.get("ovr", 0))])

func _on_sell_selected_pressed() -> void:
	var selected := my_cards_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Selecciona una carta para publicar."
		return
	var index := int(selected[0])
	if index < 0 or index >= my_card_ids.size():
		status_label.text = "Carta inválida."
		return
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var result: Dictionary = uft.list_card_on_market(my_card_ids[index], int(start_price_box.value), int(buy_now_box.value), int(duration_box.value))
	if result.get("ok", false):
		status_label.text = "Carta publicada."
		_refresh_my_cards()
		_on_search_pressed()
	else:
		status_label.text = "No se pudo publicar: %s" % str(result.get("error", "error"))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(UFT_MARKET_SCENE)
