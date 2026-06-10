extends Area2D

func _on_body_entered(body):
	#print(body)
	if body.is_in_group("player"):
		GameManager.add_health(16.0)
		queue_free()
