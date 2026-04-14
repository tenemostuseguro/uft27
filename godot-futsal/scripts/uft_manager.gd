extends Node

const CACHE_ROOT := "user://cache/images"
const STARTER_POSITIONS: Array[String] = ["POR", "C", "AI", "AD", "P"]

const MODE_SQUAD_BATTLE := "uft_squad_battle"
const MODE_CHAMPIONS := "uft_champions"

var godot_major := 4
var base_players: Dictionary = {}
var cards: Dictionary = {}
var packs: Dictionary = {}
var events: Array[Dictionary] = []
var market_listings: Array[Dictionary] = []
var season_config: Dictionary = {}

var state: Dictionary = {
	"club_name": "Mi Club UFT",
	"coins": 10000,
	"points": 200,
	"xp": 0,
	"season_xp": 0,
	"battle_pass_claimed": [],
	"collection": [],
	"transfer_list": [],
	"lineup": {"POR":"","C":"","AI":"","AD":"","P":""},
	"bench": [],
	"champions_division": 10,
	"champions_points": 0,
	"squad_battle_rank": 0,
	"event_progress": {}
}

func _ready() -> void:
	godot_major = int(Engine.get_version_info().get("major", 4))
	await _load_static_data()
	await _load_state()
	_ensure_starter_cards()
	_save_state()

func is_godot4() -> bool:
	return godot_major >= 4

func _load_static_data() -> void:
	var auth := get_node_or_null("/root/AuthService")
	if auth == null:
		push_warning("UFTManager: AuthService no disponible, no se pueden cargar catálogos desde Supabase.")
		return
	var players_result: Dictionary = await auth.list_uft_players()
	if players_result.get("ok", false):
		base_players = _array_to_dict(_as_dict_array(players_result.get("json", [])), "player_id")
	else:
		push_warning("UFTManager: error cargando uft_players: %s" % str(players_result.get("error", "desconocido")))

	var cards_result: Dictionary = await auth.list_uft_cards()
	if cards_result.get("ok", false):
		cards = _array_to_dict(_as_dict_array(cards_result.get("json", [])), "card_id")
	else:
		push_warning("UFTManager: error cargando uft_cards_catalog: %s" % str(cards_result.get("error", "desconocido")))

	var packs_result: Dictionary = await auth.list_uft_packs()
	if packs_result.get("ok", false):
		packs = _array_to_dict(_as_dict_array(packs_result.get("json", [])), "pack_id")
	else:
		push_warning("UFTManager: error cargando uft_packs_catalog: %s" % str(packs_result.get("error", "desconocido")))

	var events_result: Dictionary = await auth.list_uft_events()
	if events_result.get("ok", false):
		events = _as_dict_array(events_result.get("json", []))
	else:
		push_warning("UFTManager: error cargando uft_events_catalog: %s" % str(events_result.get("error", "desconocido")))

	var market_result: Dictionary = await auth.list_uft_market_listings()
	if market_result.get("ok", false):
		market_listings = _as_dict_array(market_result.get("json", []))
	else:
		push_warning("UFTManager: error cargando uft_market_catalog: %s" % str(market_result.get("error", "desconocido")))

	var seasons_result: Dictionary = await auth.list_uft_seasons()
	if seasons_result.get("ok", false):
		var seasons_rows := _as_dict_array(seasons_result.get("json", []))
		if seasons_rows.size() > 0:
			season_config = seasons_rows[0]
	else:
		push_warning("UFTManager: error cargando uft_seasons_catalog: %s" % str(seasons_result.get("error", "desconocido")))

	if base_players.is_empty() or cards.is_empty():
		push_warning("UFTManager: catálogos UFT incompletos desde Supabase (players/cards).")

func _load_state() -> void:
	var auth := get_node_or_null("/root/AuthService")
	if auth == null or not auth.is_authenticated():
		push_warning("UFTManager: sesión no autenticada, no se puede cargar snapshot UFT desde Supabase.")
		return
	var remote: Dictionary = await auth.get_uft_snapshot()
	if remote.get("ok", false):
		var snapshot: Variant = remote.get("snapshot", {})
		if snapshot is Dictionary:
			for key in state.keys():
				if snapshot.has(key):
					state[key] = snapshot[key]
	else:
		push_warning("UFTManager: error cargando snapshot UFT desde Supabase: %s" % str(remote.get("error", "desconocido")))

func _save_state() -> void:
	var auth := get_node_or_null("/root/AuthService")
	if auth == null or not auth.is_authenticated():
		push_warning("UFTManager: sesión no autenticada, no se puede guardar snapshot UFT en Supabase.")
		return
	auth.save_uft_snapshot(state)

