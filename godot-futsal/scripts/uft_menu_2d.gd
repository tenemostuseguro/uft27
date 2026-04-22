extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const GAME_SCENE := "res://scenes/Main3D.tscn"
const MARKET_SCENE := "res://scenes/UFTMarketMenu2D.tscn"
const COURT_TEXTURE_PATH := "res://assets/court.png"
const EMPTY_SLOT_TEXTURE_PATH := "res://assets/vacio.png"
const POSITIONS: Array[String] = ["POR", "C", "AI", "AD", "P"]

const FORMATIONS := {
	"1-2-1": {
		"POR": Vector2(0.50, 0.88),
		"C": Vector2(0.50, 0.62),
		"AI": Vector2(0.28, 0.42),
		"AD": Vector2(0.72, 0.42),
		"P": Vector2(0.50, 0.18)
	},
	"1-1-2": {
		"POR": Vector2(0.50, 0.88),
		"C": Vector2(0.50, 0.52),
		"AI": Vector2(0.34, 0.28),
		"AD": Vector2(0.66, 0.28),
		"P": Vector2(0.50, 0.12)
	},
	"1-3-0": {
		"POR": Vector2(0.50, 0.88),
		"C": Vector2(0.50, 0.60),
		"AI": Vector2(0.32, 0.46),
		"AD": Vector2(0.68, 0.46),
		"P": Vector2(0.50, 0.34)
	}
}

@onready var club_label: Label = $Margin/VBox/TopBar/TopRow/ClubInfo
@onready var currency_label: Label = $Margin/VBox/TopBar/TopRow/Currency
@onready var squad_meta_label: Label = $Margin/VBox/Content/SquadPanel/SquadVBox/SquadMeta
@onready var status_label: Label = $Margin/VBox/Status
@onready var formation_select: OptionButton = $Margin/VBox/Content/SquadPanel/SquadVBox/FormationRow/FormationSelect
@onready var auto_fill_btn: Button = $Margin/VBox/Content/SquadPanel/SquadVBox/FormationRow/AutoFill
@onready var court_rect: TextureRect = $Margin/VBox/Content/SquadPanel/SquadVBox/FieldArea/Court
@onready var slot_layer: Control = $Margin/VBox/Content/SquadPanel/SquadVBox/FieldArea/SlotLayer
@onready var collection_list: ItemList = $Margin/VBox/Content/SquadPanel/SquadVBox/Collection

var current_formation := "1-2-1"
var lineup_cards: Dictionary = {"POR":"", "C":"", "AI":"", "AD":"", "P":""}
var slot_nodes: Dictionary = {}
var card_cache: Dictionary = {}
var collection_card_ids: Array[String] = []
var selected_slot := "P"

var dragging := false
var drag_from_slot := ""
var drag_preview: TextureRect = null

func _ready() -> void:
	_connect_button("Margin/VBox/BottomTabs/SquadBattle", _on_squad_battle_pressed)
	_connect_button("Margin/VBox/BottomTabs/Champions", _on_champions_pressed)
	_connect_button("Margin/VBox/BottomTabs/OpenBronze", _on_open_bronze)
	_connect_button("Margin/VBox/BottomTabs/OpenEvent", _on_open_event)
	_connect_button("Margin/VBox/BottomTabs/ClaimPass", _on_claim_pass)
	_connect_button("Margin/VBox/BottomTabs/Back", _on_back_pressed)
	_connect_button("Margin/VBox/Content/PromoPanel/PromoVBox/OpenMarket", _on_open_market_pressed)
	auto_fill_btn.pressed.connect(_on_auto_fill_pressed)
	collection_list.item_activated.connect(_on_collection_item_activated)
	formation_select.item_selected.connect(_on_formation_selected)
	set_process(true)
	_setup_visuals()
	_refresh()

func _process(_delta: float) -> void:
	if dragging and drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size * 0.5

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag("")
	if event is InputEventScreenTouch and not event.pressed:
		_finish_drag("")

func _setup_visuals() -> void:
	var court_tex := load(COURT_TEXTURE_PATH)
	if court_tex is Texture2D:
		court_rect.texture = court_tex
	formation_select.clear()
	for key in FORMATIONS.keys():
		formation_select.add_item(key)
	formation_select.select(0)

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
	lineup_cards = (uft.state.get("lineup", {}) as Dictionary).duplicate(true)
	for pos in POSITIONS:
		if not lineup_cards.has(pos):
			lineup_cards[pos] = ""
	_build_collection(uft)
	_rebuild_slot_nodes()
	_refresh_slot_visuals()
	_refresh_squad_meta(uft)

