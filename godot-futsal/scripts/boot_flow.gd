extends Control

const LOGIN_SCENE := "res://scenes/LoginMenu2D.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const INTRO_VIDEO_PATH := "res://assets/intro.mp4"
const LOADING_IMAGE_PATH := "res://assets/loading.png"

@export var minimum_loading_seconds := 2.6
@export var loading_steps := 30

@onready var intro_video: VideoStreamPlayer = $IntroLayer/IntroVideo
@onready var skip_label: Label = $IntroLayer/SkipLabel
@onready var loading_layer: Control = $LoadingLayer
@onready var loading_texture: TextureRect = $LoadingLayer/LoadingTexture
@onready var loading_status_label: Label = $LoadingLayer/LoadingStatus
@onready var progress_bar: ProgressBar = $LoadingLayer/ProgressBar

var _intro_active := false
var _loading_started := false

func _ready() -> void:
	loading_layer.visible = false
	progress_bar.value = 0.0
	_loading_status_label_default()
	_setup_loading_texture()
	_start_intro_or_loading()

func _unhandled_input(event: InputEvent) -> void:
	if not _intro_active:
		return
	if event is InputEventMouseButton and event.pressed:
		_start_loading_sequence()
	elif event is InputEventScreenTouch and event.pressed:
		_start_loading_sequence()
	elif event.is_action_pressed("ui_accept"):
		_start_loading_sequence()

func _start_intro_or_loading() -> void:
	if ResourceLoader.exists(INTRO_VIDEO_PATH):
		var intro_stream: Resource = load(INTRO_VIDEO_PATH)
		if intro_stream != null:
			intro_video.stream = intro_stream
			intro_video.finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
			intro_video.play()
			_intro_active = true
			skip_label.text = "Tocá la pantalla, hacé click o presioná aceptar para saltar"
			return
	_start_loading_sequence()

func _on_intro_finished() -> void:
	_start_loading_sequence()

func _start_loading_sequence() -> void:
	if _loading_started:
		return
	_loading_started = true
	_intro_active = false
	if intro_video.is_playing():
		intro_video.stop()
	$IntroLayer.visible = false
	loading_layer.visible = true
	await _run_loading_animation()
	get_tree().change_scene_to_file(_resolve_next_scene())

func _run_loading_animation() -> void:
	var target_scene := _resolve_next_scene()
	var per_step: float = minimum_loading_seconds / float(max(1, loading_steps))
	for step in range(loading_steps + 1):
		var ratio := float(step) / float(max(1, loading_steps))
		progress_bar.value = ratio * 100.0
		loading_status_label.text = "Cargando %s... %d%%" % [_scene_label(target_scene), int(progress_bar.value)]
		if step < loading_steps:
			await get_tree().create_timer(per_step).timeout

func _resolve_next_scene() -> String:
	var auth := get_node_or_null("/root/AuthService")
	if auth != null and auth.is_authenticated():
		return MAIN_MENU_SCENE
	return LOGIN_SCENE

func _scene_label(path: String) -> String:
	if path == MAIN_MENU_SCENE:
		return "menú principal"
	return "inicio de sesión"

func _setup_loading_texture() -> void:
	if ResourceLoader.exists(LOADING_IMAGE_PATH):
		var texture: Resource = load(LOADING_IMAGE_PATH)
		if texture is Texture2D:
			loading_texture.texture = texture
			return
	loading_texture.texture = null

func _loading_status_label_default() -> void:
	loading_status_label.text = "Preparando recursos..."
