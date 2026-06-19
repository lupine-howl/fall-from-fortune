extends CharacterBody2D

# ---------------------------------------------------------
# CONSTANTS & EXPORTS
# ---------------------------------------------------------
@export var SPEED := 180.0
@export var LADDER_CLIMB_SPEED := 100.0 
@export var WALL_CLIMB_SPEED := 100.0   
@export var JUMP_VELOCITY := -600.0
@export var DOUBLE_JUMP_VELOCITY := -600.0
@export var ROLL_BOOST := 400.0
@export var DASH_BOOST := 400.0
@export var attack_damage := 25.0

@export_category("Water Settings")
@export var water_gravity_multiplier := 0.35  
@export var water_swim_velocity := -350.0     
@export var water_terminal_velocity := 200.0   
@export var water_speed_multiplier := 0.60     

@export_category("Environmental Friction")
@export var grounded_horizontal_current_dampening := 0.25 

# ---------------------------------------------------------
# STATES
# ---------------------------------------------------------
# LEDGE MODIFICATION: Added LEDGE_CLIMBING state
enum MoveState {
	GROUNDED, JUMPING, FALLING, DOUBLE_JUMPING, ROLLING, DASHING, KNOCKBACK, LADDER_CLIMBING, WALL_CLIMBING, LEDGE_CLIMBING
}

var state: MoveState = MoveState.GROUNDED
var is_dead := false
var is_invincible := false 
var facing := 1 
var knockback_timer := 0.0

var attack_buffer := 0.15
var attack_timer := 0.0
var can_double_jump := true
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var roll_timer := 0.0
var dash_timer := 0.0
var spawn_point
var is_submerged := false 
var is_on_ladder := false 

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
@onready var sprite_pivot := $SpritePivot
@onready var anim_tree := $AnimationTree
@onready var hazard_detector := $SpritePivot/HazardDetector
@onready var sprite_upper := $SpritePivot/SpriteContainer/SpriteUpper
@onready var sprite_lower := $SpritePivot/SpriteContainer/SpriteLower
@onready var attack_area := $SpritePivot/AttackArea
@onready var wall_detector := $SpritePivot/WallDetector 
@onready var ledge_detector := $SpritePivot/LedgeDetector # LEDGE MODIFICATION

func _ready() -> void:
	spawn_point = global_position 
	anim_tree.active = true
	_reset_animation_states()
	GameManager.hp_changed.connect(_on_hp_changed)

func take_damage(knockback_dir: Vector2, force: float):
	if is_invincible: return
	
	state = MoveState.KNOCKBACK
	knockback_timer = 0.2
	velocity = knockback_dir * force
	is_invincible = true
	
	var original_modulate = modulate
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.1)
	tween.tween_property(self, "modulate", original_modulate, 0.1)
	
	if not is_inside_tree(): 
		return
	await get_tree().create_timer(0.5).timeout
	is_invincible = false

