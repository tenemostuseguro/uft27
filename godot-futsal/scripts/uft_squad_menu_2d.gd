extends Control

const UFT_MENU_SCENE := "res://scenes/UFTMenu2D.tscn"
const COURT_TEXTURE_PATH := "res://assets/court.png"
const EMPTY_SLOT_TEXTURE_PATH := "res://assets/vacio.png"
const GRL_FONT_PATH := "res://assets/fonts/grl.otf"
const GRL_BADGE_TEXTURES := {
	"low": "res://assets/amagrl.png",
	"mid": "res://assets/rojgrl.png",
	"high": "res://assets/morgrl.png",
	"elite": "res://assets/blagrl.png"
}
const POSITIONS: Array[String] = ["POR", "C", "AI", "AD", "P"]

const FORMATIONS := {
	"1-2-1": {"POR": Vector2(0.50, 0.88), "C": Vector2(0.50, 0.62), "AI": Vector2(0.28, 0.42), "AD": Vector2(0.72, 0.42), "P": Vector2(0.50, 0.18)},
	"1-1-2": {"POR": Vector2(0.50, 0.88), "C": Vector2(0.50, 0.52), "AI": Vector2(0.34, 0.28), "AD": Vector2(0.66, 0.28), "P": Vector2(0.50, 0.12)},
	"1-3-0": {"POR": Vector2(0.50, 0.88), "C": Vector2(0.50, 0.60), "AI": Vector2(0.32, 0.46), "AD": Vector2(0.68, 0.46), "P": Vector2(0.50, 0.34)}
}

@onready var squad_meta_label: Label = $Margin/VBox/SquadMeta
@onready var status_label: Label = $Margin/VBox/Status
@onready var formation_select: OptionButton = $Margin/VBox/FormationRow/FormationSelect
@onready var auto_fill_btn: Button = $Margin/VBox/FormationRow/AutoFill
@onready var court_rect: TextureRect = $Margin/VBox/FieldArea/Court
@onready var slot_layer: Control = $Margin/VBox/FieldArea/SlotLayer
@onready var collection_grid: GridContainer = $Margin/VBox/CollectionScroll/CollectionGrid

var current_formation := "1-2-1"
var lineup_cards: Dictionary = {"POR":"", "C":"", "AI":"", "AD":"", "P":""}
var slot_nodes: Dictionary = {}
var card_cache: Dictionary = {}
var collection_card_ids: Array[String] = []
var selected_slot := "P"

var dragging := false
var drag_from_slot := ""
var drag_from_collection_card_id := ""
var drag_preview: TextureRect = null
var grl_font: FontFile = null

func _ready() -> void:
	$Margin/VBox/Header/Back.pressed.connect(func() -> void: get_tree().change_scene_to_file(UFT_MENU_SCENE))
	auto_fill_btn.pressed.connect(_on_auto_fill_pressed)
	formation_select.item_selected.connect(_on_formation_selected)
	slot_layer.resized.connect(_on_slot_layer_resized)
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
	grl_font = load(GRL_FONT_PATH) as FontFile
	var court_tex: Variant = load(COURT_TEXTURE_PATH)
	if court_tex is Texture2D:
		court_rect.texture = court_tex
	court_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	formation_select.clear()
	for key in FORMATIONS.keys():
		formation_select.add_item(key)
	formation_select.select(0)

func _refresh() -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	lineup_cards = (uft.state.get("lineup", {}) as Dictionary).duplicate(true)
	for pos in POSITIONS:
		if not lineup_cards.has(pos):
			lineup_cards[pos] = ""
	_build_collection(uft)
	_rebuild_slot_nodes()
	_refresh_slot_visuals()
	_refresh_squad_meta(uft)

func _build_collection(uft: Node) -> void:
	for child in collection_grid.get_children():
		child.queue_free()
	collection_card_ids.clear()
	card_cache.clear()
	for card in uft.get_collection_cards():
		var card_id := str(card.get("card_id", ""))
		card_cache[card_id] = card
		collection_card_ids.append(card_id)
		collection_grid.add_child(_create_collection_card_widget(card_id, card))

func _create_collection_card_widget(card_id: String, card: Dictionary) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(90, 122)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	holder.add_child(vb)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(88, 98)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(tex)
	var card_name := Label.new()
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_name.add_theme_font_size_override("font_size", 12)
	var player := card.get("player", {}) as Dictionary
	var ovr := int(card.get("ovr", 0))
	card_name.text = "%s %d" % [str(player.get("main_position", "")), ovr]
	vb.add_child(card_name)
	_add_grl_badge(holder, ovr)
	holder.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_drag_from_collection(card_id, tex.texture)
		if event is InputEventScreenTouch and event.pressed:
			_start_drag_from_collection(card_id, tex.texture)
	)
	var image_url := str(card.get("card_frame_url", ""))
	if image_url.is_empty():
		image_url = str(card.get("face_url", ""))
	if image_url.is_empty():
		var p: Dictionary = card.get("player", {})
		image_url = str(p.get("photo_face_url", ""))
	if image_url.is_empty():
		_assign_empty_texture(tex)
	else:
		_load_remote_texture_into(tex, image_url)
	return holder

