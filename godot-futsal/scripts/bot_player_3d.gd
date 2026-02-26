extends CharacterBody3D

@export var team_side := -1 # -1 home / 1 away
@export var bot_name := "BOT"
@export var move_speed := 6.8
@export var press_distance := 11.0
@export var hold_distance := 5.5
@export var kick_force := 8.5
@export var kick_range := 1.7

var manager: Node = null
var anchor_position := Vector3.ZERO

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	if team_side < 0:
		mesh.material_override = _material(Color(0.12, 0.75, 0.95))
	else:
		mesh.material_override = _material(Color(1.0, 0.55, 0.2))

func _physics_process(_delta: float) -> void:
	if manager == null or not multiplayer.is_server():
		return

	var ball := manager.ball
	var to_ball := ball.global_position - global_position
	var target := anchor_position

	if to_ball.length() < press_distance:
		target = ball.global_position
	elif (anchor_position - ball.global_position).length() < hold_distance:
		target = ball.global_position.lerp(anchor_position, 0.35)

	var flat_target := Vector3(target.x, global_position.y, target.z)
	var move_dir := flat_target - global_position
	move_dir.y = 0.0

	if move_dir.length() > 0.1:
		velocity = move_dir.normalized() * move_speed
		look_at(global_position + move_dir.normalized(), Vector3.UP)
	else:
		velocity = Vector3.ZERO

	move_and_slide()

	if to_ball.length() <= kick_range:
		var goal_target := Vector3(manager.field_half_length * -team_side, ball.global_position.y, 0.0)
		var kick_dir := (goal_target - ball.global_position).normalized()
		ball.apply_central_impulse(kick_dir * kick_force)

	rpc("sync_state", global_position, rotation.y)

@rpc("authority", "unreliable")
func sync_state(pos: Vector3, yaw: float) -> void:
	if multiplayer.is_server():
		return
	global_position = pos
	rotation.y = yaw

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