func _ensure_starter_cards() -> void:
	if state["collection"].size() > 0:
		return
	var by_pos: Dictionary = {"POR": "", "C": "", "AI": "", "AD": "", "P": ""}
	for card_id in cards.keys():
		var card: Dictionary = cards[card_id]
		var player: Dictionary = base_players.get(str(card.get("player_id", "")), {})
		var pos := str(player.get("main_position", ""))
		if by_pos.has(pos) and str(by_pos[pos]).is_empty():
			by_pos[pos] = str(card_id)
	for pos in STARTER_POSITIONS:
		var selected := str(by_pos.get(pos, ""))
		if selected.is_empty():
			continue
		state["collection"].append(selected)
		state["lineup"][pos] = selected

func get_summary() -> Dictionary:
	return {
		"coins": state["coins"],
		"points": state["points"],
		"xp": state["xp"],
		"season_xp": state["season_xp"],
		"division": state["champions_division"],
		"champions_points": state["champions_points"],
		"club_name": state["club_name"]
	}

func get_collection_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card_id in state["collection"]:
		if cards.has(card_id):
			result.append(get_card_details(card_id))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("ovr", 0)) > int(b.get("ovr", 0)))
	return result

func get_card_details(card_id: String) -> Dictionary:
	if not cards.has(card_id):
		return {}
	var card: Dictionary = cards[card_id].duplicate(true)
	var player: Dictionary = base_players.get(str(card.get("player_id", "")), {})
	card["player"] = player
	card["main_stats"] = compute_main_stats(card)
	card["ovr"] = compute_card_ovr(card)
	return card

func compute_main_stats(card: Dictionary) -> Dictionary:
	var player: Dictionary = base_players.get(str(card.get("player_id", "")), {})
	var is_gk := str(player.get("main_position", "")) == "POR"
	if is_gk:
		var s: Dictionary = card.get("gk_substats", {})
		return {
			"reflejos": _avg([s.get("reaction", 0), s.get("reflejos_cortos", 0), s.get("rebotes", 0)]),
			"parada": _avg([s.get("paradas_cercanas", 0), s.get("blocaje", 0), s.get("desvio", 0), s.get("paradas_media", 0)]),
			"uno_vs_uno": _avg([s.get("achique", 0), s.get("timing_salida", 0), s.get("cobertura_corporal", 0), s.get("lectura_atacante", 0)]),
			"colocacion": _avg([s.get("posicionamiento", 0), s.get("lectura_jugada", 0), s.get("segundo_palo", 0), s.get("ajuste_lateral", 0)]),
			"juego_pies": _avg([s.get("pase_corto", 0), s.get("control", 0), s.get("pase_largo", 0), s.get("decision", 0)]),
			"fisico": _avg([s.get("explosividad", 0), s.get("agilidad", 0), s.get("resistencia", 0), s.get("elasticidad", 0)])
		}
	var f: Dictionary = card.get("field_substats", {})
	return {
		"ritmo": _avg([f.get("aceleracion_corta", 0), f.get("velocidad_punta", 0), f.get("cambio_ritmo", 0), f.get("agilidad_lateral", 0), f.get("recuperacion_sprint", 0)]),
		"regate": _avg([f.get("regate_corto", 0), f.get("conduccion_cerrada", 0), f.get("finta_tecnica", 0), f.get("giro_con_balon", 0), f.get("proteccion_balon", 0), f.get("salida_presion", 0)]),
		"pase": _avg([f.get("pase_corto", 0), f.get("pase_primertoque", 0), f.get("pase_rapido", 0), f.get("vision", 0), f.get("pase_filtrado", 0), f.get("pase_presion", 0)]),
		"tiro": _avg([f.get("definicion_corta", 0), f.get("potencia_tiro", 0), f.get("colocacion", 0), f.get("tiro_rapido", 0), f.get("puntera", 0), f.get("volea", 0), f.get("tiro_movimiento", 0)]),
		"defensa": _avg([f.get("marcaje", 0), f.get("anticipacion", 0), f.get("robo", 0), f.get("intercepcion", 0), f.get("cobertura", 0), f.get("presion_def", 0), f.get("temporizacion", 0)]),
		"fisico": _avg([f.get("resistencia", 0), f.get("explosividad", 0), f.get("equilibrio", 0), f.get("fuerza_choque", 0), f.get("resistencia_contacto", 0), f.get("recuperacion", 0)])
	}

