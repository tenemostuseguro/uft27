extends Control

@onready var controls_label: Label = %ControlsLabel
@onready var traits_label: Label = %TraitsLabel

func setup(summary: Dictionary) -> void:
  var actions: Array = summary["controls"]["actions"]
  controls_label.text = "Acciones: %s" % ", ".join(actions)

  var trait_names: Array = []
  for trait in summary["traits"]:
    trait_names.append(trait["name"])
  traits_label.text = "Traits: %s" % ", ".join(trait_names)
