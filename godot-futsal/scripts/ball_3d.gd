extends RigidBody3D

@export var friction := 0.987
@export var max_speed := 19.0
@export var min_speed_stop := 0.08

func _physics_process(_delta: float) -> void:
	var has_peer := multiplayer.has_multiplayer_peer()
	if has_peer and not multiplayer.is_server():
		return

	linear_velocity.y = 0.0
	linear_velocity *= friction

	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	elif linear_velocity.length() < min_speed_stop:
		linear_velocity = Vector3.ZERO
