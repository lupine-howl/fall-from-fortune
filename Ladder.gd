extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Check if the body that entered is the player by looking for our helper function
	if body.has_method("set_on_ladder"):
		body.set_on_ladder(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_on_ladder"):
		body.set_on_ladder(false)
