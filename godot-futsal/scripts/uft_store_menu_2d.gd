extends Control

const UFT_MENU_SCENE := "res://scenes/UFTMenu2D.tscn"

@onready var store_list: VBoxContainer = $Margin/VBox/Scroll/StoreList
@onready var status_label: Label = $Margin/VBox/Status

var store_slots: Array[Dictionary] = []

func _ready() -> void:
	$Margin/VBox/Header/Back.pressed.connect(func() -> void: get_tree().change_scene_to_file(UFT_MENU_SCENE))
	_reload_store()
	set_process(true)

func _process(_delta: float) -> void:
	_update_time_labels()

func _reload_store() -> void:
	for child in store_list.get_children():
		child.queue_free()

	var auth := get_node_or_null("/root/AuthService")
	if auth == null:
		status_label.text = "AuthService no disponible"
		return
	var result: Dictionary = await auth.list_uft_store_slots()
	if not result.get("ok", false):
		status_label.text = "Error cargando tienda: %s" % str(result.get("error", "desconocido"))
		return
	var rows: Variant = result.get("json", [])
	if rows is not Array:
		status_label.text = "Respuesta inválida de tienda"
		return
	store_slots.clear()
	for item in rows:
		if item is Dictionary:
			store_slots.append(item)
			store_list.add_child(_build_store_slot_row(item))
	status_label.text = "Sobres en tienda: %d" % store_slots.size()

func _build_store_slot_row(slot: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 124)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	panel.add_child(hb)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(120, 100)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(image)

	var image_url := str(slot.get("image_url", ""))
	if not image_url.is_empty():
		_load_remote_texture_into(image, image_url)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = 3
	hb.add_child(info_vb)

	var name_label := Label.new()
	name_label.text = "%s (%s)" % [str(slot.get("pack_name", "Sobre")), str(slot.get("pack_id", ""))]
	name_label.add_theme_font_size_override("font_size", 18)
	info_vb.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "Costo: %d coins / %d points · Cartas: %d" % [
		int(slot.get("cost_coins", 0)),
		int(slot.get("cost_points", 0)),
		int(slot.get("cards_count", 1))
	]
	info_vb.add_child(cost_label)

	var timer_label := Label.new()
	timer_label.name = "TimerLabel"
	timer_label.set_meta("ends_at_unix", int(slot.get("ends_at_unix", 0)))
	info_vb.add_child(timer_label)

	var note := str(slot.get("manual_note", ""))
	if not note.is_empty():
		var note_label := Label.new()
		note_label.text = "Nota: %s" % note
		info_vb.add_child(note_label)

	var buy_btn := Button.new()
	buy_btn.text = "Comprar / Abrir"
	buy_btn.pressed.connect(_on_buy_pressed.bind(str(slot.get("pack_id", ""))))
	hb.add_child(buy_btn)

	_update_single_timer_label(timer_label)
	return panel

func _update_time_labels() -> void:
	for row in store_list.get_children():
		var panel := row as PanelContainer
		if panel == null:
			continue
		var hb := panel.get_child(0) as HBoxContainer
		if hb == null or hb.get_child_count() < 2:
			continue
		var info := hb.get_child(1) as VBoxContainer
		if info == null:
			continue
		var timer := info.get_node_or_null("TimerLabel") as Label
		if timer != null:
			_update_single_timer_label(timer)

func _update_single_timer_label(timer_label: Label) -> void:
	var ends_at := int(timer_label.get_meta("ends_at_unix", 0))
	var now := int(Time.get_unix_time_from_system())
	var remain: int = int(max(0, ends_at - now))
	var h: int = int(remain / 3600)
	var m: int = int((remain % 3600) / 60)
	var s: int = int(remain % 60)
	timer_label.text = "Tiempo restante: %02d:%02d:%02d" % [h, m, s]

func _on_buy_pressed(pack_id: String) -> void:
	var uft := get_node_or_null("/root/UFTManager")
	if uft == null:
		status_label.text = "UFTManager no disponible"
		return
	var result: Dictionary = uft.open_pack(pack_id)
	if result.get("ok", false):
		var won_cards: Variant = result.get("won_cards", [])
		status_label.text = "Sobre abierto (%s): %s" % [pack_id, str(won_cards)]
	else:
		status_label.text = "Error abriendo sobre: %s" % str(result.get("error", "desconocido"))

func _load_remote_texture_into(node: TextureRect, url: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return
	var body: PackedByteArray = result[3]
	if body.is_empty():
		return
	var image := Image.new()
	if image.load_png_from_buffer(body) != OK and image.load_jpg_from_buffer(body) != OK and image.load_webp_from_buffer(body) != OK:
		return
	node.texture = ImageTexture.create_from_image(image)