func _build_collection(uft: Node) -> void:
	collection_list.clear()
	collection_card_ids.clear()
	card_cache.clear()
	for card in uft.get_collection_cards():
		var card_id := str(card.get("card_id", ""))
		card_cache[card_id] = card
		collection_card_ids.append(card_id)
		var player: Dictionary = card.get("player", {})
		collection_list.add_item("%s (%s) OVR %d" % [str(player.get("name", "?")), str(player.get("main_position", "")), int(card.get("ovr", 0))])

func _rebuild_slot_nodes() -> void:
	for child in slot_layer.get_children():
		child.queue_free()
	slot_nodes.clear()
	var formation: Dictionary = FORMATIONS.get(current_formation, FORMATIONS["1-2-1"])
	for pos in POSITIONS:
		var marker := TextureRect.new()
		marker.custom_minimum_size = Vector2(74, 100)
		marker.size = Vector2(74, 100)
		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker.mouse_filter = Control.MOUSE_FILTER_STOP
		var p: Vector2 = formation.get(pos, Vector2(0.5, 0.5))
		marker.position = Vector2(slot_layer.size.x * p.x - 37, slot_layer.size.y * p.y - 50)
		marker.gui_input.connect(_on_slot_gui_input.bind(pos))
		slot_layer.add_child(marker)
		var lbl := Label.new()
		lbl.text = pos
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.anchors_preset = Control.PRESET_FULL_RECT
		marker.add_child(lbl)
		slot_nodes[pos] = marker

func _refresh_slot_visuals() -> void:
	for pos in POSITIONS:
		var slot := slot_nodes.get(pos, null)
		if slot == null:
			continue
		var card_id := str(lineup_cards.get(pos, ""))
		if card_id.is_empty():
			_assign_empty_texture(slot)
		else:
			_load_card_slot_texture(slot, card_id)
		if pos == selected_slot:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			slot.modulate = Color(0.85, 0.85, 0.85, 1.0)

func _assign_empty_texture(slot: TextureRect) -> void:
	var empty_tex := load(EMPTY_SLOT_TEXTURE_PATH)
	if empty_tex is Texture2D:
		slot.texture = empty_tex
	else:
		slot.texture = null

func _load_card_slot_texture(slot: TextureRect, card_id: String) -> void:
	var card: Dictionary = card_cache.get(card_id, {})
	if card.is_empty():
		_assign_empty_texture(slot)
		return
	var url := str(card.get("card_frame_url", ""))
	if url.is_empty():
		url = str(card.get("face_url", ""))
	if url.is_empty():
		_assign_empty_texture(slot)
		return
	_load_remote_texture_into(slot, url)

func _load_remote_texture_into(slot: TextureRect, url: String) -> void:
	var tex := await _fetch_remote_texture(url)
	if tex == null:
		_assign_empty_texture(slot)
		return
	if not is_instance_valid(slot):
		return
	slot.texture = tex

