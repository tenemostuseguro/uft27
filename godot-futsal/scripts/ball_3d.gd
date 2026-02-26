extends RigidBody3D

@export var friction := 0.985
@export var max_speed := 18.0

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	linear_velocity *= friction
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
