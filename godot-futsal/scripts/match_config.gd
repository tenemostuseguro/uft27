extends Node

const POSITIONS: Array[String] = ["GK", "Cierre", "Ala Izq", "Ala Der", "Pivot"]

var team_name := "Mi Equipo"
var primary_color := Color(0.2, 0.5, 1.0, 1.0)
var secondary_color := Color(1.0, 1.0, 1.0, 1.0)
var formation := "1-2-1"
var profile_photo_path := ""
var selected_crest_id := ""
var template_ready := false
var selected_lineup: Dictionary = {
	"GK": "",
	"Cierre": "",
	"Ala Izq": "",
	"Ala Der": "",
	"Pivot": ""
}

var player_pool: Array[Dictionary] = []
var crest_catalog: Array[Dictionary] = []

const MODE_VS_AI := "vs_ai"
const MODE_HOST := "host"
const MODE_JOIN := "join"

var start_mode := MODE_VS_AI
var join_ip := "127.0.0.1"

func set_match_start(mode: String, ip: String = "127.0.0.1") -> void:
	start_mode = mode
	join_ip = ip.strip_edges()
	if join_ip.is_empty():
		join_ip = "127.0.0.1"

func _ready() -> void:
	if player_pool.is_empty():
		player_pool = _build_player_pool()
	if crest_catalog.is_empty():
		crest_catalog = _build_crest_catalog()

func set_template(new_name: String, primary_hex: String, secondary_hex: String, new_formation: String, new_lineup: Dictionary, crest_id: String = "", photo_path: String = "") -> void:
	team_name = new_name.strip_edges()
	if team_name.is_empty():
		team_name = "Mi Equipo"

	primary_color = Color.from_string(primary_hex.strip_edges(), primary_color)
	secondary_color = Color.from_string(secondary_hex.strip_edges(), secondary_color)
	formation = new_formation.strip_edges()
	if formation.is_empty():
		formation = "1-2-1"

	selected_lineup = _sanitize_lineup(new_lineup)

	if not crest_id.strip_edges().is_empty():
		selected_crest_id = crest_id.strip_edges()
	if not photo_path.strip_edges().is_empty():
		profile_photo_path = photo_path.strip_edges()

	template_ready = _is_lineup_complete(selected_lineup)

func get_players_for_role(role: String) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for raw_player in player_pool:
		var player: Dictionary = raw_player
		var roles: Array = player.get("roles", [])
		if role in roles:
			players.append(player)
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("ovr", 0)) > int(b.get("ovr", 0)))
	return players

func find_player_by_name(player_name: String) -> Dictionary:
	for raw_player in player_pool:
		var player: Dictionary = raw_player
		if str(player.get("name", "")) == player_name:
			return player
	return {}

func get_lineup_rating() -> int:
	var total := 0
	var count := 0
	for role in POSITIONS:
		var player_name: String = str(selected_lineup.get(role, ""))
		if player_name.is_empty():
			continue
		var player := find_player_by_name(player_name)
		if player.is_empty():
			continue
		total += int(player.get("ovr", 0))
		count += 1
	if count == 0:
		return 0
	return int(round(float(total) / float(count)))

func _sanitize_lineup(candidate: Dictionary) -> Dictionary:
	var safe_lineup: Dictionary = {}
	for role in POSITIONS:
		safe_lineup[role] = str(candidate.get(role, "")).strip_edges()
	return safe_lineup

func _is_lineup_complete(lineup: Dictionary) -> bool:
	for role in POSITIONS:
		if str(lineup.get(role, "")).is_empty():
			return false
	return true

func set_profile_photo(path: String) -> void:
	profile_photo_path = path.strip_edges()

func set_selected_crest(crest_id: String) -> void:
	selected_crest_id = crest_id.strip_edges()
	template_ready = _is_lineup_complete(selected_lineup)

func get_available_countries() -> Array[String]:
	var countries: Array[String] = []
	var seen: Dictionary = {}
	for crest in crest_catalog:
		var country: String = str(crest.get("country", ""))
		if country.is_empty() or seen.has(country):
			continue
		seen[country] = true
		countries.append(country)
	countries.sort()
	return countries

