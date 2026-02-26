extends Node3D

const PORT := 7777
const MAX_PLAYERS := 2

@export var player_scene: PackedScene
@export var bot_scene: PackedScene
@export var ai_players_per_side := 3
@export var match_duration := 300.0
@export var field_half_length := 20.0
@export var field_half_width := 10.0

@onready var players_root: Node3D = $Players
@onready var bots_root: Node3D = $Bots
@onready var ball: RigidBody3D = $Ball
@onready var score_label: Label = $CanvasLayer/UI/ScoreLabel
@onready var timer_label: Label = $CanvasLayer/UI/TimerLabel
@onready var status_label: Label = $CanvasLayer/UI/StatusLabel
@onready var ip_input: LineEdit = $CanvasLayer/UI/IPInput
@onready var host_button: Button = $CanvasLayer/UI/HostButton
@onready var join_button: Button = $CanvasLayer/UI/JoinButton
@onready var stamina_label: Label = $CanvasLayer/UI/StaminaLabel
@onready var event_label: Label = $CanvasLayer/UI/EventLabel

var home_score := 0
var away_score := 0
var time_left := 300.0
var players: Dictionary = {}
var bots: Array = []
var halftime_done := false

func _ready() -> void:
	time_left = match_duration
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	event_label.text = "Bienvenido a Futsal 3D"
	status_label.text = "Elegí Host o Join"
	update_ui()

func _process(delta: float) -> void:
	_update_local_hud()
	if not multiplayer.is_server():
		return
	_update_match_clock(delta)
	_check_ball_bounds()
	update_ui()

func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		rpc("sync_ball_state", ball.global_position, ball.linear_velocity)

func _update_match_clock(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left = max(0.0, time_left - delta)

	var half_time := match_duration * 0.5
	if not halftime_done and time_left <= half_time:
		halftime_done = true
		event_label.text = "Descanso: cambio de lados"
		_swap_sides()

	if time_left <= 0.0:
		event_label.text = "Final: %d - %d" % [home_score, away_score]

	rpc("sync_match_state", home_score, away_score, time_left)

func _swap_sides() -> void:
	for player in players.values():
		player.global_position.x *= -1.0
	for bot in bots:
		bot.global_position.x *= -1.0
		bot.anchor_position.x *= -1.0

func _check_ball_bounds() -> void:
	var pos := ball.global_position
	if abs(pos.x) > field_half_length + 3.0 or abs(pos.z) > field_half_width + 3.0:
		event_label.text = "Pelota fuera: saque neutral"
		ball.global_position = Vector3(0.0, 0.35, 0.0)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		status_label.text = "Error al hostear: %s" % err
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Host activo en puerto %d" % PORT
	event_label.text = "Esperando rival..."
	_spawn_player(multiplayer.get_unique_id())
	_spawn_bots_if_needed()

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status_label.text = "Error al conectar: %s" % err
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Conectando a %s:%d..." % [ip, PORT]

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id)
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
	_spawn_player(multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	status_label.text = "Conexión fallida"

func _on_server_disconnected() -> void:
	status_label.text = "Host desconectado"

func _spawn_player(id: int) -> void:
	if players.has(id):
		return
	var player := player_scene.instantiate()
	player.name = "Player_%d" % id
	player.player_id = id
	player.local_control = id == multiplayer.get_unique_id()
	player.team_side = _team_side_for_peer(id)
	player.manager = self
	player.global_position = _spawn_position_for_side(player.team_side, id)
	players_root.add_child(player)
	players[id] = player

func _spawn_bots_if_needed() -> void:
	if not multiplayer.is_server() or bot_scene == null or bots.size() > 0:
		return

	for i in ai_players_per_side:
		_create_bot(-1, i)
		_create_bot(1, i)

func _create_bot(side: int, index: int) -> void:
	var bot := bot_scene.instantiate()
	bot.name = "Bot_%s_%d" % ["Home" if side < 0 else "Away", index]
	bot.team_side = side
	bot.bot_name = bot.name
	bot.manager = self
	bot.anchor_position = _bot_anchor(side, index)
	bot.global_position = bot.anchor_position
	bots_root.add_child(bot)
	bots.append(bot)

func _team_side_for_peer(id: int) -> int:
	return -1 if id % 2 == 1 else 1

func _spawn_position_for_side(side: int, id: int) -> Vector3:
	var lane := 1.5 if id % 3 == 0 else -1.5
	return Vector3((field_half_length - 3.0) * side, 0.0, lane)

func _bot_anchor(side: int, index: int) -> Vector3:
	var x := side * (8.0 - index * 2.6)
	var z_positions := [-5.5, 0.0, 5.5]
	var z := z_positions[index % z_positions.size()]
	return Vector3(x, 0.0, z)

func request_kick_from_player(player_id: int, player_pos: Vector3, forward: Vector3, force: float, kick_range: float) -> void:
	if multiplayer.is_server():
		_apply_kick(player_id, player_pos, forward, force, kick_range)
	else:
		rpc_id(1, "request_kick_server", player_id, player_pos, forward, force, kick_range)

@rpc("any_peer", "reliable")
func request_kick_server(player_id: int, player_pos: Vector3, forward: Vector3, force: float, kick_range: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player_id:
		return
	_apply_kick(player_id, player_pos, forward, force, kick_range)

func _apply_kick(_player_id: int, player_pos: Vector3, forward: Vector3, force: float, kick_range: float) -> void:
	var to_ball := ball.global_position - player_pos
	if to_ball.length() > kick_range:
		return
	var dir := forward.normalized()
	if dir.length() <= 0.001:
		dir = to_ball.normalized()
	ball.apply_central_impulse(dir * force)
	event_label.text = "¡Remate!"

func _on_goal_home_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or body != ball:
		return
	home_score += 1
	event_label.text = "Gol local"
	_reset_after_goal()

func _on_goal_away_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or body != ball:
		return
	away_score += 1
	event_label.text = "Gol visitante"
	_reset_after_goal()

func _reset_after_goal() -> void:
	for id in players.keys():
		var side := players[id].team_side
		players[id].global_position = _spawn_position_for_side(side, id)
		players[id].velocity = Vector3.ZERO
	for i in bots.size():
		bots[i].global_position = _bot_anchor(bots[i].team_side, i % ai_players_per_side)
	ball.global_position = Vector3(0.0, 0.35, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	rpc("sync_match_state", home_score, away_score, time_left)
	update_ui()

func _update_local_hud() -> void:
	var local_player := _get_local_player()
	if local_player == null:
		stamina_label.text = "Stamina: --"
		return
	stamina_label.text = "Stamina: %d%%" % int(local_player.stamina_ratio() * 100.0)

func _get_local_player() -> Node:
	for player in players.values():
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
	if multiplayer.is_server():
		return
	ball.global_position = pos
	ball.linear_velocity = vel

func update_ui() -> void:
	var team := MatchConfig.team_name if MatchConfig.template_ready else "Local"
	score_label.text = "%s %d - %d Visitante" % [team, home_score, away_score]
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
