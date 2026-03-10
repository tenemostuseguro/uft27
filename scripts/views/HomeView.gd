extends Control

@onready var description_label: Label = %DescriptionLabel

func setup(summary: Dictionary) -> void:
  var modes: Array = []
  for config in summary["configs"]:
    modes.append("%s: %dx%d" % [config["mode"], config["periods"], config["period_seconds"]])
  description_label.text = "Modos: %s" % ", ".join(modes)