func compute_card_ovr(card: Dictionary) -> int:
	var player: Dictionary = base_players.get(str(card.get("player_id", "")), {})
	var pos := str(player.get("main_position", ""))
	var m := compute_main_stats(card)
	if pos == "POR":
		return int(round(m["reflejos"] * 0.25 + m["parada"] * 0.20 + m["uno_vs_uno"] * 0.20 + m["colocacion"] * 0.15 + m["juego_pies"] * 0.10 + m["fisico"] * 0.10))
	var w := {"ritmo":0.20, "regate":0.20, "pase":0.15, "tiro":0.20, "defensa":0.15, "fisico":0.10}
	if pos == "C":
		w["defensa"] += 0.10
		w["pase"] += 0.05
		w["tiro"] -= 0.05
	elif pos == "AI" or pos == "AD":
		w["ritmo"] += 0.10
		w["regate"] += 0.10
		w["defensa"] -= 0.05
	elif pos == "P":
		w["tiro"] += 0.15
		w["fisico"] += 0.05
		w["ritmo"] -= 0.05
	var total := 0.0
	for key in w.keys():
		total += float(m.get(key, 0.0)) * float(w[key])
	return int(round(total))

func validate_lineup(lineup: Dictionary = {}) -> Dictionary:
	var target: Dictionary = lineup if not lineup.is_empty() else state["lineup"]
	for pos in STARTER_POSITIONS:
		if str(target.get(pos, "")).is_empty():
			return {"ok": false, "error": "Quinteto inválido: falta posición %s" % pos}
	if str(target.get("POR", "")).is_empty():
		return {"ok": false, "error": "Quinteto inválido: portero obligatorio"}
	var seen_players: Dictionary = {}
	for pos in STARTER_POSITIONS:
		var card_id := str(target.get(pos, ""))
		if not cards.has(card_id):
			return {"ok": false, "error": "Carta no encontrada en %s" % pos}
		var player_id := str(cards[card_id].get("player_id", ""))
		if seen_players.has(player_id):
			return {"ok": false, "error": "No se puede alinear dos cartas del mismo jugador (%s)." % player_id}
		seen_players[player_id] = true
	return {"ok": true}

func set_starter_card(position: String, card_id: String) -> Dictionary:
	var lineup: Dictionary = state["lineup"].duplicate(true)
	lineup[position] = card_id
	var valid := validate_lineup(lineup)
	if not valid.get("ok", false):
		return valid
	state["lineup"] = lineup
	_save_state()
	return {"ok": true}

func add_currency(coins: int, points: int = 0, xp: int = 0) -> void:
	state["coins"] += max(0, coins)
	state["points"] += max(0, points)
	state["xp"] += max(0, xp)
	state["season_xp"] += max(0, xp)
	_save_state()

func spend_currency(coins: int, points: int = 0) -> bool:
	if state["coins"] < coins or state["points"] < points:
		return false
	state["coins"] -= coins
	state["points"] -= points
	_save_state()
	return true

func open_pack(pack_id: String) -> Dictionary:
	if not packs.has(pack_id):
		return {"ok": false, "error": "Sobre no existe"}
	var pack: Dictionary = packs[pack_id]
	if not spend_currency(int(pack.get("cost_coins", 0)), int(pack.get("cost_points", 0))):
		return {"ok": false, "error": "Saldo insuficiente"}
	var won: Array[String] = []
	var pool: Array = pack.get("pool", [])
	var count := int(pack.get("cards_count", 1))
	for i in range(max(1, count)):
		if pool.is_empty():
			break
		var card_id := str(pool[randi() % pool.size()])
		if state["collection"].has(card_id) and str(pack.get("duplicate_policy", "allow")) == "coins":
			state["coins"] += int(200 + compute_card_ovr(cards[card_id]) * 10)
		else:
			state["collection"].append(card_id)
			won.append(card_id)
	_save_state()
	return {"ok": true, "won_cards": won}

