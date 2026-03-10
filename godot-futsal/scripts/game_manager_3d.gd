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
@export var goal_half_width := 1.6

@onready var players_root: Node3D = $Players
@onready var bots_root: Node3D = $Bots
@onready var ball: RigidBody3D = $Ball
@onready var score_label: Label = $CanvasLayer/UI/Hud/VBox/ScoreLabel
@onready var timer_label: Label = $CanvasLayer/UI/Hud/VBox/TimerLabel
@onready var stamina_label: Label = $CanvasLayer/UI/Hud/VBox/StaminaLabel
@onready var possession_label: Label = $CanvasLayer/UI/Hud/VBox/PossessionLabel
@onready var mode_label: Label = $CanvasLayer/UI/Hud/VBox/ModeLabel
@onready var status_label: Label = $CanvasLayer/UI/Hud/VBox/StatusLabel
@onready var event_label: Label = $CanvasLayer/UI/Hud/VBox/EventLabel
@onready var foul_label: Label = $CanvasLayer/UI/Hud/VBox/FoulLabel
@onready var change_label: Label = $CanvasLayer/UI/Hud/VBox/ChangeLabel

@onready var ip_input: LineEdit = $CanvasLayer/UI/Hud/VBox/NetworkRow/IPInput
@onready var host_button: Button = $CanvasLayer/UI/Hud/VBox/NetworkRow/HostButton
@onready var join_button: Button = $CanvasLayer/UI/Hud/VBox/NetworkRow/JoinButton
@onready var vs_ai_button: Button = $CanvasLayer/UI/Hud/VBox/NetworkRow/VsAIButton

@onready var mobile_controls: Control = $CanvasLayer/UI/MobileControls
@onready var move_up_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/UpButton
@onready var move_down_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/DownButton
@onready var move_left_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/LeftButton
@onready var move_right_button: Button = $CanvasLayer/UI/MobileControls/MovePad/Grid/RightButton
@onready var shoot_button: Button = $CanvasLayer/UI/MobileControls/ActionPad/VBox/ShootButton
@onready var sprint_button: Button = $CanvasLayer/UI/MobileControls/ActionPad/VBox/SprintButton
@onready var change_button: Button = $CanvasLayer/UI/MobileControls/ActionPad/VBox/ChangeButton
@onready var pause_menu: PanelContainer = $CanvasLayer/UI/PauseMenu
@onready var resume_button: Button = $CanvasLayer/UI/PauseMenu/VBox/ResumeButton
@onready var restart_button: Button = $CanvasLayer/UI/PauseMenu/VBox/RestartButton
@onready var back_menu_button: Button = $CanvasLayer/UI/PauseMenu/VBox/BackMenuButton

var home_score := 0
var away_score := 0
var home_fouls := 0
var away_fouls := 0
var home_changes_left := 9
var away_changes_left := 9
var time_left := 300.0
var players: Dictionary = {}
var bots: Array[CharacterBody3D] = []

var halftime_done := false
var offline_vs_ai := false
var last_touch_side := -1
var foul_cooldown := 0.0
var match_finished := false

var dead_ball := false
var restart_timer := 0.0
var restart_position := Vector3.ZERO
var restart_reason := ""

var mobile_left := false
var mobile_right := false
var mobile_up := false
var mobile_down := false
var mobile_sprint := false
var mobile_shoot_request := false
var mobile_change_request := false
var paused_by_menu := false

