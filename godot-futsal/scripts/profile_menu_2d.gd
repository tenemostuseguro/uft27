extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const CLUB_CREST_MENU_SCENE := "res://scenes/ClubCrestMenu2D.tscn"

@onready var photo_preview: TextureRect = $Margin/VBox/Row/PhotoPanel/PhotoVBox/PhotoPreview
@onready var photo_button: Button = $Margin/VBox/Row/PhotoPanel/PhotoVBox/PhotoButton
@onready var open_crest_button: Button = $Margin/VBox/Row/CrestPanel/CrestVBox/OpenCrestMenu
@onready var status_label: Label = $Margin/VBox/Status
@onready var photo_dialog: FileDialog = $PhotoDialog

func _ready() -> void:
	$Margin/VBox/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$Margin/VBox/Buttons/CrestButton.pressed.connect(func() -> void: get_tree().change_scene_to_file(CLUB_CREST_MENU_SCENE))
	open_crest_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(CLUB_CREST_MENU_SCENE))
	$Margin/VBox/Buttons/BackButton.pressed.connect(_on_back_pressed)
	photo_button.pressed.connect(func() -> void: photo_dialog.popup_centered_ratio(0.7))
	photo_dialog.file_selected.connect(_on_photo_selected)
	_load_photo(MatchConfig.profile_photo_path)

func _on_photo_selected(path: String) -> void:
	MatchConfig.set_profile_photo(path)
	_load_photo(path)

func _load_photo(path: String) -> void:
	if path.strip_edges().is_empty():
		photo_preview.texture = null
		return

	var texture := _load_photo_texture_from_resource(path)
	if texture != null:
		photo_preview.texture = texture
		return

	if path.begins_with("http://") or path.begins_with("https://"):
		_request_remote_photo(path)
		return

	photo_preview.texture = null

func _load_photo_texture_from_resource(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			return resource
	var image: Image = Image.load_from_file(path)
	if image != null:
		return ImageTexture.create_from_image(image)
	return null

func _request_remote_photo(url: String) -> void:
	var candidates := _build_remote_image_candidates(url)
	_request_remote_photo_candidate(candidates, 0)

func _request_remote_photo_candidate(candidates: Array[String], index: int) -> void:
	if index >= candidates.size():
		photo_preview.texture = null
		return
	var target_url := candidates[index]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_remote_photo_downloaded.bind(http, candidates, index))
	if http.request(target_url) != OK:
		http.queue_free()
		_request_remote_photo_candidate(candidates, index + 1)

func _on_remote_photo_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, candidates: Array[String], index: int) -> void:
	http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var texture := _texture_from_http_body(candidates[index], headers, body)
		if texture != null:
			photo_preview.texture = texture
			return
	_request_remote_photo_candidate(candidates, index + 1)

func _texture_from_http_body(url: String, headers: PackedStringArray, body: PackedByteArray) -> Texture2D:
	var mime_type := _extract_content_type(headers).to_lower()
	if mime_type.contains("gif") or url.to_lower().contains(".gif"):
		return null
	var image := Image.new()
	var err := image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		err = image.load_webp_from_buffer(body)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

func _extract_content_type(headers: PackedStringArray) -> String:
	for header in headers:
		var normalized := str(header).to_lower()
		if normalized.begins_with("content-type:"):
			return str(header).split(":", true, 1)[1].strip_edges()
	return ""

func _build_remote_image_candidates(url: String) -> Array[String]:
	var normalized := url.strip_edges()
	var candidates: Array[String] = []
	if normalized.is_empty():
		return candidates
	candidates.append(normalized)
	var lower := normalized.to_lower()
	var gif_pos := lower.find(".gif")
	if gif_pos != -1:
		var prefix := normalized.substr(0, gif_pos)
		var suffix := normalized.substr(gif_pos + 4)
		for ext in [".png", ".webp", ".jpg", ".jpeg"]:
			var alt := "%s%s%s" % [prefix, ext, suffix]
			if not candidates.has(alt):
				candidates.append(alt)
	return candidates

func _on_save_pressed() -> void:
	status_label.text = "Perfil guardado ✅"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
