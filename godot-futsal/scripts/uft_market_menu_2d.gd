extends Control

const UFT_MENU_SCENE := "res://scenes/UFTMenu2D.tscn"
const UFT_MARKET_SEARCH_SCENE := "res://scenes/UFTMarketSearchMenu2D.tscn"

@onready var status_label: Label = $Margin/VBox/Status
@onready var coins_label: Label = $Margin/VBox/TopBar/TopRow/Coins
@onready var listings_grid: HBoxContainer = $Margin/VBox/Body/ListingsScroll/ListingsGrid

var listing_cards: Array[Dictionary] = []
var countdown_labels: Array[Dictionary] = []

func _ready() -> void:
	_connect_button("Margin/VBox/TopBar/TopRow/Back", _on_back_pressed)
	_connect_button("Margin/VBox/TopBar/TopRow/Search", _on_open_search_pressed)
	_connect_button("Margin/VBox/TopBar/TopRow/Sell", _on_sell_pressed)
	_connect_button("Margin/VBox/TabBar/BrowseTab", _on_browse_tab)
	_connect_button("Margin/VBox/TabBar/MyListingsTab", _on_my_listings_tab)
	_connect_button("Margin/VBox/TabBar/MyBidsTab", _on_my_bids_tab)
	set_process(true)
	_refresh()

func _process(_delta: float) -> void:
	for item in countdown_labels:
		var timer_label: Label = item.get("label", null) as Label
		if timer_label == null:
			continue
		if not is_instance_valid(timer_label):
			continue
		var expiry: int = int(item.get("expires_at_unix", 0))
		timer_label.text = _format_countdown(expiry)

func _connect_button(path: String, callback: Callable) -> void:
	var btn := get_node_or_null(path)
	if btn != null and btn is Button and not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)

func _refresh(filters: Dictionary = {}) -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return

	var sum: Dictionary = uft.get_summary()
	coins_label.text = "Coins %d" % int(sum.get("coins", 0))
	listing_cards = uft.get_market_listings(filters)
	countdown_labels.clear()
	for child in listings_grid.get_children():
		child.queue_free()

	for listing in listing_cards:
		listings_grid.add_child(_build_listing_tile(listing))

	status_label.text = "Mercado: %d cartas activas" % listing_cards.size()

func _build_listing_tile(listing: Dictionary) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(230, 470)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	root.add_child(vbox)

	var card: Dictionary = listing.get("card", {})
	var player: Dictionary = card.get("player", {})

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(220, 280)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(portrait)
	_load_card_texture(portrait, card)

	var timer := Label.new()
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", 32)
	var expires_at_unix: int = int(listing.get("expires_at_unix", 0))
	timer.text = _format_countdown(expires_at_unix)
	vbox.add_child(timer)
	countdown_labels.append({"label": timer, "expires_at_unix": expires_at_unix})

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 3)
	vbox.add_child(footer)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = "%s · OVR %d" % [str(player.get("name", "?")), int(card.get("ovr", 0))]
	footer.add_child(name_label)

	var start_label := Label.new()
	start_label.text = "Start Price: %d" % int(listing.get("start_price", 0))
	footer.add_child(start_label)

	var bid_label := Label.new()
	bid_label.text = "Current Bid: %d" % int(listing.get("current_bid", 0))
	footer.add_child(bid_label)

	var buy_label := Label.new()
	buy_label.text = "Buy Now: %d" % int(listing.get("buy_now_price", 0))
	footer.add_child(buy_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	footer.add_child(actions)

	var bid_btn := Button.new()
	bid_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bid_btn.text = "Pujar"
	bid_btn.pressed.connect(func() -> void:
		_on_bid_pressed(str(listing.get("listing_id", "")), int(listing.get("current_bid", 0)), int(listing.get("start_price", 0)))
	)
	actions.add_child(bid_btn)

	var buy_btn := Button.new()
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.text = "Comprar ya"
	buy_btn.pressed.connect(func() -> void:
		_on_buy_now_pressed(str(listing.get("listing_id", "")))
	)
	actions.add_child(buy_btn)

	return root

func _load_card_texture(target: TextureRect, card: Dictionary) -> void:
	var player: Dictionary = card.get("player", {})
	var image_urls: Array[String] = [
		str(card.get("card_frame_url", "")),
		str(card.get("face_url", "")),
		str(player.get("photo_face_url", ""))
	]
	for image_url in image_urls:
		if image_url.is_empty():
			continue
		var tex: Texture2D = await _fetch_remote_texture(image_url)
		if tex != null:
			target.texture = tex
			return

func _format_countdown(expires_at_unix: int) -> String:
	var remaining: int = max(0, expires_at_unix - int(Time.get_unix_time_from_system()))
	var hours: int = int(floor(float(remaining) / 3600.0))
	var minutes: int = int(floor(float(remaining % 3600) / 60.0))
	var seconds: int = remaining % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

func _fetch_remote_texture(url: String) -> Texture2D:
	var http := HTTPRequest.new()
	add_child(http)
	var err: int = http.request(url)
	if err != OK:
		http.queue_free()
		return null
	var completed: Array = await http.request_completed
	http.queue_free()
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return null
	var status_code: int = int(completed[1])
	if status_code < 200 or status_code >= 300:
		return null
	var body: PackedByteArray = completed[3]
	if body.is_empty():
		return null
	var image := Image.new()
	var parse_ok := false
	parse_ok = image.load_png_from_buffer(body) == OK
	if not parse_ok:
		parse_ok = image.load_jpg_from_buffer(body) == OK
	if not parse_ok:
		parse_ok = image.load_webp_from_buffer(body) == OK
	if not parse_ok:
		return null
	return ImageTexture.create_from_image(image)

func _on_bid_pressed(listing_id: String, current_bid: int, start_price: int) -> void:
	var min_bid: int = max(start_price, current_bid + 100)
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var result: Dictionary = uft.place_bid_on_listing(listing_id, min_bid)
	if result.get("ok", false):
		status_label.text = "Puja realizada: %d" % int(result.get("amount", min_bid))
	else:
		status_label.text = "Puja fallida: %s" % str(result.get("error", "error"))
	_refresh()

func _on_buy_now_pressed(listing_id: String) -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var result: Dictionary = uft.buy_market_listing(listing_id)
	if result.get("ok", false):
		status_label.text = "Compra realizada: %s" % str(result.get("card_id", ""))
	else:
		status_label.text = "Compra fallida: %s" % str(result.get("error", "error"))
	_refresh()

func _on_open_search_pressed() -> void:
	get_tree().change_scene_to_file(UFT_MARKET_SEARCH_SCENE)

func _on_sell_pressed() -> void:
	status_label.text = "Selecciona una carta en Search para listar en mercado."

func _on_browse_tab() -> void:
	_refresh()

func _on_my_listings_tab() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		return
	_refresh({"seller": "user"})

func _on_my_bids_tab() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		return
	_refresh({"highest_bidder": str(uft.state.get("club_name", ""))})

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(UFT_MENU_SCENE)