func _physics_process(delta: float) -> void:
	if velocity.y > 10000:
		die()
	
	if is_dead:
		_apply_gravity(delta) 
		velocity.x *= 0.9
		_move(); return

	if state == MoveState.KNOCKBACK:
		knockback_timer -= delta
		if knockback_timer <= 0: state = MoveState.GROUNDED
		_apply_gravity(delta) 
		move_and_slide(); return

	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")

	# LEDGE MODIFICATION: Evaluate Ledge Grab Conditions
	var pressing_into_wall: bool = (direction != 0 and sign(direction) == facing)
	var touching_wall: bool = wall_detector and wall_detector.is_colliding()
	var over_ledge: bool = ledge_detector and not ledge_detector.is_colliding()
	
	# Can trigger from jumping/falling near an edge, or climbing up a wall to the top
	if state != MoveState.LEDGE_CLIMBING and touching_wall and over_ledge and not is_on_floor():
		if pressing_into_wall or state == MoveState.WALL_CLIMBING:
			start_ledge_climb()

	var can_wall_climb: bool = wall_detector and wall_detector.is_colliding() and not is_on_floor()
	if can_wall_climb and state != MoveState.WALL_CLIMBING and state != MoveState.LEDGE_CLIMBING and pressing_into_wall:
		state = MoveState.WALL_CLIMBING

	if is_on_ladder and state != MoveState.LADDER_CLIMBING and y_dir != 0:
		state = MoveState.LADDER_CLIMBING

	# Lock directional facing while climbing walls, ladders, or ledges
	if state != MoveState.ROLLING and state != MoveState.DASHING and state != MoveState.WALL_CLIMBING and state != MoveState.LADDER_CLIMBING and state != MoveState.LEDGE_CLIMBING:
		if direction != 0:
			facing = -1 if direction < 0 else 1
			sprite_pivot.scale.x = facing

	if Input.is_action_just_pressed("ui_jump"): jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if Input.is_action_pressed("ui_attack"): attack_timer = attack_buffer
	else: attack_timer = max(attack_timer - delta, 0.0)

	var attacking := attack_timer > 0.0
	_set_state("attacking", attacking)

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
	else: coyote_timer = max(coyote_timer - delta, 0.0)
		
	if Input.is_action_just_pressed("ui_dash") and not is_submerged and state != MoveState.LADDER_CLIMBING and state != MoveState.WALL_CLIMBING and state != MoveState.LEDGE_CLIMBING:
		state = MoveState.DASHING
		dash_timer = 0.20
		velocity.x = facing * DASH_BOOST
		_set_state("dashing", true)

	# Movement Calculations per State
	if state == MoveState.LADDER_CLIMBING:
		velocity.y = y_dir * LADDER_CLIMB_SPEED
		velocity.x = direction * (SPEED * 0.5) 
	elif state == MoveState.WALL_CLIMBING:
		velocity.y = y_dir * WALL_CLIMB_SPEED
		velocity.x = 0 
	elif state == MoveState.LEDGE_CLIMBING:
		# LEDGE MODIFICATION: Velocity is managed completely by our Hoisting Tween sequence
		velocity = Vector2.ZERO
	elif state != MoveState.ROLLING and state != MoveState.DASHING:
		var current_target_speed := SPEED
		if is_submerged:
			current_target_speed *= water_speed_multiplier
			
		var horiz_gravity := get_gravity().x
		
		if direction != 0: 
			var gravity_influence_dir: float = sign(horiz_gravity) * direction
			var adaptive_target_speed: float = direction * current_target_speed
			
			if gravity_influence_dir > 0:
				adaptive_target_speed += horiz_gravity * 0.25
			elif gravity_influence_dir < 0:
				adaptive_target_speed += horiz_gravity * 0.25
				
			velocity.x = move_toward(velocity.x, adaptive_target_speed, SPEED * 8 * delta)
		else: 
			if is_on_floor():
				horiz_gravity *= grounded_horizontal_current_dampening
				
			var gravity_push_drift := horiz_gravity * 0.5
			velocity.x = move_toward(velocity.x, gravity_push_drift, current_target_speed * 8 * delta)

	if not is_on_floor() and velocity.y >= 0 and state != MoveState.LADDER_CLIMBING and state != MoveState.WALL_CLIMBING and state != MoveState.LEDGE_CLIMBING: 
		state = MoveState.FALLING

	match state:
		MoveState.GROUNDED:
			_set_state("on_ladder", false)
			_set_state("on_wall", false) 
			_set_state("on_ledge", false) # LEDGE MODIFICATION
			_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)
			_set_state("crouching", y_dir > 0)
			if attacking and y_dir > 0 and not is_submerged:
				state = MoveState.ROLLING; roll_timer = 0.25; velocity.x = facing * ROLL_BOOST; _set_state("rolling", true); return
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = water_swim_velocity if is_submerged else JUMP_VELOCITY
				state = MoveState.JUMPING; _set_state("jumping", true); return
			_set_state("running", direction != 0)
		
		MoveState.LADDER_CLIMBING:
			_set_state("on_ladder", true)
			_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)
			
			var is_moving := (y_dir != 0 or direction != 0)
			if is_moving: anim_tree["parameters/ClimbScale/scale"] = 1.0
			else: anim_tree["parameters/ClimbScale/scale"] = 0.0
			
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = JUMP_VELOCITY
				state = MoveState.JUMPING
				_set_state("on_ladder", false)
				anim_tree["parameters/ClimbScale/scale"] = 1.0
				_set_state("jumping", true)
				return
				
			if is_on_floor() and y_dir > 0:
				state = MoveState.GROUNDED
				anim_tree["parameters/ClimbScale/scale"] = 1.0
				return

		MoveState.WALL_CLIMBING:
			_set_state("on_wall", true)
			_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)
			
			if y_dir != 0: anim_tree["parameters/ClimbScale/scale"] = 1.0
			else: anim_tree["parameters/ClimbScale/scale"] = 0.0
			
			var pulling_away: bool = (direction != 0 and sign(direction) != facing)
			if not wall_detector.is_colliding() or pulling_away:
				state = MoveState.FALLING
				anim_tree["parameters/ClimbScale/scale"] = 1.0
				_set_state("on_wall", false)
				return
				
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = JUMP_VELOCITY * 0.85
				velocity.x = -facing * SPEED * 2.0 
				facing = -facing
				sprite_pivot.scale.x = facing 
				
				state = MoveState.JUMPING
				anim_tree["parameters/ClimbScale/scale"] = 1.0
				_set_state("on_wall", false)
				_set_state("jumping", true)
				return
				
			if is_on_floor():
				state = MoveState.GROUNDED
				anim_tree["parameters/ClimbScale/scale"] = 1.0
				return

		MoveState.LEDGE_CLIMBING:
			# LEDGE MODIFICATION: Simply keep animation conditions active while tween operates
			_set_state("on_ledge", true)
			_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)

		MoveState.JUMPING:
			_set_state("on_ladder", false)
			_set_state("on_wall", false) 
			_set_state("on_ledge", false) # LEDGE MODIFICATION
			_set_state("jumping", true)
			_set_state("falling", false)
			if velocity.y > 0: state = MoveState.FALLING
			if jump_buffer_timer > 0:
				if is_submerged:
					jump_buffer_timer = 0
					velocity.y = water_swim_velocity
				elif can_double_jump:
					jump_buffer_timer = 0; can_double_jump = false; velocity.y = DOUBLE_JUMP_VELOCITY; state = MoveState.DOUBLE_JUMPING; _set_state("double_jumping", true); return
		MoveState.DOUBLE_JUMPING:
			_set_state("double_jumping", true)
			if velocity.y > 0: state = MoveState.FALLING
			if jump_buffer_timer > 0 and is_submerged:
				jump_buffer_timer = 0
				velocity.y = water_swim_velocity
				state = MoveState.JUMPING
		MoveState.FALLING:
			_set_state("on_ladder", false)
			_set_state("on_wall", false) 
			_set_state("on_ledge", false) # LEDGE MODIFICATION
			_set_state("falling", true)
			_set_state("jumping", false)
			if is_on_floor(): state = MoveState.GROUNDED; return
			if jump_buffer_timer > 0:
				if is_submerged:
					jump_buffer_timer = 0
					velocity.y = water_swim_velocity
					state = MoveState.JUMPING; return
				elif can_double_jump:
					jump_buffer_timer = 0; can_double_jump = false; velocity.y = DOUBLE_JUMP_VELOCITY; state = MoveState.DOUBLE_JUMPING; _set_state("double_jumping", true); return
		MoveState.ROLLING:
			roll_timer -= delta; _set_state("rolling", true)
			if roll_timer <= 0: _set_state("rolling", false); state = MoveState.GROUNDED; return
		MoveState.DASHING:
			dash_timer -= delta; _set_state("dashing", true)
			if dash_timer <= 0: _set_state("dashing", false); state = MoveState.GROUNDED; return

	_apply_gravity(delta)
	_move()

