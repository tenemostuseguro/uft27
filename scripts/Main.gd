extends Control

const PrototypeData := preload("res://scripts/data/PrototypeData.gd")

@onready var energy_label: Label = %EnergyLabel
@onready var tokens_label: Label = %TokensLabel
@onready var stars_label: Label = %StarsLabel
@onready var log_label: Label = %LogLabel
@onready var home_view: Control = $HUD/ViewContainer/ViewStack/HomeView
@onready var event_view: Control = $HUD/ViewContainer/ViewStack/EventView
@onready var market_view: Control = $HUD/ViewContainer/ViewStack/MarketView
@onready var match_view: Control = $HUD/ViewContainer/ViewStack/MatchView

var energy := 20
var tokens := 0
var stars := 0
var event_path := []
var next_node_index := 0

func _ready() -> void:
  event_path = PrototypeData.build_event_path()
  _setup_views()
  _update_labels()
  _log("Evento listo. Usa las acciones para simular el loop.")

func _setup_views() -> void:
  var match_summary = PrototypeData.get_match_summary()
  var event_summary = PrototypeData.get_event_summary()
  var market_summary = PrototypeData.get_market_summary()
  home_view.call("setup", match_summary)
  event_view.call("setup", event_summary)
  market_view.call("setup", market_summary)
  match_view.call("setup", match_summary)

func _show_view(target: Control) -> void:
  for child in $HUD/ViewContainer/ViewStack.get_children():
    child.visible = child == target

func _update_labels() -> void:
  energy_label.text = "Energia: %d" % energy
  tokens_label.text = "Tokens: %d" % tokens
  stars_label.text = "Estrellas: %d" % stars

func _log(message: String) -> void:
  log_label.text = message

func _can_play_activity(cost: int) -> bool:
  return energy >= cost

func _apply_activity(reward_index: int, activity_index: int) -> void:
  var activity = PrototypeData.EVENT_ACTIVITIES[activity_index]
  var reward = activity["rewards"][reward_index]
  energy -= activity["energy_cost"]
  tokens += reward["tokens"]
  stars += reward["stars"]
  _update_labels()
  _log("Completaste %s: +%d T, +%d estrellas." % [activity["name"], reward["tokens"], reward["stars"]])

func _on_skill_game_pressed() -> void:
  if not _can_play_activity(PrototypeData.EVENT_ENERGY["skill_game_cost"]):
    _log("No tienes energia suficiente para un skill game.")
    return
  _apply_activity(1, 0)

func _on_mini_match_pressed() -> void:
  if not _can_play_activity(PrototypeData.EVENT_ENERGY["mini_match_cost"]):
    _log("No tienes energia suficiente para un mini partido.")
    return
  _apply_activity(2, 5)

func _on_advance_path_pressed() -> void:
  if next_node_index >= event_path.size():
    _log("Ya completaste el path del evento.")
    return
  var node = event_path[next_node_index]
  var cost: int = node["stars_cost"]
  if stars < cost:
    _log("Necesitas %d estrellas para avanzar." % cost)
    return
  stars -= cost
  next_node_index += 1
  _update_labels()
  _log("Avanzaste al nodo %d: %s" % [node["id"], node["reward"]])

func _on_buy_store_item_pressed() -> void:
  var item = PrototypeData.EVENT_STORE[0]
  var cost: int = item["token_cost"]
  if tokens < cost:
    _log("No tienes tokens suficientes para %s." % item["name"])
    return
  tokens -= cost
  _update_labels()
  _log("Compraste %s por %d T." % [item["name"], cost])

func _on_market_sell_pressed() -> void:
  var price := 20000
  var fee := PrototypeData.calculate_market_fee(price)
  tokens += price - fee
  _update_labels()
  _log("Venta simulada: precio %d, comision %d, neto %d." % [price, fee, price - fee])

func _on_recharge_pressed() -> void:
  energy = PrototypeData.regenerate_energy(energy, 40)
  _update_labels()
  _log("Se recargo energia (40 min simulados).")

func _on_home_pressed() -> void:
  _show_view(home_view)
  _log("Vista Home.")

func _on_event_pressed() -> void:
  _show_view(event_view)
  _log("Vista Evento.")

func _on_market_pressed() -> void:
  _show_view(market_view)
  _log("Vista Mercado.")

func _on_match_pressed() -> void:
  _show_view(match_view)
  _log("Vista Match.")