func get_market_listings(filters: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw in market_listings:
		var listing: Dictionary = raw
		var card_id := str(listing.get("card_id", ""))
		if not cards.has(card_id):
			continue
		var card := get_card_details(card_id)
		if filters.has("min_ovr") and int(card.get("ovr", 0)) < int(filters["min_ovr"]):
			continue
		if filters.has("card_type") and str(filters["card_type"]) != "" and str(card.get("card_type", "")) != str(filters["card_type"]):
			continue
		var player: Dictionary = card.get("player", {})
		if filters.has("position") and str(filters["position"]) != "" and str(player.get("main_position", "")) != str(filters["position"]):
			continue
		listing["card"] = card
		result.append(listing)
	return result

func buy_market_listing(listing_id: String) -> Dictionary:
	for i in range(market_listings.size()):
		var listing: Dictionary = market_listings[i]
		if str(listing.get("listing_id", "")) != listing_id:
			continue
		var price := int(listing.get("price", 0))
		if not spend_currency(price, 0):
			return {"ok": false, "error": "Coins insuficientes"}
		var card_id := str(listing.get("card_id", ""))
		state["collection"].append(card_id)
		market_listings.remove_at(i)
		_save_state()
		return {"ok": true, "card_id": card_id}
	return {"ok": false, "error": "Oferta no encontrada"}

func list_card_on_market(card_id: String, price: int) -> Dictionary:
	if not state["collection"].has(card_id):
		return {"ok": false, "error": "No posees esa carta"}
	state["collection"].erase(card_id)
	var listing := {"listing_id":"u_%d" % Time.get_unix_time_from_system(), "card_id": card_id, "price": max(100, price), "seller": "user"}
	market_listings.append(listing)
	_save_state()
	return {"ok": true}

func get_active_events() -> Array[Dictionary]:
	var now := int(Time.get_unix_time_from_system())
	var active: Array[Dictionary] = []
	for e in events:
		if not bool(e.get("active", false)):
			continue
		if now < int(e.get("start_unix", 0)) or now > int(e.get("end_unix", 0)):
			continue
		active.append(e)
	return active

func start_mode(mode: String) -> void:
	MatchConfig.set_match_start(MatchConfig.MODE_VS_AI)
	MatchConfig.uft_mode = mode

func resolve_mode_result(mode: String, won: bool, draw: bool) -> Dictionary:
	var rewards := {"coins": 0, "points": 0, "xp": 0}
	if mode == MODE_SQUAD_BATTLE:
		rewards["coins"] = 1200 if won else (600 if draw else 300)
		rewards["xp"] = 80 if won else 40
		state["squad_battle_rank"] += 15 if won else 5
	elif mode == MODE_CHAMPIONS:
		rewards["coins"] = 1800 if won else (900 if draw else 450)
		rewards["xp"] = 120 if won else 60
		var delta := 3 if won else (1 if draw else -2)
		state["champions_points"] = max(0, int(state["champions_points"]) + delta)
		if state["champions_points"] >= 12:
			state["champions_points"] = 0
			state["champions_division"] = max(1, int(state["champions_division"]) - 1)
	add_currency(rewards["coins"], rewards["points"], rewards["xp"])
	_save_state()
	return rewards

func claim_battle_pass(level: int, premium: bool = false) -> Dictionary:
	var claimed: Array = state["battle_pass_claimed"]
	var key := "%d_%s" % [level, "p" if premium else "f"]
	if claimed.has(key):
		return {"ok": false, "error": "Recompensa ya reclamada"}
	for entry in season_config.get("levels", []):
		if int(entry.get("level", 0)) != level:
			continue
		if int(state["season_xp"]) < int(entry.get("xp_required", 0)):
			return {"ok": false, "error": "XP insuficiente"}
		var reward: Dictionary = entry.get("premium_reward" if premium else "free_reward", {})
		_apply_reward(reward)
		claimed.append(key)
		state["battle_pass_claimed"] = claimed
		_save_state()
		return {"ok": true, "reward": reward}
	return {"ok": false, "error": "Nivel no encontrado"}

func _apply_reward(reward: Dictionary) -> void:
	match str(reward.get("type", "")):
		"coins":
			state["coins"] += int(reward.get("amount", 0))
		"points":
			state["points"] += int(reward.get("amount", 0))
		"xp":
			state["xp"] += int(reward.get("amount", 0))
			state["season_xp"] += int(reward.get("amount", 0))
		"card":
			var card_id := str(reward.get("card_id", ""))
			if cards.has(card_id):
				state["collection"].append(card_id)

func get_cached_image_path(url: String, folder: String) -> String:
	var ext := _guess_extension(url)
	var id := str(url.hash())
	var path := "%s/%s/%s%s" % [CACHE_ROOT, folder, id, ext]
	_ensure_dir("%s/%s" % [CACHE_ROOT, folder])
	return path

func cache_remote_image(url: String, folder: String) -> String:
	var cache_path := get_cached_image_path(url, folder)
	if FileAccess.file_exists(cache_path):
		return cache_path
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return ""
	var completed: Array = await http.request_completed
	http.queue_free()
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return ""
	if int(completed[1]) < 200 or int(completed[1]) >= 300:
		return ""
	var body: PackedByteArray = completed[3]
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(body)
	return cache_path

func _guess_extension(url: String) -> String:
	var lower := url.to_lower()
	for ext in [".png", ".jpg", ".jpeg", ".webp", ".gif"]:
		if lower.contains(ext):
			return ext
	return ".png"

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _array_to_dict(source: Array, key_name: String) -> Dictionary:
	var out := {}
	for row in source:
		if row is Dictionary:
			out[str(row.get(key_name, ""))] = row
	return out

func _as_dict_array(source: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if source is Array:
		for item in source:
			if item is Dictionary:
				out.append(item)
	return out

func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return clamp(total / float(values.size()), 1.0, 120.0)
