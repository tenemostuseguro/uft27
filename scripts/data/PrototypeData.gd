extends Node

const MATCH_CONFIGS := [
  {
    "mode": "offline-ai",
    "periods": 2,
    "period_seconds": 120,
    "target_shots_range": Vector2i(6, 12),
  },
  {
    "mode": "pvp-ranked",
    "periods": 2,
    "period_seconds": 150,
    "target_shots_range": Vector2i(6, 12),
  },
]

const CONTROL_SCHEME := {
  "movement": "Joystick virtual izquierdo",
  "actions": [
    "Pase (tap)",
    "Tiro (mantener potencia + direccion o swipe)",
    "Sprint (boton o doble toque joystick)",
    "Regate/Skill (swipe direccional corto)",
    "Pared (doble tap en pase o boton 1-2 contextual)",
  ],
  "defense": [
    "Contener (mantener)",
    "Entrada (tap, riesgo de falta)",
    "Cambio jugador (tap jugador o boton)",
  ],
}

const TRAITS := [
  {
    "id": "pared-maestro",
    "name": "Pared Maestro",
    "description": "Mejor timing y velocidad en paredes.",
  },
  {
    "id": "puntera",
    "name": "Puntera",
    "description": "Tiro rapido con ejecucion mas veloz.",
  },
  {
    "id": "cierre-tactico",
    "name": "Cierre Tactico",
    "description": "Mejor intercepcion y lectura defensiva.",
  },
  {
    "id": "primer-toque",
    "name": "Primer Toque",
    "description": "Control orientado mejorado.",
  },
  {
    "id": "portero-libero",
    "name": "Portero Libero",
    "description": "Mejor juego con los pies y salidas.",
  },
]

const SAMPLE_CARDS := [
  {
    "id": "event-ala-86",
    "name": "Ala Evento 86",
    "role": "ala-izq",
    "rarity": "epica",
    "ovr": 86,
    "base_stats": {
      "control": 84,
      "pase": 83,
      "regate": 86,
      "tiro": 82,
      "defensa": 62,
      "velocidad": 88,
      "fisico": 75,
    },
    "traits": ["puntera", "primer-toque"],
    "tradeable": true,
  },
  {
    "id": "event-pivot-90",
    "name": "Pivot Evento 90",
    "role": "pivot",
    "rarity": "legendaria",
    "ovr": 90,
    "base_stats": {
      "control": 88,
      "pase": 86,
      "regate": 84,
      "tiro": 90,
      "defensa": 70,
      "velocidad": 82,
      "fisico": 89,
    },
    "traits": ["pared-maestro", "puntera"],
    "tradeable": false,
  },
]

const EVENT_ACTIVITIES := [
  {
    "id": "a1",
    "name": "Paredes Express",
    "kind": "skill-game",
    "energy_cost": 2,
    "duration_seconds": Vector2i(30, 60),
    "rewards": [
      {"stars": 1, "tokens": 6},
      {"stars": 2, "tokens": 9},
      {"stars": 3, "tokens": 12},
    ],
    "objective": "Completa 5 paredes sin perder el balon.",
  },
  {
    "id": "a2",
    "name": "Puntera a Dianas",
    "kind": "skill-game",
    "energy_cost": 2,
    "duration_seconds": Vector2i(30, 60),
    "rewards": [
      {"stars": 1, "tokens": 6},
      {"stars": 2, "tokens": 9},
      {"stars": 3, "tokens": 12},
    ],
    "objective": "3 tiros a zonas marcadas.",
  },
  {
    "id": "a3",
    "name": "Rondo 3v1",
    "kind": "skill-game",
    "energy_cost": 2,
    "duration_seconds": Vector2i(30, 60),
    "rewards": [
      {"stars": 1, "tokens": 6},
      {"stars": 2, "tokens": 9},
      {"stars": 3, "tokens": 12},
    ],
    "objective": "8 pases seguidos.",
  },
  {
    "id": "a4",
    "name": "Salida de Presion",
    "kind": "skill-game",
    "energy_cost": 2,
    "duration_seconds": Vector2i(30, 60),
    "rewards": [
      {"stars": 1, "tokens": 6},
      {"stars": 2, "tokens": 9},
      {"stars": 3, "tokens": 12},
    ],
    "objective": "2 pases + giro + pase final a zona.",
  },
  {
    "id": "a5",
    "name": "Robo y Contra",
    "kind": "skill-game",
    "energy_cost": 2,
    "duration_seconds": Vector2i(30, 60),
    "rewards": [
      {"stars": 1, "tokens": 6},
      {"stars": 2, "tokens": 9},
      {"stars": 3, "tokens": 12},
    ],
    "objective": "Intercepta 1 pase y marca en 10s.",
  },
  {
    "id": "b1",
    "name": "Remontada",
    "kind": "mini-match",
    "energy_cost": 3,
    "duration_seconds": Vector2i(90, 120),
    "rewards": [
      {"stars": 1, "tokens": 12},
      {"stars": 2, "tokens": 16},
      {"stars": 3, "tokens": 20},
    ],
    "objective": "Empiezas 0-1, quedan 90s.",
  },
  {
    "id": "b2",
    "name": "Gol Rapido",
    "kind": "mini-match",
    "energy_cost": 3,
    "duration_seconds": Vector2i(75, 120),
    "rewards": [
      {"stars": 1, "tokens": 12},
      {"stars": 2, "tokens": 16},
      {"stars": 3, "tokens": 20},
    ],
    "objective": "Marca 2 goles en 75s.",
  },
  {
    "id": "b3",
    "name": "Posesion",
    "kind": "mini-match",
    "energy_cost": 3,
    "duration_seconds": Vector2i(90, 120),
    "rewards": [
      {"stars": 1, "tokens": 12},
      {"stars": 2, "tokens": 16},
      {"stars": 3, "tokens": 20},
    ],
    "objective": "Gana con 60% posesion.",
  },
  {
    "id": "b4",
    "name": "Sin faltas",
    "kind": "mini-match",
    "energy_cost": 3,
    "duration_seconds": Vector2i(90, 120),
    "rewards": [
      {"stars": 1, "tokens": 12},
      {"stars": 2, "tokens": 16},
      {"stars": 3, "tokens": 20},
    ],
    "objective": "Gana sin cometer faltas.",
  },
]

