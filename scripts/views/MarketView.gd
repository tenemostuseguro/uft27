extends Control

@onready var tradeables_label: Label = %TradeablesLabel
@onready var rules_label: Label = %RulesLabel

func setup(summary: Dictionary) -> void:
  tradeables_label.text = "Tradeables: %s" % ", ".join(summary["tradeables"])
  var rules = summary["rules"]
  rules_label.text = "Fee %d%% | Listings %d | Cooldown %ds" % [
    int(rules["fee_rate"] * 100),
    rules["daily_listing_limit"],
    rules["repeat_buy_cooldown_seconds"],
  ]
