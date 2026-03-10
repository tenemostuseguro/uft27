extends Control

@onready var activities_label: Label = %ActivitiesLabel
@onready var missions_label: Label = %MissionsLabel
@onready var store_label: Label = %StoreLabel
@onready var energy_label: Label = %EnergyConfigLabel

func setup(summary: Dictionary) -> void:
  var activities: Array = []
  for activity in summary["activities"]:
    activities.append("%s (%s)" % [activity["name"], activity["kind"]])
  activities_label.text = "Actividades: %s" % ", ".join(activities)

  var missions: Array = []
  for mission in summary["missions"]:
    missions.append(mission["name"])
  missions_label.text = "Misiones: %s" % ", ".join(missions)

  var store_items: Array = []
  for item in summary["store"]:
    store_items.append("%s (%d T)" % [item["name"], item["token_cost"]])
  store_label.text = "Tienda: %s" % ", ".join(store_items)

  var energy = summary["energy"]
  energy_label.text = "Energia: max %d, recarga %d min" % [energy["max_energy"], energy["recharge_minutes"]]
