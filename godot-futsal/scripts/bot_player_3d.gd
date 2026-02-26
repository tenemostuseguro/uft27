extends CharacterBody3D

@export var team_side := -1 # -1 home / 1 away
@export var role_name := "Cierre"
@export var is_rival := false
@export var bot_name := "BOT"
@export var move_speed := 7.2
@export var kick_force := 8.8
@export var kick_range := 1.8

var manager: GameManager3D = null
var anchor_position := Vector3.ZERO

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	if is_rival:
		mesh.material_override = _material(Color(1.0, 0.56, 0.25))
	else:
		mesh.material_override = _material(Color(0.12, 0.8, 0.95))

func _physics_process(delta: float) -> void:
	if manager == null or not manager._is_authority():
		return

	var ball_pos: Vector3 = manager.ball.global_position
	var move_target: Vector3 = _decide_target(ball_pos, delta)
	var move_dir: Vector3 = move_target - global_position
	move_dir.y = 0.0

	if move_dir.length() > 0.1:
		velocity = move_dir.normalized() * _role_speed_multiplier() * move_speed
		look_at(global_position + move_dir.normalized(), Vector3.UP)
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	_try_action_with_ball(ball_pos)

	if multiplayer.has_multiplayer_peer():
		rpc("sync_state", global_position, rotation.y, velocity)

func _decide_target(ball_pos: Vector3, _delta: float) -> Vector3:
	var target: Vector3 = anchor_position
	var to_ball: Vector3 = ball_pos - global_position
	var ball_dist := to_ball.length()

	match role_name:
		"GK":
			target = manager.get_defend_goal_position(team_side)
			target.z = clamp(ball_pos.z, -3.8, 3.8)
			if ball_dist < 5.0:
				target = ball_pos
		"Cierre":
			var danger_line := manager.get_defend_goal_position(team_side).x + (team_side * -3.0)
			target = Vector3(danger_line, 0.0, clamp(ball_pos.z, -6.0, 6.0))
			if ball_dist < 10.0:
				target = ball_pos
		"Ala Izq", "Ala Der":
			var wing_bias := -4.8 if role_name == "Ala Izq" else 4.8
			target = anchor_position
			target.z = lerp(anchor_position.z, wing_bias, 0.7)
			if ball_dist < 11.0:
				target = ball_pos + Vector3(-team_side * 1.2, 0.0, wing_bias * 0.12)
		"Pivot":
			var attack_goal := manager.get_attack_goal_position(team_side)
			target = Vector3(attack_goal.x * 0.72, 0.0, clamp(ball_pos.z * 0.6, -5.0, 5.0))
			if ball_dist < 12.0:
				target = ball_pos
		_:
			if ball_dist < 9.0:
				target = ball_pos

	if _is_offside_like(target):
		target.x = global_position.x - team_side * 1.2

	return target

func _try_action_with_ball(ball_pos: Vector3) -> void:
	var to_ball: Vector3 = ball_pos - global_position
	if to_ball.length() > kick_range:
		return

	var attack_goal: Vector3 = manager.get_attack_goal_position(team_side)
	var nearest_opponent: Node3D = manager.get_closest_opponent(global_position, team_side)
	var enemy_close := nearest_opponent != null and global_position.distance_to(nearest_opponent.global_position) < 3.0

	if role_name == "GK":
		var clear_dir: Vector3 = (attack_goal - manager.ball.global_position).normalized()
		manager.ball.apply_central_impulse(clear_dir * (kick_force + 2.0))
		return

	if enemy_close and role_name != "Pivot":
		var mate: Node3D = manager.get_closest_teammate(global_position, team_side, self)
		if mate != null:
			var pass_dir: Vector3 = (mate.global_position - manager.ball.global_position).normalized()
			manager.ball.apply_central_impulse(pass_dir * (kick_force - 1.2))
			return

	var shot_dir: Vector3 = (attack_goal - manager.ball.global_position).normalized()
	var shot_power := kick_force
	if role_name == "Pivot":
		shot_power += 1.8
	elif role_name == "Cierre":
		shot_power -= 0.8

	manager.ball.apply_central_impulse(shot_dir * shot_power)

func _is_offside_like(target: Vector3) -> bool:
	# Regla simple para que no rompan la estructura: el pivot no puede quedarse pegado al arco rival todo el tiempo.
	if role_name != "Pivot":
		return false
	var limit_x := manager.field_half_length * 0.9 * -team_side
	return (team_side < 0 and target.x > limit_x) or (team_side > 0 and target.x < limit_x)

func _role_speed_multiplier() -> float:
	match role_name:
		"GK":
			return 0.85
		"Cierre":
			return 0.95
		"Pivot":
			return 1.05
		_:
			return 1.0

@rpc("authority", "unreliable")
func sync_state(pos: Vector3, yaw: float, vel: Vector3) -> void:
	if manager != null and manager._is_authority():
		return
	global_position = pos
	rotation.y = yaw
	velocity = vel

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