func _ready() -> void:
	time_left = match_duration
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	vs_ai_button.pressed.connect(_on_vs_ai_pressed)

	_connect_mobile_controls()
	mobile_controls.visible = OS.has_feature("mobile")
	pause_menu.visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	back_menu_button.pressed.connect(_on_back_menu_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	event_label.text = "Elegí modo de juego"
	status_label.text = "Host, Join o Vs IA"
	mode_label.text = "Modo: menú"
	_update_foul_label()
	_update_change_label()
	update_ui()

func _process(delta: float) -> void:
	_update_local_hud()
	if paused_by_menu:
		return
	if not _is_authority():
		return

	_update_match_clock(delta)
	if match_finished:
		_update_possession_label()
		update_ui()
		return

	if dead_ball:
		restart_timer = max(0.0, restart_timer - delta)
		if restart_timer <= 0.0:
			_apply_restart()
		foul_cooldown = max(0.0, foul_cooldown - delta)
		_update_possession_label()
		update_ui()
		return

	foul_cooldown = max(0.0, foul_cooldown - delta)
	_check_ball_out_events()
	_check_foul_events()
	_constrain_entities_to_field()
	_update_possession_label()
	update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()

func _toggle_pause_menu() -> void:
	paused_by_menu = not paused_by_menu
	pause_menu.visible = paused_by_menu
	event_label.text = "Pausa" if paused_by_menu else "Partido reanudado"

func _on_resume_pressed() -> void:
	if paused_by_menu:
		_toggle_pause_menu()

func _on_restart_pressed() -> void:
	_prepare_new_match()
	_reset_player_and_bot_positions()
	paused_by_menu = false
	pause_menu.visible = false
	event_label.text = "Partido reiniciado"

func _on_back_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu2D.tscn")

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
	change_button.pressed.connect(func() -> void: mobile_change_request = true)

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

func consume_mobile_change() -> bool:
	if mobile_change_request:
		mobile_change_request = false
		return true
	return false

func _update_match_clock(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left = max(0.0, time_left - delta)

	var half_time: float = match_duration * 0.5
	if not halftime_done and time_left <= half_time:
		halftime_done = true
		home_fouls = 0
		away_fouls = 0
		_update_foul_label()
		event_label.text = "Descanso: cambio de lados"
		_swap_sides()

	if time_left <= 0.0:
		_finish_match()

	if multiplayer.has_multiplayer_peer():
		rpc("sync_match_state", home_score, away_score, time_left, home_fouls, away_fouls, home_changes_left, away_changes_left)

func _finish_match() -> void:
	if match_finished:
		return
	match_finished = true
	dead_ball = true
	restart_timer = 0.0
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	for raw_player in players.values():
		var p: CharacterBody3D = raw_player
		p.velocity = Vector3.ZERO
	for b in bots:
		b.velocity = Vector3.ZERO
	event_label.text = "Final: %d - %d" % [home_score, away_score]

func can_play() -> bool:
	return not match_finished and time_left > 0.0

func _swap_sides() -> void:
	for raw_player in players.values():
		var player: CharacterBody3D = raw_player
		player.global_position.x *= -1.0
		player.team_side *= -1
	for bot in bots:
		bot.global_position.x *= -1.0
		bot.anchor_position.x *= -1.0
		bot.team_side *= -1

func _prepare_new_match() -> void:
	home_score = 0
	away_score = 0
	home_fouls = 0
	away_fouls = 0
	home_changes_left = 9
	away_changes_left = 9
	time_left = match_duration
	halftime_done = false
	last_touch_side = 0
	foul_cooldown = 0.0
	match_finished = false
	dead_ball = false
	restart_timer = 0.0
	restart_reason = ""
	restart_position = Vector3.ZERO
	ball.global_position = Vector3(0.0, 0.35, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	_update_foul_label()
	_update_change_label()
	update_ui()

func _on_vs_ai_pressed() -> void:
	_prepare_new_match()
	offline_vs_ai = true
	status_label.text = "Modo local vs IA"
	mode_label.text = "Modo: local vs IA"
	event_label.text = "Partido iniciado"
	if players.is_empty():
		_spawn_player(1, true, -1)
	_spawn_bots_balanced(true)

func _on_host_pressed() -> void:
	_prepare_new_match()
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
	_prepare_new_match()
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

func _constrain_entities_to_field() -> void:
	for raw_player in players.values():
		var p: CharacterBody3D = raw_player
		p.global_position.x = clamp(p.global_position.x, -field_half_length + 0.4, field_half_length - 0.4)
		p.global_position.z = clamp(p.global_position.z, -field_half_width + 0.4, field_half_width - 0.4)
	for b in bots:
		b.global_position.x = clamp(b.global_position.x, -field_half_length + 0.4, field_half_length - 0.4)
		b.global_position.z = clamp(b.global_position.z, -field_half_width + 0.4, field_half_width - 0.4)

func _check_ball_out_events() -> void:
	var pos: Vector3 = ball.global_position
	if abs(pos.z) > field_half_width:
		_schedule_throw_in(pos)
		return

	if abs(pos.x) > field_half_length:
		if abs(pos.z) <= goal_half_width:
			return # zona de gol, lo resuelve Area3D
		_schedule_goal_line_restart(pos)

func _schedule_throw_in(pos: Vector3) -> void:
	var restart_x := clamp(pos.x, -field_half_length + 1.2, field_half_length - 1.2)
	var restart_z: float = (1.0 if pos.z >= 0.0 else -1.0) * (field_half_width - 0.35)
	var receiving_side := -_resolve_last_touch_side(pos)
	_schedule_restart("Saque de banda (%s)" % _side_name(receiving_side), Vector3(restart_x, 0.35, restart_z))

func _schedule_goal_line_restart(pos: Vector3) -> void:
	var ball_out_right := pos.x > 0.0
	var defense_side := 1 if ball_out_right else -1
	var attack_side := -defense_side
	var touch_side := _resolve_last_touch_side(pos)
	var restart_pos := Vector3(defense_side * (field_half_length - 1.5), 0.35, clamp(pos.z, -3.5, 3.5))
	if touch_side == defense_side:
		restart_pos = Vector3(attack_side * (field_half_length - 1.4), 0.35, clamp(pos.z, -3.5, 3.5))
		_schedule_restart("Córner para %s" % _side_name(attack_side), restart_pos)
	else:
		_schedule_restart("Saque de meta para %s" % _side_name(defense_side), restart_pos)

func _resolve_last_touch_side(pos: Vector3) -> int:
	if last_touch_side == -1 or last_touch_side == 1:
		return last_touch_side
	# Si no hubo toque registrado (p.ej. rebote inicial), asumimos que atacaba
	# el equipo del lado desde donde salió la pelota.
	return 1 if pos.x > 0.0 else -1

func _check_foul_events() -> void:
	if foul_cooldown > 0.0 or dead_ball:
		return
	var carrier := _get_ball_carrier()
	if carrier == null:
		return

	var carrier_side := int(carrier.team_side)
	var foe := get_closest_opponent(carrier.global_position, carrier_side)
	if foe == null:
		return

	var dist := carrier.global_position.distance_to(foe.global_position)
	if dist > 1.2:
		return

	var relative_speed := (carrier.velocity - foe.velocity).length()
	if relative_speed < 6.2:
		return

	if abs(carrier.global_position.x) > field_half_length - 0.8:
		return

	foul_cooldown = 2.2
	var fouls_by_offender := _register_foul(-carrier_side)
	ball.linear_velocity = Vector3.ZERO
	if fouls_by_offender >= 6:
		_schedule_double_penalty(carrier_side)
	else:
		_schedule_restart("Falta para %s" % _side_name(carrier_side), Vector3(carrier.global_position.x, 0.35, carrier.global_position.z))

func _register_foul(side_committed: int) -> int:
	if side_committed < 0:
		home_fouls += 1
	else:
		away_fouls += 1
	_update_foul_label()
	return home_fouls if side_committed < 0 else away_fouls

func _update_foul_label() -> void:
	foul_label.text = "Faltas L/V: %d / %d" % [home_fouls, away_fouls]

func _schedule_double_penalty(awarded_side: int) -> void:
	var target_goal_x := -awarded_side * field_half_length
	var spot_x := target_goal_x + awarded_side * 10.0
	var spot := Vector3(clamp(spot_x, -field_half_length + 1.0, field_half_length - 1.0), 0.35, 0.0)
	_schedule_restart("Doble penalti para %s" % _side_name(awarded_side), spot)

func _update_change_label() -> void:
	change_label.text = "Cambios L/V: %d / %d" % [home_changes_left, away_changes_left]

func request_substitution(player_id: int) -> void:
	if _is_authority():
		_apply_substitution(player_id)
	else:
		rpc_id(1, "request_substitution_server", player_id)

@rpc("any_peer", "reliable")
func request_substitution_server(player_id: int) -> void:
	if not _is_authority():
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != player_id:
		return
	_apply_substitution(player_id)

func _apply_substitution(player_id: int) -> void:
	if not can_play() or not players.has(player_id):
		return
	var player: CharacterBody3D = players[player_id]
	var side := int(player.team_side)
	if side < 0:
		if home_changes_left <= 0:
			return
		home_changes_left -= 1
	else:
		if away_changes_left <= 0:
			return
		away_changes_left -= 1
	var candidate: CharacterBody3D = null
	var best_d := -1.0
	for bot in bots:
		if int(bot.team_side) != side:
			continue
		var d := bot.global_position.distance_to(ball.global_position)
		if d > best_d:
			best_d = d
			candidate = bot
	if candidate != null:
		var swap_pos := candidate.global_position
		candidate.global_position = player.global_position
		candidate.velocity = Vector3.ZERO
		player.global_position = swap_pos
	player.velocity = Vector3.ZERO
	player.stamina = player.max_stamina
	_update_change_label()
	event_label.text = "Cambio %s" % _side_name(side)

func _get_ball_carrier() -> Node3D:
	var nearest: Node3D = null
	var best := 1.35
	for raw_player in players.values():
		var p: Node3D = raw_player
		var d := p.global_position.distance_to(ball.global_position)
		if d < best:
			best = d
			nearest = p
	for b in bots:
		var d2 := b.global_position.distance_to(ball.global_position)
		if d2 < best:
			best = d2
			nearest = b
	return nearest

func _schedule_restart(reason: String, position: Vector3) -> void:
	if dead_ball:
		return
	dead_ball = true
	restart_timer = 1.0
	restart_reason = reason
	restart_position = position
	event_label.text = reason
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

func _apply_restart() -> void:
	dead_ball = false
	ball.global_position = restart_position
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	event_label.text = "%s | ¡Jueguen!" % restart_reason

func _side_name(side: int) -> String:
	if side < 0:
		return "Local"
	if side > 0:
		return "Visitante"
	return "Neutral"

func register_touch(side: int) -> void:
	last_touch_side = side

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

func _apply_kick(player_id: int, player_pos: Vector3, forward: Vector3, force: float, kick_range: float) -> void:
	if dead_ball or match_finished:
		return
	var to_ball: Vector3 = ball.global_position - player_pos
	if to_ball.length() > kick_range:
		return
	var dir: Vector3 = forward.normalized()
	if dir.length() <= 0.001:
		dir = to_ball.normalized()
	ball.apply_central_impulse(dir * force)
	if players.has(player_id):
		register_touch(int(players[player_id].team_side))
	event_label.text = "¡Remate!"

func apply_bot_kick(side: int, dir: Vector3, power: float) -> void:
	if dead_ball or match_finished:
		return
	register_touch(side)
	ball.apply_central_impulse(dir * power)

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

func _reset_player_and_bot_positions() -> void:
	for id_variant in players.keys():
		var id: int = int(id_variant)
		var side: int = int(players[id].team_side)
		players[id].global_position = _spawn_position_for_side(side, id)
		players[id].velocity = Vector3.ZERO
	for bot in bots:
		bot.anchor_position = _bot_anchor_by_role(int(bot.team_side), str(bot.role_name))
		bot.global_position = bot.anchor_position
		bot.velocity = Vector3.ZERO

func _reset_after_goal() -> void:
	match_finished = false
	dead_ball = false
	_reset_player_and_bot_positions()
	ball.global_position = Vector3(0.0, 0.35, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	if multiplayer.has_multiplayer_peer():
		rpc("sync_match_state", home_score, away_score, time_left, home_fouls, away_fouls, home_changes_left, away_changes_left)
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
func sync_match_state(home: int, away: int, clock_left: float, fouls_home: int, fouls_away: int, changes_home: int = 9, changes_away: int = 9) -> void:
	home_score = home
	away_score = away
	time_left = clock_left
	home_fouls = fouls_home
	away_fouls = fouls_away
	home_changes_left = changes_home
	away_changes_left = changes_away
	_update_foul_label()
	_update_change_label()
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
