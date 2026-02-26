extends Node

var team_name := "Mi Equipo"
var primary_color := Color(0.2, 0.5, 1.0, 1.0)
var secondary_color := Color(1.0, 1.0, 1.0, 1.0)
var formation := "2-2"
var template_ready := false

func set_template(new_name: String, primary_hex: String, secondary_hex: String, new_formation: String) -> void:
	team_name = new_name.strip_edges()
	if team_name.is_empty():
		team_name = "Mi Equipo"

	var parsed_primary := Color.from_string(primary_hex.strip_edges(), primary_color)
	var parsed_secondary := Color.from_string(secondary_hex.strip_edges(), secondary_color)
	primary_color = parsed_primary
	secondary_color = parsed_secondary
	formation = new_formation.strip_edges()
	if formation.is_empty():
		formation = "2-2"

	template_ready = true