func _rebuild_slot_nodes() -> void:
	for child in slot_layer.get_children():
		child.queue_free()
	slot_nodes.clear()
	var formation: Dictionary = FORMATIONS.get(current_formation, FORMATIONS["1-2-1"])
	for pos in POSITIONS:
		var marker := TextureRect.new()
		marker.size = Vector2(92, 128)
		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker.mouse_filter = Control.MOUSE_FILTER_STOP
		var p: Vector2 = formation.get(pos, Vector2(0.5, 0.5))
		marker.position = Vector2(slot_layer.size.x * p.x - marker.size.x * 0.5, slot_layer.size.y * p.y - marker.size.y * 0.5)
		marker.gui_input.connect(_on_slot_gui_input.bind(pos))
		slot_layer.add_child(marker)
		var lbl := Label.new()
		lbl.text = pos
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.anchors_preset = Control.PRESET_FULL_RECT
		marker.add_child(lbl)
		var badge_root := Control.new()
		badge_root.name = "BadgeRoot"
		badge_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_root.anchors_preset = Control.PRESET_TOP_RIGHT
		badge_root.anchor_left = 1.0
		badge_root.anchor_right = 1.0
		badge_root.anchor_top = 0.0
		badge_root.anchor_bottom = 0.0
		badge_root.offset_left = -46
		badge_root.offset_top = 4
		badge_root.offset_right = -2
		badge_root.offset_bottom = 48
		marker.add_child(badge_root)
		var badge_tex := TextureRect.new()
		badge_tex.name = "Badge"
		badge_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge_tex.anchors_preset = Control.PRESET_FULL_RECT
		badge_root.add_child(badge_tex)
		var badge_label := Label.new()
		badge_label.name = "BadgeLabel"
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_label.anchors_preset = Control.PRESET_FULL_RECT
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_color_override("font_color", Color.WHITE)
		badge_label.add_theme_font_size_override("font_size", 14)
		if grl_font != null:
			badge_label.add_theme_font_override("font", grl_font)
		badge_root.add_child(badge_label)
		slot_nodes[pos] = marker

func _refresh_slot_visuals() -> void:
	for pos in POSITIONS:
		var slot: TextureRect = slot_nodes.get(pos, null)
		if slot == null:
			continue
		var card_id := str(lineup_cards.get(pos, ""))
		if card_id.is_empty():
			_assign_empty_texture(slot)
			_set_slot_badge(slot, 0, false)
		else:
			_load_card_slot_texture(slot, card_id)
			var details := card_cache.get(card_id, {}) as Dictionary
			if details.is_empty():
				var uft := get_node_or_null("/root/UFTManager")
				if uft != null:
					details = uft.get_card_details(card_id)
			_set_slot_badge(slot, int(details.get("ovr", 0)), true)
		slot.modulate = Color(1, 1, 1, 1) if pos == selected_slot else Color(0.85, 0.85, 0.85, 1)

func _assign_empty_texture(slot: TextureRect) -> void:
	var empty_tex: Variant = load(EMPTY_SLOT_TEXTURE_PATH)
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
		var player: Dictionary = card.get("player", {})
		url = str(player.get("photo_face_url", ""))
	if url.is_empty():
		_assign_empty_texture(slot)
		return
	_load_remote_texture_into(slot, url)

func _load_remote_texture_into(slot: TextureRect, url: String) -> void:
	var tex: Texture2D = await _load_texture_with_cache_fallback(url)
	if tex == null:
		_assign_empty_texture(slot)
		return
	if not is_instance_valid(slot):
		return
	slot.texture = tex

func _load_texture_with_cache_fallback(url: String) -> Texture2D:
	var uft := get_node_or_null("/root/UFTManager")
	if uft != null and uft.has_method("cache_remote_image"):
		var cached_path: String = await uft.cache_remote_image(url, "squad_cards")
		if not cached_path.is_empty():
			var from_cache: Texture2D = _load_texture_from_path(cached_path)
			if from_cache != null:
				return from_cache
	return await _fetch_remote_texture(url)

