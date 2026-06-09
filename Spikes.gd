extends CharacterBody2D
@export var damage := 100.0

func _on_hit_box_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			var knockback = (body.global_position - global_position).normalized()
			body.take_damage(knockback, 400.0)
		
		# Assuming you want instant death for the spike/bomb interaction
		if body.has_method("die"):
			body.die()
		else:
			GameManager.take_damage(damage)
			
		#queue_free()
