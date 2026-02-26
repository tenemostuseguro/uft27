extends Node3D

const PORT := 7777
const MAX_PLAYERS := 2

@export var player_scene: PackedScene

@onready var players_root: Node3D = $Players
@onready var ball: RigidBody3D = $Ball
@onready var score_label: Label = $CanvasLayer/UI/ScoreLabel
@onready var timer_label: Label = $CanvasLayer/UI/TimerLabel
@onready var status_label: Label = $CanvasLayer/UI/StatusLabel
@onready var ip_input: LineEdit = $CanvasLayer/UI/IPInput
@onready var host_button: Button = $CanvasLayer/UI/HostButton
@onready var join_button: Button = $CanvasLayer/UI/JoinButton

var home_score := 0
var away_score := 0
var time_left := 180.0
var players: Dictionary = {}

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	status_label.text = "Local: elegí Host o Join"
	update_ui()

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if time_left > 0.0:
		time_left = max(0.0, time_left - delta)
		rpc("sync_match_state", home_score, away_score, time_left)
	update_ui()

func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		rpc_unreliable("sync_ball_state", ball.global_position, ball.linear_velocity)

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		status_label.text = "Error al hostear: %s" % err
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Host activo en puerto %d" % PORT
	_spawn_player(multiplayer.get_unique_id())

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

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	status_label.text = "Peer desconectado: %d" % id

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
	player.manager = self
	player.global_position = _spawn_position_for(id)
	players_root.add_child(player)
	players[id] = player

func _spawn_position_for(id: int) -> Vector3:
	if id % 2 == 0:
		return Vector3(6.0, 1.0, 0.0)
	return Vector3(-6.0, 1.0, 0.0)

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

func _on_goal_home_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or body != ball:
		return
	home_score += 1
	_reset_after_goal()

func _on_goal_away_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or body != ball:
		return
	away_score += 1
	_reset_after_goal()

func _reset_after_goal() -> void:
	for id in players.keys():
		players[id].global_position = _spawn_position_for(id)
		players[id].velocity = Vector3.ZERO
	ball.global_position = Vector3.ZERO
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	rpc("sync_match_state", home_score, away_score, time_left)
	update_ui()

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
	score_label.text = "%d - %d" % [home_score, away_score]
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
