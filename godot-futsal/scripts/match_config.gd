extends Node

const POSITIONS: Array[String] = ["GK", "Cierre", "Ala Izq", "Ala Der", "Pivot"]

var team_name := "Mi Equipo"
var primary_color := Color(0.2, 0.5, 1.0, 1.0)
var secondary_color := Color(1.0, 1.0, 1.0, 1.0)
var formation := "1-2-1"
var template_ready := false
var selected_lineup: Dictionary = {
	"GK": "",
	"Cierre": "",
	"Ala Izq": "",
	"Ala Der": "",
	"Pivot": ""
}

var player_pool: Array[Dictionary] = [
	{"name":"Andrés Molina","roles":["GK"],"ovr":84,"pac":40,"sho":25,"pas":72,"dri":48,"def":82,"phy":80},
	{"name":"Diego Navas","roles":["GK"],"ovr":81,"pac":42,"sho":28,"pas":70,"dri":50,"def":78,"phy":77},
	{"name":"Bruno Sala","roles":["GK"],"ovr":79,"pac":45,"sho":22,"pas":68,"dri":44,"def":75,"phy":79},
	{"name":"Marco Herrera","roles":["Cierre"],"ovr":83,"pac":71,"sho":48,"pas":78,"dri":74,"def":85,"phy":84},
	{"name":"Sergio Funes","roles":["Cierre"],"ovr":80,"pac":69,"sho":50,"pas":76,"dri":70,"def":82,"phy":81},
	{"name":"Pablo Cifuentes","roles":["Cierre","Ala Der"],"ovr":82,"pac":74,"sho":60,"pas":79,"dri":76,"def":80,"phy":79},
	{"name":"Iván Duarte","roles":["Ala Izq"],"ovr":84,"pac":88,"sho":77,"pas":80,"dri":86,"def":61,"phy":72},
	{"name":"Leo Mena","roles":["Ala Izq","Pivot"],"ovr":81,"pac":85,"sho":79,"pas":76,"dri":83,"def":55,"phy":74},
	{"name":"Nico Vidal","roles":["Ala Izq","Ala Der"],"ovr":79,"pac":86,"sho":70,"pas":74,"dri":82,"def":57,"phy":69},
	{"name":"Tomás Prieto","roles":["Ala Der"],"ovr":83,"pac":87,"sho":76,"pas":82,"dri":85,"def":58,"phy":71},
	{"name":"Raúl Ferrer","roles":["Ala Der"],"ovr":80,"pac":84,"sho":73,"pas":79,"dri":81,"def":56,"phy":70},
	{"name":"Enzo Quiroga","roles":["Ala Der","Pivot"],"ovr":82,"pac":82,"sho":81,"pas":78,"dri":80,"def":54,"phy":77},
	{"name":"Matías Salvat","roles":["Pivot"],"ovr":85,"pac":78,"sho":88,"pas":74,"dri":82,"def":44,"phy":84},
	{"name":"Julián Rivas","roles":["Pivot"],"ovr":82,"pac":80,"sho":84,"pas":70,"dri":79,"def":42,"phy":82},
	{"name":"Álvaro Peña","roles":["Pivot","Ala Izq"],"ovr":81,"pac":79,"sho":83,"pas":73,"dri":78,"def":45,"phy":80},
	{"name":"Santi Otero","roles":["Cierre","Ala Izq"],"ovr":78,"pac":75,"sho":65,"pas":77,"dri":74,"def":74,"phy":73},
	{"name":"Gabi Ruiz","roles":["Ala Der","Cierre"],"ovr":77,"pac":76,"sho":66,"pas":75,"dri":73,"def":70,"phy":72},
	{"name":"Facu Márquez","roles":["Ala Izq","Ala Der"],"ovr":76,"pac":81,"sho":67,"pas":72,"dri":77,"def":52,"phy":68},
	{"name":"Damián Solís","roles":["GK","Cierre"],"ovr":75,"pac":55,"sho":35,"pas":69,"dri":56,"def":72,"phy":76},
	{"name":"Eze Bernal","roles":["Pivot","Cierre"],"ovr":78,"pac":73,"sho":79,"pas":71,"dri":75,"def":60,"phy":78}
]

func set_template(new_name: String, primary_hex: String, secondary_hex: String, new_formation: String, new_lineup: Dictionary) -> void:
	team_name = new_name.strip_edges()
	if team_name.is_empty():
		team_name = "Mi Equipo"

	primary_color = Color.from_string(primary_hex.strip_edges(), primary_color)
	secondary_color = Color.from_string(secondary_hex.strip_edges(), secondary_color)
	formation = new_formation.strip_edges()
	if formation.is_empty():
		formation = "1-2-1"

	selected_lineup = _sanitize_lineup(new_lineup)
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