func get_leagues_for_country(country: String) -> Array[String]:
	var leagues: Array[String] = []
	var seen: Dictionary = {}
	for crest in crest_catalog:
		if str(crest.get("country", "")) != country:
			continue
		var league: String = str(crest.get("league", ""))
		if league.is_empty() or seen.has(league):
			continue
		seen[league] = true
		leagues.append(league)
	leagues.sort()
	return leagues

func get_crests(country: String, league: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for crest in crest_catalog:
		if str(crest.get("country", "")) != country:
			continue
		if str(crest.get("league", "")) != league:
			continue
		result.append(crest)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("team", "")) < str(b.get("team", "")))
	return result

func find_crest_by_id(crest_id: String) -> Dictionary:
	for crest in crest_catalog:
		if str(crest.get("id", "")) == crest_id:
			return crest
	return {}

func _build_crest_catalog() -> Array[Dictionary]:
	return [
		{"id":"ar_lp_boca","country":"Argentina","league":"Liga Profesional","team":"Boca Juniors","crest":"🔵🟡"},
		{"id":"ar_lp_river","country":"Argentina","league":"Liga Profesional","team":"River Plate","crest":"⚪🔴"},
		{"id":"ar_lp_racing","country":"Argentina","league":"Liga Profesional","team":"Racing Club","crest":"🔵⚪"},
		{"id":"es_lal_rm","country":"España","league":"LaLiga","team":"Real Madrid","crest":"👑⚪"},
		{"id":"es_lal_fcb","country":"España","league":"LaLiga","team":"FC Barcelona","crest":"🔵🔴"},
		{"id":"es_lal_atm","country":"España","league":"LaLiga","team":"Atlético Madrid","crest":"🔴⚪"},
		{"id":"eng_pl_ars","country":"Inglaterra","league":"Premier League","team":"Arsenal","crest":"🔴⚪"},
		{"id":"eng_pl_mci","country":"Inglaterra","league":"Premier League","team":"Manchester City","crest":"🔵"},
		{"id":"eng_pl_liv","country":"Inglaterra","league":"Premier League","team":"Liverpool","crest":"🔴"},
		{"id":"it_sa_juv","country":"Italia","league":"Serie A","team":"Juventus","crest":"⚫⚪"},
		{"id":"it_sa_milan","country":"Italia","league":"Serie A","team":"AC Milan","crest":"🔴⚫"},
		{"id":"it_sa_inter","country":"Italia","league":"Serie A","team":"Inter","crest":"🔵⚫"}
	]