# MODIFIED: Snaps the player into place and lets the AnimationPlayer take over visuals
func start_ledge_climb() -> void:
	state = MoveState.LEDGE_CLIMBING
	velocity = Vector2.ZERO
	
	# Get the exact intersection corner point of the wall
	var wall_intersection_pt: Vector2 = wall_detector.get_collision_point()
	
	# Lock the physics body to the exact starting anchor point relative to the ledge.
	# Tune these two numbers so the character's hands perfectly grip the corner on frame 1.
	global_position.x = wall_intersection_pt.x - (facing * 1.0)
	global_position.y = wall_intersection_pt.y + 12.0 
	
	# Trigger the animation tree state
	_set_state("on_ledge", true)
	_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)


# NEW: Call this function from the VERY LAST FRAME of your AnimationPlayer track
func finalize_ledge_climb() -> void:
	# 1. Figure out where the visuals ended up relative to the physics anchor
	# Adjust these values to match where your animation visually landed the player on the platform
	var horizontal_vault_distance := 16.0 * facing
	var vertical_vault_distance := -40.0
	
	# 2. Teleport the actual physics collider safely onto the top of the platform
	global_position.x += horizontal_vault_distance
	global_position.y += vertical_vault_distance
	
	# 3. Reset visual sprite offsets back to local Vector2.ZERO instantly 
	# (so they align perfectly with the new physics body position)
	sprite_upper.position = Vector2.ZERO
	sprite_lower.position = Vector2.ZERO
	
	# 4. Return control back to regular physics processing
	state = MoveState.GROUNDED
	_reset_animation_states()
	