func _fetch_remote_texture(url: String) -> Texture2D:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return null
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return null
	var body: PackedByteArray = result[3]
	if body.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(body) != OK and image.load_jpg_from_buffer(body) != OK and image.load_webp_from_buffer(body) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _on_slot_input(pos: String, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			selected_slot = pos
			_refresh_slot_visuals()
			_start_drag(pos)
		else:
			_finish_drag(pos)
	if event is InputEventScreenTouch:
		if event.pressed:
			selected_slot = pos
			_refresh_slot_visuals()
			_start_drag(pos)
		else:
			_finish_drag(pos)

func _on_slot_gui_input(event: InputEvent, pos: String) -> void:
	_on_slot_input(pos, event)

func _start_drag(pos: String) -> void:
	var card_id := str(lineup_cards.get(pos, ""))
	if card_id.is_empty():
		return
	dragging = true
	drag_from_slot = pos
	if drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = TextureRect.new()
	drag_preview.size = Vector2(74, 100)
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.z_index = 99
	var origin: TextureRect = slot_nodes.get(pos, null)
	if origin != null:
		drag_preview.texture = origin.texture
	add_child(drag_preview)

func _finish_drag(target_pos: String) -> void:
	if not dragging:
		return
	if target_pos.is_empty():
		target_pos = _find_slot_under_mouse()
	if not target_pos.is_empty() and target_pos != drag_from_slot:
		_swap_slots(drag_from_slot, target_pos)
	dragging = false
	drag_from_slot = ""
	if drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null

func _find_slot_under_mouse() -> String:
	var mouse := get_global_mouse_position()
	for pos in POSITIONS:
		var slot: TextureRect = slot_nodes.get(pos, null)
		if slot == null:
			continue
		var r := Rect2(slot.global_position, slot.size)
		if r.has_point(mouse):
			return pos
	return ""

func _swap_slots(from_pos: String, to_pos: String) -> void:
	var from_id := str(lineup_cards.get(from_pos, ""))
	var to_id := str(lineup_cards.get(to_pos, ""))
	if not _lineup_swap_is_valid(from_pos, from_id, to_pos, to_id):
		status_label.text = "No se permite repetir al mismo jugador en la alineación."
		return
	lineup_cards[from_pos] = to_id
	lineup_cards[to_pos] = from_id
	_commit_lineup_to_manager()
	_refresh_slot_visuals()
	_refresh_squad_meta(get_node_or_null("/root/UFTManager"))

func _lineup_swap_is_valid(from_pos: String, from_id: String, to_pos: String, to_id: String) -> bool:
	var simulated := lineup_cards.duplicate(true)
	simulated[from_pos] = to_id
	simulated[to_pos] = from_id
	return _has_unique_players(simulated)

func _has_unique_players(lineup: Dictionary) -> bool:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		return true
	var seen := {}
	for pos in POSITIONS:
		var card_id := str(lineup.get(pos, ""))
		if card_id.is_empty():
			continue
		var details: Dictionary = uft.get_card_details(card_id)
		var player: Dictionary = details.get("player", {})
		var player_id := str(player.get("player_id", ""))
		if seen.has(player_id):
			return false
		seen[player_id] = true
	return true

func _on_collection_item_activated(index: int) -> void:
	if index < 0 or index >= collection_card_ids.size():
		return
	var card_id := collection_card_ids[index]
	_assign_card_to_slot(card_id, selected_slot)

func _assign_card_to_slot(card_id: String, target_pos: String) -> void:
	if target_pos.is_empty():
		return
	var simulated := lineup_cards.duplicate(true)
	simulated[target_pos] = card_id
	if not _has_unique_players(simulated):
		status_label.text = "No puedes usar dos cartas del mismo jugador en el quinteto."
		return
	lineup_cards[target_pos] = card_id
	_commit_lineup_to_manager()
	_refresh_slot_visuals()
	_refresh_squad_meta(get_node_or_null("/root/UFTManager"))

func _on_auto_fill_pressed() -> void:
	var used_players := {}
	for pos in POSITIONS:
		var card_id := str(lineup_cards.get(pos, ""))
		if card_id.is_empty():
			continue
		var details: Dictionary = card_cache.get(card_id, {})
		var player: Dictionary = details.get("player", {})
		used_players[str(player.get("player_id", ""))] = true
	for pos in POSITIONS:
		if not str(lineup_cards.get(pos, "")).is_empty():
			continue
		for card_id in collection_card_ids:
			var card: Dictionary = card_cache.get(card_id, {})
			var player: Dictionary = card.get("player", {})
			var player_id := str(player.get("player_id", ""))
			if used_players.has(player_id):
				continue
			lineup_cards[pos] = card_id
			used_players[player_id] = true
			break
	_commit_lineup_to_manager()
	_refresh_slot_visuals()
	_refresh_squad_meta(get_node_or_null("/root/UFTManager"))

func _on_formation_selected(index: int) -> void:
	current_formation = formation_select.get_item_text(index)
	_rebuild_slot_nodes()
	_refresh_slot_visuals()

func _commit_lineup_to_manager() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		return
	uft.state["lineup"] = lineup_cards.duplicate(true)
	if uft.has_method("_save_state"):
		uft._save_state()

func _refresh_squad_meta(uft: Node) -> void:
	if uft == null:
		squad_meta_label.text = "Rating 0 · Chemistry 0"
		return
	var total := 0
	var count := 0
	for pos in POSITIONS:
		var card_id := str(lineup_cards.get(pos, ""))
		if card_id.is_empty():
			continue
		var details: Dictionary = uft.get_card_details(card_id)
		total += int(details.get("ovr", 0))
		count += 1
	var rating: int = int(round(float(total) / float(max(1, count)))) if count > 0 else 0
	var chemistry := count * 20
	squad_meta_label.text = "Rating %d · Chemistry %d" % [rating, chemistry]

func _on_squad_battle_pressed() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var valid: Dictionary = uft.validate_lineup(lineup_cards)
	if not valid.get("ok", false):
		status_label.text = str(valid.get("error", "Lineup inválida"))
		return
	_commit_lineup_to_manager()
	uft.start_mode(uft.MODE_SQUAD_BATTLE)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_champions_pressed() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var valid: Dictionary = uft.validate_lineup(lineup_cards)
	if not valid.get("ok", false):
		status_label.text = str(valid.get("error", "Lineup inválida"))
		return
	_commit_lineup_to_manager()
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
