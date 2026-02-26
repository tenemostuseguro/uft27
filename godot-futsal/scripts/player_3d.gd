extends CharacterBody3D

@export var move_speed := 7.5
@export var sprint_multiplier := 1.45
@export var player_id := 1
@export var kick_force := 8.0
@export var kick_range := 2.2

var local_control := false
var manager: Node = null

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	if player_id == 1:
		mesh.material_override = _material(Color(0.2, 0.5, 1.0))
	else:
		mesh.material_override = _material(Color(1.0, 0.35, 0.25))

func _physics_process(_delta: float) -> void:
	if local_control:
		_process_local_input()
		rpc_unreliable("sync_remote_state", global_position, rotation.y, velocity)

func _process_local_input() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	var speed := move_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0
	move_and_slide()

	if direction.length() > 0.05:
		look_at(global_position + direction, Vector3.UP)

	if Input.is_action_just_pressed("shoot") and manager != null:
		manager.request_kick_from_player(player_id, global_position, -global_transform.basis.z, kick_force, kick_range)

@rpc("any_peer", "unreliable")
func sync_remote_state(pos: Vector3, yaw: float, vel: Vector3) -> void:
	if local_control:
		return
	global_position = pos
	rotation.y = yaw
	velocity = vel

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
