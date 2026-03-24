extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu2D.tscn"
const CHANGELOG_PATH := "res://CHANGELOG.md"

@onready var build_label: Label = $Margin/VBox/BuildLabel
@onready var body: RichTextLabel = $Margin/VBox/Body

func _ready() -> void:
	$Margin/VBox/BackButton.pressed.connect(_on_back_pressed)
	build_label.text = "Versión actual: %s" % MatchConfig.get_build_label()
	body.text = _load_changelog_text()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _load_changelog_text() -> String:
	var file := FileAccess.open(CHANGELOG_PATH, FileAccess.READ)
	if file == null:
		return "No se pudo cargar CHANGELOG.md"
	return file.get_as_text()