func _build_player_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []

	# GKs
	pool.append(_make_player("Andrés Molina", ["GK"], 84, 40, 25, 72, 48, 82, 80))
	pool.append(_make_player("Diego Navas", ["GK"], 81, 42, 28, 70, 50, 78, 77))
	pool.append(_make_player("Bruno Sala", ["GK"], 79, 45, 22, 68, 44, 75, 79))
	pool.append(_make_player("Damián Solís", ["GK", "Cierre"], 75, 55, 35, 69, 56, 72, 76))
	pool.append(_make_player("Lucho Peralta", ["GK"], 77, 48, 30, 67, 49, 76, 75))
	pool.append(_make_player("Mateo Bravo", ["GK"], 78, 47, 31, 69, 52, 77, 76))
	pool.append(_make_player("Iker Roldán", ["GK"], 74, 44, 28, 65, 47, 71, 74))

	# Cierres
	pool.append(_make_player("Marco Herrera", ["Cierre"], 83, 71, 48, 78, 74, 85, 84))
	pool.append(_make_player("Sergio Funes", ["Cierre"], 80, 69, 50, 76, 70, 82, 81))
	pool.append(_make_player("Pablo Cifuentes", ["Cierre", "Ala Der"], 82, 74, 60, 79, 76, 80, 79))
	pool.append(_make_player("Santi Otero", ["Cierre", "Ala Izq"], 78, 75, 65, 77, 74, 74, 73))
	pool.append(_make_player("Ramiro Sosa", ["Cierre"], 81, 72, 57, 78, 72, 81, 80))
	pool.append(_make_player("Joaquín Vera", ["Cierre"], 79, 70, 55, 76, 70, 79, 79))
	pool.append(_make_player("Nacho Godoy", ["Cierre"], 76, 68, 52, 73, 69, 75, 76))

	# Alas izquierdas
	pool.append(_make_player("Iván Duarte", ["Ala Izq"], 84, 88, 77, 80, 86, 61, 72))
	pool.append(_make_player("Leo Mena", ["Ala Izq", "Pivot"], 81, 85, 79, 76, 83, 55, 74))
	pool.append(_make_player("Facu Márquez", ["Ala Izq", "Ala Der"], 76, 81, 67, 72, 77, 52, 68))
	pool.append(_make_player("Gabriel Luna", ["Ala Izq"], 82, 87, 74, 79, 84, 59, 71))
	pool.append(_make_player("Thiago Olmedo", ["Ala Izq"], 78, 84, 68, 73, 80, 53, 67))
	pool.append(_make_player("Franco Gil", ["Ala Izq", "Cierre"], 77, 79, 66, 74, 78, 64, 70))
	pool.append(_make_player("Seba Torres", ["Ala Izq"], 75, 80, 64, 70, 76, 50, 65))

	# Alas derechas
	pool.append(_make_player("Tomás Prieto", ["Ala Der"], 83, 87, 76, 82, 85, 58, 71))
	pool.append(_make_player("Raúl Ferrer", ["Ala Der"], 80, 84, 73, 79, 81, 56, 70))
	pool.append(_make_player("Gabi Ruiz", ["Ala Der", "Cierre"], 77, 76, 66, 75, 73, 70, 72))
	pool.append(_make_player("Nico Vidal", ["Ala Izq", "Ala Der"], 79, 86, 70, 74, 82, 57, 69))
	pool.append(_make_player("Lautaro Rey", ["Ala Der"], 81, 85, 74, 80, 83, 55, 72))
	pool.append(_make_player("Pedro Maffei", ["Ala Der"], 78, 82, 69, 76, 79, 53, 68))
	pool.append(_make_player("Ricky Montalvo", ["Ala Der", "Ala Izq"], 76, 80, 67, 73, 77, 51, 67))
	pool.append(_make_player("Nicolás Albornoz", ["Ala Der"], 75, 79, 65, 72, 75, 50, 66))

	# Pivots
	pool.append(_make_player("Matías Salvat", ["Pivot"], 85, 78, 88, 74, 82, 44, 84))
	pool.append(_make_player("Julián Rivas", ["Pivot"], 82, 80, 84, 70, 79, 42, 82))
	pool.append(_make_player("Álvaro Peña", ["Pivot", "Ala Izq"], 81, 79, 83, 73, 78, 45, 80))
	pool.append(_make_player("Eze Bernal", ["Pivot", "Cierre"], 78, 73, 79, 71, 75, 60, 78))
	pool.append(_make_player("Enzo Quiroga", ["Ala Der", "Pivot"], 82, 82, 81, 78, 80, 54, 77))
	pool.append(_make_player("Germán Costa", ["Pivot"], 80, 77, 82, 72, 77, 43, 79))
	pool.append(_make_player("Axel Montero", ["Pivot"], 79, 76, 80, 70, 76, 41, 80))
	pool.append(_make_player("Fede Lagos", ["Pivot"], 77, 74, 78, 69, 74, 40, 78))
	pool.append(_make_player("Mauro Paz", ["Cierre", "Pivot"], 80, 71, 68, 74, 73, 74, 82))

	return pool

func _make_player(player_name: String, roles: Array[String], ovr: int, pac: int, sho: int, pas: int, dri: int, deff: int, phy: int) -> Dictionary:
	return {
		"name": player_name,
		"roles": roles,
		"ovr": ovr,
		"pac": pac,
		"sho": sho,
		"pas": pas,
		"dri": dri,
		"def": deff,
		"phy": phy
	}