func _apply_gravity(delta: float) -> void:
	# Keep gravity disabled during your custom ledge vaulting tween sequence
	if state == MoveState.LADDER_CLIMBING or state == MoveState.WALL_CLIMBING or state == MoveState.LEDGE_CLIMBING:
		return

	var current_gravity := get_gravity()
	var default_gravity_y: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	if current_gravity.x != 0:
		var applied_horiz_force = current_gravity.x
		var direction := Input.get_axis("ui_left", "ui_right")
		if is_on_floor() and direction == 0:
			applied_horiz_force *= grounded_horizontal_current_dampening
			
		velocity.x += applied_horiz_force * delta

	var has_vertical_current := current_gravity.y != default_gravity_y
	
	if has_vertical_current and current_gravity.y < 0:
		velocity.y += current_gravity.y * delta
	elif not is_on_floor():
		if has_vertical_current:
			velocity.y += current_gravity.y * delta
		elif is_submerged:
			velocity.y += current_gravity.y * water_gravity_multiplier * delta
			if velocity.y > water_terminal_velocity:
				velocity.y = water_terminal_velocity
		else:
			velocity.y += current_gravity.y * delta

func _set_state(name: String, value: bool) -> void:
	var pos := "is_" + name; var neg := "is_not_" + name
	anim_tree["parameters/LowerState/conditions/" + pos] = value
	anim_tree["parameters/LowerState/conditions/" + neg] = !value
	anim_tree["parameters/UpperState/conditions/" + pos] = value
	anim_tree["parameters/UpperState/conditions/" + neg] = !value

func _reset_animation_states() -> void:
	if anim_tree and "parameters/ClimbScale/scale" in anim_tree:
		anim_tree["parameters/ClimbScale/scale"] = 1.0
		
	_set_state("on_ladder", false) 
	_set_state("on_wall", false) 
	_set_state("on_ledge", false) # LEDGE MODIFICATION
	_set_state("jumping", false); _set_state("falling", false); _set_state("double_jumping", false)
	_set_state("running", false); _set_state("crouching", false); _set_state("attacking", false)
	_set_state("rolling", false); _set_state("dead", false); _set_state("dashing", false)

func _move() -> void:
	move_and_slide(); check_slide_hazards(); check_area_hazards()

func _process_attack():
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
		if body.has_method("take_damage"):
			print(body)
			body.take_damage(attack_damage,(body.global_position - global_position).normalized() * 300)

func check_slide_hazards() -> void:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i); var collider = col.get_collider()
		if collider and collider.is_in_group("hazards"): die()

func check_area_hazards() -> void:
	if hazard_detector:
		var overlapping_areas = hazard_detector.get_overlapping_areas()
		
		for area in overlapping_areas:
			if area.is_in_group("hazards"): 
				die()
				return
		
		var touching_ladder := false
		for area in overlapping_areas:
			if area.is_in_group("ladders"):
				touching_ladder = true
				break
		
		is_on_ladder = touching_ladder
		if not is_on_ladder and state == MoveState.LADDER_CLIMBING:
			state = MoveState.FALLING
			
		var bodies = hazard_detector.get_overlapping_bodies()
		var currently_in_water := false
		
		for body in bodies:
			if body is TileMapLayer:
				currently_in_water = true
				break
		
		if currently_in_water and not is_submerged:
			if velocity.y > 0:
				velocity.y *= 0.2
				
		is_submerged = currently_in_water
		
func die() -> void:
	if is_dead: return

	is_dead = true
	is_submerged = false 
	_reset_animation_states()
	_set_state("dead", true)
	velocity = Vector2.ZERO

	await get_tree().create_timer(1.2).timeout
	
	is_dead = false
	_reset_animation_states()
	state = MoveState.GROUNDED
	
	GameManager.trigger_player_respawn()
	
func _on_hp_changed(new_hp: float) -> void:
	if new_hp <= 0 and not is_dead: die()
