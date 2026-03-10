extends Node3D
class_name GameManager3D

const PORT := 7777
const MAX_PLAYERS := 2

@export var player_scene: PackedScene
@export var bot_scene: PackedScene
@export var ai_players_per_side := 4
@export var match_duration := 300.0
@export var field_half_length := 20.0
@export var field_half_width := 10.0

@onready var players_root: Node3D = $Players
@onready var bots_root: Node3D = $Bots
@onready var ball: RigidBody3D = $Ball
@onready var score_label: Label = $CanvasLayer/UI/Hud/ScoreLabel
@onready var timer_label: Label = $CanvasLayer/UI/Hud/TimerLabel
@onready var status_label: Label = $CanvasLayer/UI/Hud/StatusLabel
@onready var event_label: Label = $CanvasLayer/UI/Hud/EventLabel
@onready var stamina_label: Label = $CanvasLayer/UI/Hud/StaminaLabel
@onready var mode_label: Label = $CanvasLayer/UI/Hud/ModeLabel
@onready var possession_label: Label = $CanvasLayer/UI/Hud/PossessionLabel

@onready var ip_input: LineEdit = $CanvasLayer/UI/Hud/VBox/NetworkRow/IPInput
@onready var host_button: Button = $CanvasLayer/UI/Hud/VBox/NetworkRow/HostButton
@onready var join_button: Button = $CanvasLayer/UI/Hud/VBox/NetworkRow/JoinButton
@onready var vs_ai_button: Button = $CanvasLayer/UI/Hud/VBox/NetworkRow/VsAIButton

@onready var mobile_controls: Control = $CanvasLayer/UI/MobileControls
@onready var move_up_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/UpButton
@onready var move_down_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/DownButton
@onready var move_left_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/LeftButton
@onready var move_right_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/RightButton
@onready var shoot_button: Button = $CanvasLayer/UI/MobileControls/ActionPad/ShootButton
@onready var sprint_button: Button = $CanvasLayer/UI/MobileControls/ActionPad/SprintButton

var home_score := 0
var away_score := 0
var time_left := 300.0
var players: Dictionary = {}
var bots: Array[CharacterBody3D] = []
var halftime_done := false
var offline_vs_ai := false

var mobile_left := false
var mobile_right := false
var mobile_up := false
var mobile_down := false
var mobile_sprint := false
var mobile_shoot_request := false

func _ready() -> void:
	time_left = match_duration
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	vs_ai_button.pressed.connect(_on_vs_ai_pressed)

	_connect_mobile_controls()
	mobile_controls.visible = OS.has_feature("mobile")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	event_label.text = "Elegí modo de juego"
	status_label.text = "Host, Join o Vs IA"
	mode_label.text = "Modo: menú"
	update_ui()

func _process(delta: float) -> void:
	_update_local_hud()
	if not _is_authority():
		return
	_update_match_clock(delta)
	_check_ball_bounds()
	_update_possession_label()
	update_ui()

func _physics_process(_delta: float) -> void:
	if _is_authority() and multiplayer.has_multiplayer_peer():
		rpc("sync_ball_state", ball.global_position, ball.linear_velocity)

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _connect_mobile_controls() -> void:
	move_up_button.button_down.connect(func() -> void: mobile_up = true)
	move_up_button.button_up.connect(func() -> void: mobile_up = false)
	move_down_button.button_down.connect(func() -> void: mobile_down = true)
	move_down_button.button_up.connect(func() -> void: mobile_down = false)
	move_left_button.button_down.connect(func() -> void: mobile_left = true)
	move_left_button.button_up.connect(func() -> void: mobile_left = false)
	move_right_button.button_down.connect(func() -> void: mobile_right = true)
	move_right_button.button_up.connect(func() -> void: mobile_right = false)
	sprint_button.button_down.connect(func() -> void: mobile_sprint = true)
	sprint_button.button_up.connect(func() -> void: mobile_sprint = false)
	shoot_button.pressed.connect(func() -> void: mobile_shoot_request = true)

func get_mobile_move_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if mobile_left:
		x -= 1.0
	if mobile_right:
		x += 1.0
	if mobile_up:
		y -= 1.0
	if mobile_down:
		y += 1.0
	return Vector2(x, y).normalized()

func is_mobile_sprint_pressed() -> bool:
	return mobile_sprint

func consume_mobile_shoot() -> bool:
	if mobile_shoot_request:
		mobile_shoot_request = false
		return true
	return false

