extends Area2D


func _ready() -> void:
	# Rotates the internal gravity direction vector to match the node's rotation
	gravity_direction = Vector2.UP.rotated(rotation)
