extends CharacterBody2D

# ---------------------------------------------------------
# CONSTANTS & EXPORTS
# ---------------------------------------------------------
@export var SPEED := 300.0
@export var JUMP_VELOCITY := -800.0
@export var DOUBLE_JUMP_VELOCITY := -800.0
@export var ROLL_BOOST := 400.0
@export var DASH_BOOST := 400.0
@export var attack_damage := 25.0

@export_category("Water Settings")
@export var water_gravity_multiplier := 0.35  # 35% of normal gravity for floaty physics
@export var water_swim_velocity := -350.0     # Upward force applied when swimming/tapping jump
@export var water_terminal_velocity := 200.0   # Caps how fast the player can sink down
@export var water_speed_multiplier := 0.60     # Moves at 60% normal speed when wading/swimming

@export_category("Environmental Friction")
@export var grounded_horizontal_current_dampening := 0.25 # Ground friction absorbs 75% of force when still

# ---------------------------------------------------------
# STATES
# ---------------------------------------------------------
enum MoveState {
	GROUNDED, JUMPING, FALLING, DOUBLE_JUMPING, ROLLING, DASHING, KNOCKBACK
}

var state: MoveState = MoveState.GROUNDED
var is_dead := false
var is_invincible := false # Added to prevent rapid-fire damage
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
var is_submerged := false # Tracks if the player is currently underwater

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

@onready var hazard_detector := $HazardDetector
@onready var anim_tree := $AnimationTree
@onready var sprite_upper := $SpriteUpper
@onready var sprite_lower := $SpriteLower
@onready var attack_area := $AttackArea

func _ready() -> void:
	spawn_point = global_position # Save the starting spot
	anim_tree.active = true
	_reset_animation_states()
	GameManager.hp_changed.connect(_on_hp_changed)
	
func take_damage(knockback_dir: Vector2, force: float):
	if is_invincible: return
	
	state = MoveState.KNOCKBACK
	knockback_timer = 0.2
	velocity = knockback_dir * force
	is_invincible = true
	
	# Flash effect
	var original_modulate = modulate
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.1)
	tween.tween_property(self, "modulate", original_modulate, 0.1)
	
	# Invincibility frames
	await get_tree().create_timer(0.5).timeout
	is_invincible = false

func _physics_process(delta: float) -> void:
	if velocity.y > 10000:
		die()
	
	if is_dead:
		_apply_gravity(delta) 
		velocity.x *= 0.9
		_move(); return

	# Handle Knockback state
	if state == MoveState.KNOCKBACK:
		knockback_timer -= delta
		if knockback_timer <= 0: state = MoveState.GROUNDED
		_apply_gravity(delta) 
		move_and_slide(); return

	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")

	if state != MoveState.ROLLING and state != MoveState.DASHING:
		if direction != 0:
			facing = -1 if direction < 0 else 1
			sprite_upper.scale.x = facing
			sprite_lower.scale.x = facing

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
		
	# Block ground-dashing while swimming through open water
	if Input.is_action_just_pressed("ui_dash") and not is_submerged:
		state = MoveState.DASHING
		dash_timer = 0.20
		velocity.x = facing * DASH_BOOST
		_set_state("dashing", true)

	# Calculate current movement velocity, scaling limits adaptively based on horizontal gravity
	if state != MoveState.ROLLING and state != MoveState.DASHING:
		var current_target_speed := SPEED
		if is_submerged:
			current_target_speed *= water_speed_multiplier
			
		var horiz_gravity := get_gravity().x
		
		if direction != 0: 
			var gravity_influence_dir: float = sign(horiz_gravity) * direction
			var adaptive_target_speed: float = direction * current_target_speed
			
			# Running: Receive 100% full gravity impact on top-speed calculations
			if gravity_influence_dir > 0:
				adaptive_target_speed += horiz_gravity * 0.25
			elif gravity_influence_dir < 0:
				adaptive_target_speed += horiz_gravity * 0.25
				
			velocity.x = move_toward(velocity.x, adaptive_target_speed, SPEED * 8 * delta)
		else: 
			# Grounded & Bracing Still: Apply the friction dampener here to restrict sliding away
			if is_on_floor():
				horiz_gravity *= grounded_horizontal_current_dampening
				
			var gravity_push_drift := horiz_gravity * 0.5
			velocity.x = move_toward(velocity.x, gravity_push_drift, current_target_speed * 8 * delta)

	if not is_on_floor() and velocity.y >= 0: state = MoveState.FALLING

	match state:
		MoveState.GROUNDED:
			_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)
			_set_state("crouching", y_dir > 0)
			# Block rolling underwater
			if attacking and y_dir > 0 and not is_submerged:
				state = MoveState.ROLLING; roll_timer = 0.25; velocity.x = facing * ROLL_BOOST; _set_state("rolling", true); return
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = water_swim_velocity if is_submerged else JUMP_VELOCITY
				state = MoveState.JUMPING; _set_state("jumping", true); return
			_set_state("running", direction != 0)
		MoveState.JUMPING:
			_set_state("falling", true)
			_set_state("jumping", true)
			_set_state("falling", false)
			if velocity.y > 0: state = MoveState.FALLING
			if jump_buffer_timer > 0:
				if is_submerged: # Allow continuous swimming inputs
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

func _apply_gravity(delta: float) -> void:
	var current_gravity := get_gravity()
	var default_gravity_y: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	# 1. Handle horizontal currents/forces
	if current_gravity.x != 0:
		var applied_horiz_force = current_gravity.x
		var direction := Input.get_axis("ui_left", "ui_right")
		if is_on_floor() and direction == 0:
			applied_horiz_force *= grounded_horizontal_current_dampening
			
		velocity.x += applied_horiz_force * delta

	# 2. Handle vertical currents/gravity split
	var has_vertical_current := current_gravity.y != default_gravity_y
	
	# If an Area2D is actively pulling or blasting us UPWARDS, apply it unconditionally!
	if has_vertical_current and current_gravity.y < 0:
		velocity.y += current_gravity.y * delta
	# Otherwise, run normal downward gravity configurations only when airborne
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
		for area in hazard_detector.get_overlapping_areas():
			if area.is_in_group("hazards"): die(); return
			
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
	
	global_position = spawn_point
	state = MoveState.GROUNDED
	
	GameManager.reset_health()
	get_tree().reload_current_scene()

func _on_hp_changed(new_hp: float) -> void:
	if new_hp <= 0 and not is_dead: die()
