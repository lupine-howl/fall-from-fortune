extends PlayerState

func enter() -> void:
	player._reset_animation_states()
	
	if player.state == player.MoveState.LEDGE_CLIMBING:
		player.velocity = Vector2.ZERO
		var wall_intersection_pt: Vector2 = player.wall_detector.get_collision_point()
		player.global_position.x = wall_intersection_pt.x - (player.facing * 1.0)
		player.global_position.y = wall_intersection_pt.y + 12.0 
		player._set_state("on_ledge", true)
		player._set_state("on_ground", false)
		player._set_state("falling", false); player._set_state("jumping", false); player._set_state("double_jumping", false)

func physics_update(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")
	
	match player.state:
		player.MoveState.LADDER_CLIMBING:
			player._set_state("on_ground", false) 
			player._set_state("on_ladder", true)
			player._set_state("falling", false); player._set_state("jumping", false); player._set_state("double_jumping", false)
			
			var is_moving := (y_dir != 0 or direction != 0)
			player.anim_tree["parameters/ClimbScale/scale"] = 1.0 if is_moving else 0.0
			
			player.velocity.y = y_dir * player.LADDER_CLIMB_SPEED
			player.velocity.x = direction * (player.SPEED * 0.5)
			
			if player.jump_buffer_timer > 0:
				player.jump_buffer_timer = 0
				player.velocity.y = player.JUMP_VELOCITY
				player.anim_tree["parameters/ClimbScale/scale"] = 1.0
				player._set_state("on_ladder", false)
				player._change_state(player.MoveState.JUMPING)
				return
				
			if player.is_on_floor() and y_dir > 0:
				player._change_state(player.MoveState.GROUNDED)
				player.anim_tree["parameters/ClimbScale/scale"] = 1.0
				return

		player.MoveState.WALL_CLIMBING:
			player._set_state("on_ground", false) 
			player._set_state("on_wall", true)
			player._set_state("falling", false); player._set_state("jumping", false); player._set_state("double_jumping", false)
			player._set_state("running", false) 
			player._set_state("wall_climbing", y_dir != 0)
			
			player.velocity.y = y_dir * player.WALL_CLIMB_SPEED
			player.velocity.x = 0 
			
			var pulling_away: bool = (direction != 0 and sign(direction) != player.facing)
			if not player.wall_detector.is_colliding() or pulling_away:
				player._set_state("on_wall", false)
				player._set_state("wall_climbing", false) 
				player._change_state(player.MoveState.FALLING)
				return
				
			if player.jump_buffer_timer > 0:
				player.jump_buffer_timer = 0
				player.velocity.y = player.JUMP_VELOCITY * 0.85
				player.velocity.x = -player.facing * player.SPEED * 2.0 
				player.facing = -player.facing
				player.sprite_pivot.scale.x = player.facing 
				player.wall_jump_lock = 0.20
				
				player._set_state("on_wall", false)
				player._set_state("wall_climbing", false) 
				player._change_state(player.MoveState.JUMPING)
				return
				
			if player.is_on_floor():
				player._change_state(player.MoveState.GROUNDED)
				player._set_state("wall_climbing", false) 
				return
				
		player.MoveState.LEDGE_CLIMBING:
			player.velocity = Vector2.ZERO
