extends CharacterBody3D

@export var move_speed := 8.0
@export var sprint_multiplier := 1.5
@export var player_id := 1
@export var team_side := -1 # -1: local/home, 1: away
@export var kick_force := 9.0
@export var kick_range := 2.0
@export var max_stamina := 100.0
@export var stamina_recovery := 18.0
@export var stamina_sprint_cost := 28.0

var local_control := false
var manager: GameManager3D = null
var stamina := 100.0
var change_cooldown := 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	stamina = max_stamina
	if local_control and MatchConfig.template_ready:
		mesh.material_override = _material(MatchConfig.primary_color)
	elif team_side < 0:
		mesh.material_override = _material(Color(0.2, 0.5, 1.0))
	else:
		mesh.material_override = _material(Color(1.0, 0.35, 0.25))

func _physics_process(delta: float) -> void:
	change_cooldown = max(0.0, change_cooldown - delta)
	if local_control:
		if manager != null and not manager.can_play():
			velocity = Vector3.ZERO
			stamina = min(max_stamina, stamina + stamina_recovery * delta)
			return
		_process_local_input(delta)
		if _can_sync_remote_state():
			rpc("sync_remote_state", global_position, rotation.y, velocity, stamina)

func _process_local_input(delta: float) -> void:
	var key_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var mobile_input := Vector2.ZERO
	if manager != null:
		mobile_input = manager.get_mobile_move_vector()

	var final_input := key_input
	if mobile_input.length() > final_input.length():
		final_input = mobile_input

	var direction := Vector3(final_input.x, 0.0, final_input.y)
	var speed := move_speed
	var mobile_sprint := manager != null and manager.is_mobile_sprint_pressed()
	var can_sprint := (Input.is_action_pressed("sprint") or mobile_sprint) and stamina > 1.0 and direction.length() > 0.01
	if can_sprint:
		speed *= sprint_multiplier
		stamina = max(0.0, stamina - stamina_sprint_cost * delta)
	else:
		stamina = min(max_stamina, stamina + stamina_recovery * delta)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0
	move_and_slide()

	if manager != null:
		global_position.x = clamp(global_position.x, -manager.field_half_length + 0.4, manager.field_half_length - 0.4)
		global_position.z = clamp(global_position.z, -manager.field_half_width + 0.4, manager.field_half_width - 0.4)

	if direction.length() > 0.05:
		look_at(global_position + direction, Vector3.UP)

	var wants_change := Input.is_key_pressed(KEY_C) or (manager != null and manager.consume_mobile_change())
	if wants_change and manager != null and change_cooldown <= 0.0:
		manager.request_substitution(player_id)
		change_cooldown = 0.35

	var mobile_shoot := manager != null and manager.consume_mobile_shoot()
	if (Input.is_action_just_pressed("shoot") or mobile_shoot) and manager != null:
		manager.request_kick_from_player(player_id, global_position, -global_transform.basis.z, kick_force, kick_range)

func _can_sync_remote_state() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

@rpc("any_peer", "unreliable")
func sync_remote_state(pos: Vector3, yaw: float, vel: Vector3, remote_stamina: float) -> void:
	if local_control:
		return
	global_position = pos
	rotation.y = yaw
	velocity = vel
	stamina = remote_stamina

func stamina_ratio() -> float:
	if max_stamina <= 0.01:
		return 0.0
	return stamina / max_stamina

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
