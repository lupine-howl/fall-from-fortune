extends CharacterBody2D

@export var speed := 200.0
@export var damage := 16.0
@export var lifetime_after_bounce := 3.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var has_hit_floor := false
var despawn_timer := 0.0

# NEW: Pass in an initial push
func set_initial_velocity(initial_vel: Vector2):
	velocity = initial_vel

func _physics_process(delta):
	velocity.y += gravity * delta
	
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		if collision.get_collider().is_in_group("player"):
			if collision.get_collider().has_method("take_damage"):
				var knockback = (collision.get_collider().global_position - global_position).normalized()
				collision.get_collider().take_damage(knockback, 400.0)
			GameManager.take_damage(damage)
			queue_free()
		else:
			velocity = velocity.bounce(collision.get_normal()) * 0.5
			if collision.get_normal().y < 0:
				has_hit_floor = true
	
	if has_hit_floor:
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		despawn_timer += delta
		modulate.a = lerp(1.0, 0.0, despawn_timer / lifetime_after_bounce)
		if despawn_timer >= lifetime_after_bounce:
			queue_free()