const EVENT_MISSIONS := [
  {
    "id": "daily-activities",
    "name": "Completa 3 actividades del evento",
    "cadence": "daily",
    "requirement": "Completar 3 actividades del evento.",
    "reward_tokens": 30,
  },
  {
    "id": "daily-stars",
    "name": "Consigue 6 estrellas",
    "cadence": "daily",
    "requirement": "Obtener 6 estrellas en el evento.",
    "reward_tokens": 25,
  },
  {
    "id": "daily-goals",
    "name": "Marca 5 goles",
    "cadence": "daily",
    "requirement": "Marca 5 goles en cualquier modo.",
    "reward_tokens": 20,
  },
  {
    "id": "weekly-stars",
    "name": "Consigue 40 estrellas",
    "cadence": "weekly",
    "requirement": "Obtener 40 estrellas en el evento.",
    "reward_tokens": 200,
  },
  {
    "id": "weekly-wins",
    "name": "Gana 15 partidos",
    "cadence": "weekly",
    "requirement": "Ganar 15 partidos en cualquier modo.",
    "reward_tokens": 150,
  },
  {
    "id": "weekly-activities",
    "name": "Completa 25 actividades",
    "cadence": "weekly",
    "requirement": "Completar 25 actividades del evento.",
    "reward_tokens": 200,
  },
]

const EVENT_STORE := [
  {
    "id": "store-top-player",
    "name": "Jugador top 90 OVR",
    "token_cost": 4000,
    "tradeable": false,
    "category": "jugador",
  },
  {
    "id": "store-player-86-a",
    "name": "Jugador 86 OVR A",
    "token_cost": 1200,
    "tradeable": true,
    "category": "jugador",
  },
  {
    "id": "store-player-86-b",
    "name": "Jugador 86 OVR B",
    "token_cost": 1200,
    "tradeable": true,
    "category": "jugador",
  },
  {
    "id": "store-material-raro",
    "name": "Material raro",
    "token_cost": 150,
    "tradeable": true,
    "category": "material",
  },
  {
    "id": "store-xp-pack",
    "name": "XP pack",
    "token_cost": 80,
    "tradeable": false,
    "category": "xp",
  },
  {
    "id": "store-cosmetic",
    "name": "Cosmetico (balon o pista)",
    "token_cost": 300,
    "tradeable": false,
    "category": "cosmetico",
  },
]

const MARKET_RULES := {
  "fee_rate": 0.07,
  "daily_listing_limit": 20,
  "repeat_buy_cooldown_seconds": 30,
  "price_bands": {
    "comun": Vector2i(200, 2000),
    "rara": Vector2i(2000, 20000),
    "epica": Vector2i(20000, 200000),
    "legendaria": Vector2i(200000, 2000000),
  },
}

const EVENT_ENERGY := {
  "max_energy": 20,
  "recharge_minutes": 20,
  "skill_game_cost": 2,
  "mini_match_cost": 3,
}

func get_match_summary() -> Dictionary:
  return {
    "configs": MATCH_CONFIGS,
    "controls": CONTROL_SCHEME,
    "traits": TRAITS,
    "sample_cards": SAMPLE_CARDS,
  }

func get_event_summary() -> Dictionary:
  return {
    "activities": EVENT_ACTIVITIES,
    "missions": EVENT_MISSIONS,
    "store": EVENT_STORE,
    "energy": EVENT_ENERGY,
  }

func get_market_summary() -> Dictionary:
  return {
    "rules": MARKET_RULES,
    "tradeables": [
      "Cartas de jugadores",
      "Materiales",
      "Consumibles",
    ],
    "non_tradeables": [
      "Cosmeticos",
      "Recompensa final del path",
    ],
  }

func build_event_path() -> Array:
  var nodes: Array = []
  for index in range(30):
    var id := index + 1
    if id == 30:
      nodes.append({
        "id": id,
        "stars_cost": 5,
        "reward": "Carta especial + cosmetico",
        "tier": "final",
      })
    elif id % 10 == 0:
      nodes.append({
        "id": id,
        "stars_cost": 4,
        "reward": "Pack o recompensa grande",
        "tier": "grande",
      })
    else:
      var stars_cost := 2 if id % 2 == 0 else 1
      nodes.append({
        "id": id,
        "stars_cost": stars_cost,
        "reward": "Monedas / XP / material / tokens",
        "tier": "normal",
      })
  return nodes

func calculate_market_fee(price: int) -> int:
  return int(round(price * MARKET_RULES["fee_rate"]))

func is_price_within_band(price: int, rarity: String) -> bool:
  var band: Vector2i = MARKET_RULES["price_bands"].get(rarity, Vector2i.ZERO)
  return price >= band.x and price <= band.y

func regenerate_energy(current: int, minutes_elapsed: int) -> int:
  if current >= EVENT_ENERGY["max_energy"]:
    return EVENT_ENERGY["max_energy"]
  var gained := minutes_elapsed / EVENT_ENERGY["recharge_minutes"]
  return min(EVENT_ENERGY["max_energy"], current + gained)