func _update_match_clock(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left = max(0.0, time_left - delta)

	var half_time: float = match_duration * 0.5
	if not halftime_done and time_left <= half_time:
		halftime_done = true
		event_label.text = "Descanso: cambio de lados"
		_swap_sides()

	if time_left <= 0.0:
		event_label.text = "Final: %d - %d" % [home_score, away_score]

	if multiplayer.has_multiplayer_peer():
		rpc("sync_match_state", home_score, away_score, time_left)

func _swap_sides() -> void:
	for raw_player in players.values():
		var player: CharacterBody3D = raw_player
		player.global_position.x *= -1.0
		player.team_side *= -1
	for bot in bots:
		bot.global_position.x *= -1.0
		bot.anchor_position.x *= -1.0
		bot.team_side *= -1

func _check_ball_bounds() -> void:
	var pos: Vector3 = ball.global_position
	if abs(pos.x) > field_half_length + 3.0 or abs(pos.z) > field_half_width + 3.0:
		event_label.text = "Pelota fuera: saque neutral"
		ball.global_position = Vector3(0.0, 0.35, 0.0)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO

func _on_vs_ai_pressed() -> void:
	offline_vs_ai = true
	status_label.text = "Modo local vs IA"
	mode_label.text = "Modo: local vs IA"
	event_label.text = "Partido iniciado"
	if players.is_empty():
		_spawn_player(1, true, -1)
	_spawn_bots_balanced(true)

func _on_host_pressed() -> void:
	offline_vs_ai = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		status_label.text = "Error al hostear: %s" % err
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Host activo en puerto %d" % PORT
	mode_label.text = "Modo: host online"
	event_label.text = "Esperando rival..."
	if players.is_empty():
		_spawn_player(multiplayer.get_unique_id(), true, -1)
	_spawn_bots_balanced(false)

func _on_join_pressed() -> void:
	offline_vs_ai = false
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status_label.text = "Error al conectar: %s" % err
		return

	multiplayer.multiplayer_peer = peer
	mode_label.text = "Modo: cliente online"
	status_label.text = "Conectando a %s:%d..." % [ip, PORT]

func _on_peer_connected(id: int) -> void:
	if _is_authority():
		_spawn_player(id, false, 1)
	status_label.text = "Peer conectado: %d" % id
	event_label.text = "Partido en línea activo"

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	status_label.text = "Peer desconectado: %d" % id
	event_label.text = "Rival desconectado"

func _on_connected_to_server() -> void:
	status_label.text = "Conectado al host"
	_spawn_player(multiplayer.get_unique_id(), true, 1)

func _on_connection_failed() -> void:
	status_label.text = "Conexión fallida"

func _on_server_disconnected() -> void:
	status_label.text = "Host desconectado"

func _spawn_player(id: int, forced_local: bool, side: int) -> void:
	if players.has(id):
		return
	var player: CharacterBody3D = player_scene.instantiate()
	player.name = "Player_%d" % id
	player.player_id = id
	player.local_control = forced_local or id == multiplayer.get_unique_id()
	player.team_side = side
	player.manager = self
	player.global_position = _spawn_position_for_side(side, id)
	players_root.add_child(player)
	players[id] = player

func _spawn_bots_balanced(full_vs_ai: bool) -> void:
	if bot_scene == null or bots.size() > 0:
		return
	if not _is_authority():
		return

	var home_bots: int = ai_players_per_side - (0 if full_vs_ai else 1)
	if home_bots < 0:
		home_bots = 0
	var away_bots: int = ai_players_per_side

	for i: int in range(home_bots):
		_create_bot(-1, i, home_bots, false)
	for j: int in range(away_bots):
		_create_bot(1, j, away_bots, true)

func _create_bot(side: int, index: int, total_per_side: int, is_rival: bool) -> void:
	var bot: CharacterBody3D = bot_scene.instantiate()
	bot.name = "Bot_%s_%d" % ["Home" if side < 0 else "Away", index]
	bot.team_side = side
	bot.role_name = _role_for_bot_index(index, total_per_side)
	bot.is_rival = is_rival
	bot.bot_name = bot.name
	bot.manager = self
	bot.anchor_position = _bot_anchor_by_role(side, bot.role_name)
	bot.global_position = bot.anchor_position
	bots_root.add_child(bot)
	bots.append(bot)

func _role_for_bot_index(index: int, total: int) -> String:
	var roles: Array[String] = ["GK", "Cierre", "Ala Izq", "Ala Der", "Pivot"]
	if total >= roles.size():
		return roles[min(index, roles.size() - 1)]
	var compact_roles: Array[String] = ["GK", "Cierre", "Ala Izq", "Pivot"]
	if total == 4:
		return compact_roles[min(index, compact_roles.size() - 1)]
	if total == 3:
		return ["GK", "Cierre", "Pivot"][min(index, 2)]
	if total == 2:
		return ["GK", "Pivot"][min(index, 1)]
	return "Cierre"

func _spawn_position_for_side(side: int, id: int) -> Vector3:
	var lane: float = 1.5 if id % 3 == 0 else -1.5
	return Vector3((field_half_length - 3.0) * side, 0.0, lane)

func _bot_anchor_by_role(side: int, role: String) -> Vector3:
	var x := 0.0
	var z := 0.0
	match role:
		"GK":
			x = side * (field_half_length - 1.8)
			z = 0.0
		"Cierre":
			x = side * (field_half_length - 6.0)
			z = 0.0
		"Ala Izq":
			x = side * (field_half_length - 10.0)
			z = -4.8
		"Ala Der":
			x = side * (field_half_length - 10.0)
			z = 4.8
		"Pivot":
			x = side * (field_half_length - 14.0)
			z = 0.0
		_:
			x = side * (field_half_length - 8.0)
	return Vector3(x, 0.0, z)

func get_attack_goal_position(side: int) -> Vector3:
	return Vector3(-side * (field_half_length - 0.8), 0.35, 0.0)

func get_defend_goal_position(side: int) -> Vector3:
	return Vector3(side * (field_half_length - 0.8), 0.35, 0.0)

func get_closest_teammate(position: Vector3, side: int, exclude: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for raw_player in players.values():
		var player: Node3D = raw_player
		if player == exclude or int(player.team_side) != side:
			continue
		var d := position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = player
	for bot in bots:
		if bot == exclude or int(bot.team_side) != side:
			continue
		var d2 := position.distance_to(bot.global_position)
		if d2 < best_d:
			best_d = d2
			best = bot
	return best

func get_closest_opponent(position: Vector3, side: int) -> Node3D:
	var enemy_side := -side
	var best: Node3D = null
	var best_d := INF
	for raw_player in players.values():
		var player: Node3D = raw_player
		if int(player.team_side) != enemy_side:
			continue
		var d := position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = player
	for bot in bots:
		if int(bot.team_side) != enemy_side:
			continue
		var d2 := position.distance_to(bot.global_position)
		if d2 < best_d:
			best_d = d2
			best = bot
	return best

func request_kick_from_player(player_id: int, player_pos: Vector3, forward: Vector3, force: float, kick_range: float) -> void:
	if _is_authority():
		_apply_kick(player_id, player_pos, forward, force, kick_range)
	else:
		rpc_id(1, "request_kick_server", player_id, player_pos, forward, force, kick_range)

@rpc("any_peer", "reliable")
func request_kick_server(player_id: int, player_pos: Vector3, forward: Vector3, force: float, kick_range: float) -> void:
	if not _is_authority():
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != player_id:
		return
	_apply_kick(player_id, player_pos, forward, force, kick_range)

func _apply_kick(_player_id: int, player_pos: Vector3, forward: Vector3, force: float, kick_range: float) -> void:
	var to_ball: Vector3 = ball.global_position - player_pos
	if to_ball.length() > kick_range:
		return
	var dir: Vector3 = forward.normalized()
	if dir.length() <= 0.001:
		dir = to_ball.normalized()
	ball.apply_central_impulse(dir * force)
	event_label.text = "¡Remate!"

func _on_goal_home_body_entered(body: Node3D) -> void:
	if not _is_authority() or body != ball:
		return
	home_score += 1
	event_label.text = "Gol local"
	_reset_after_goal()

func _on_goal_away_body_entered(body: Node3D) -> void:
	if not _is_authority() or body != ball:
		return
	away_score += 1
	event_label.text = "Gol visitante"
	_reset_after_goal()

func _reset_after_goal() -> void:
	for id_variant in players.keys():
		var id: int = int(id_variant)
		var side: int = int(players[id].team_side)
		players[id].global_position = _spawn_position_for_side(side, id)
		players[id].velocity = Vector3.ZERO
	for bot in bots:
		bot.anchor_position = _bot_anchor_by_role(int(bot.team_side), str(bot.role_name))
		bot.global_position = bot.anchor_position
		bot.velocity = Vector3.ZERO
	ball.global_position = Vector3(0.0, 0.35, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	if multiplayer.has_multiplayer_peer():
		rpc("sync_match_state", home_score, away_score, time_left)
	update_ui()

func _update_local_hud() -> void:
	var local_player: Node = _get_local_player()
	if local_player == null:
		stamina_label.text = "Stamina: --"
		return
	stamina_label.text = "Stamina: %d%%" % int(local_player.stamina_ratio() * 100.0)

func _update_possession_label() -> void:
	var closest_home := _closest_entity_to_ball(-1)
	var closest_away := _closest_entity_to_ball(1)
	if closest_home == INF and closest_away == INF:
		possession_label.text = "Posesión: --"
	elif closest_home <= closest_away:
		possession_label.text = "Posesión: Local"
	else:
		possession_label.text = "Posesión: Visitante"

func _closest_entity_to_ball(side: int) -> float:
	var best := INF
	for raw_player in players.values():
		var player: Node3D = raw_player
		if int(player.team_side) != side:
			continue
		best = min(best, player.global_position.distance_to(ball.global_position))
	for bot in bots:
		if int(bot.team_side) != side:
			continue
		best = min(best, bot.global_position.distance_to(ball.global_position))
	return best

func _get_local_player() -> Node:
	for raw_player in players.values():
		var player: Node = raw_player
		if player.local_control:
			return player
	return null

@rpc("authority", "reliable")
func sync_match_state(home: int, away: int, clock_left: float) -> void:
	home_score = home
	away_score = away
	time_left = clock_left
	update_ui()

@rpc("authority", "unreliable")
func sync_ball_state(pos: Vector3, vel: Vector3) -> void:
	if _is_authority():
		return
	ball.global_position = pos
	ball.linear_velocity = vel

func update_ui() -> void:
	var team := MatchConfig.team_name if MatchConfig.template_ready else "Local"
	score_label.text = "%s %d - %d Visitante" % [team, home_score, away_score]
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