func _load_texture_from_path(path: String) -> Texture2D:
	var image := Image.new()
	var err: int = image.load(path)
	if err != OK:
		var global_path: String = ProjectSettings.globalize_path(path)
		err = image.load(global_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

func _fetch_remote_texture(url: String) -> Texture2D:
	var http := HTTPRequest.new()
	add_child(http)
	var err: int = http.request(url)
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

func _on_slot_gui_input(event: InputEvent, pos: String) -> void:
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

func _start_drag(pos: String) -> void:
	var card_id := str(lineup_cards.get(pos, ""))
	if card_id.is_empty():
		return
	if not card_cache.has(card_id):
		return
	dragging = true
	drag_from_slot = pos
	drag_from_collection_card_id = ""
	if drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = TextureRect.new()
	drag_preview.size = Vector2(92, 128)
	drag_preview.top_level = true
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.z_index = 99
	var origin: TextureRect = slot_nodes.get(pos, null)
	if origin != null:
		drag_preview.texture = origin.texture
	add_child(drag_preview)
	drag_preview.global_position = get_global_mouse_position() - drag_preview.size * 0.5

func _start_drag_from_collection(card_id: String, source_texture: Texture2D) -> void:
	if card_id.is_empty():
		return
	dragging = true
	drag_from_slot = ""
	drag_from_collection_card_id = card_id
	if drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = TextureRect.new()
	drag_preview.size = Vector2(92, 128)
	drag_preview.top_level = true
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.z_index = 99
	drag_preview.texture = source_texture
	add_child(drag_preview)
	drag_preview.global_position = get_global_mouse_position() - drag_preview.size * 0.5

func _finish_drag(target_pos: String) -> void:
	if not dragging:
		return
	var resolved_target := target_pos
	if resolved_target.is_empty():
		resolved_target = _find_slot_under_mouse()
	if not resolved_target.is_empty():
		if not drag_from_collection_card_id.is_empty():
			_assign_collection_card_to_slot(drag_from_collection_card_id, resolved_target)
		elif resolved_target != drag_from_slot:
			_swap_slots(drag_from_slot, resolved_target)
	dragging = false
	drag_from_slot = ""
	drag_from_collection_card_id = ""
	if drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null

func _find_slot_under_mouse() -> String:
	var mouse := get_global_mouse_position()
	for pos in POSITIONS:
		var slot: TextureRect = slot_nodes.get(pos, null)
		if slot == null:
			continue
		if slot.get_global_rect().has_point(mouse):
			return pos
	return ""

func _select_grl_badge_texture_path(ovr: int) -> String:
	if ovr >= 100:
		return str(GRL_BADGE_TEXTURES.get("elite", ""))
	if ovr >= 90:
		return str(GRL_BADGE_TEXTURES.get("high", ""))
	if ovr >= 80:
		return str(GRL_BADGE_TEXTURES.get("mid", ""))
	return str(GRL_BADGE_TEXTURES.get("low", ""))

func _add_grl_badge(parent: Control, ovr: int) -> void:
	var badge := TextureRect.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(34, 40)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.anchors_preset = Control.PRESET_TOP_RIGHT
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -34
	badge.offset_right = 0
	badge.offset_top = 2
	badge.offset_bottom = 42
	parent.add_child(badge)
	var badge_label := Label.new()
	badge_label.name = "BadgeLabel"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.anchors_preset = Control.PRESET_FULL_RECT
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.add_theme_font_size_override("font_size", 12)
	if grl_font != null:
		badge_label.add_theme_font_override("font", grl_font)
	badge.add_child(badge_label)
	_set_badge_visuals(badge, badge_label, ovr, true)

func _set_slot_badge(slot: TextureRect, ovr: int, visible: bool) -> void:
	var badge_root := slot.get_node_or_null("BadgeRoot") as Control
	if badge_root == null:
		return
	var badge := badge_root.get_node_or_null("Badge") as TextureRect
	var badge_label := badge_root.get_node_or_null("BadgeLabel") as Label
	if badge == null or badge_label == null:
		return
	_set_badge_visuals(badge, badge_label, ovr, visible)

func _set_badge_visuals(badge: TextureRect, badge_label: Label, ovr: int, visible: bool) -> void:
	if not visible:
		badge.visible = false
		return
	badge.visible = true
	badge.texture = load(_select_grl_badge_texture_path(ovr)) as Texture2D
	badge_label.text = str(ovr)

func _swap_slots(from_pos: String, to_pos: String) -> void:
	var from_id := str(lineup_cards.get(from_pos, ""))
	var to_id := str(lineup_cards.get(to_pos, ""))
	var simulated := lineup_cards.duplicate(true)
	simulated[from_pos] = to_id
	simulated[to_pos] = from_id
	if not _has_unique_players(simulated):
		status_label.text = "No se permite repetir al mismo jugador en la alineación."
		return
	lineup_cards = simulated
	_commit_lineup()
	_refresh_slot_visuals()
	_refresh_squad_meta(get_node_or_null("/root/UFTManager"))

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

func _assign_collection_card_to_slot(card_id: String, slot_pos: String) -> void:
	var simulated := lineup_cards.duplicate(true)
	simulated[slot_pos] = card_id
	if not _has_unique_players(simulated):
		status_label.text = "No puedes usar dos cartas del mismo jugador en el quinteto."
		return
	lineup_cards = simulated
	_commit_lineup()
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
	_commit_lineup()
	_refresh_slot_visuals()
	_refresh_squad_meta(get_node_or_null("/root/UFTManager"))

func _on_formation_selected(index: int) -> void:
	current_formation = formation_select.get_item_text(index)
	_rebuild_slot_nodes()
	_refresh_slot_visuals()

func _on_slot_layer_resized() -> void:
	_rebuild_slot_nodes()
	_refresh_slot_visuals()

func _commit_lineup() -> void:
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
