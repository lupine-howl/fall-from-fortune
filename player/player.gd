extends CharacterBody2D

# ---------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------
const SPEED := 300.0
const JUMP_VELOCITY := -800.0
const DOUBLE_JUMP_VELOCITY := -800.0

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

const ROLL_BOOST := 400.0
const DASH_BOOST := 400.0

# ---------------------------------------------------------
# STATES
# ---------------------------------------------------------
enum MoveState {
	GROUNDED,
	JUMPING,
	FALLING,
	DOUBLE_JUMPING,
	ROLLING,
	DASHING
}

var state: MoveState = MoveState.GROUNDED

var is_dead := false
var facing := 1  # 1 = right, -1 = left

# Attack debounce
var attack_buffer := 0.15
var attack_timer := 0.0

# Flags
var can_double_jump := true
var coyote_timer := 0.0
var jump_buffer_timer := 0.0

# Roll/Dash timers
var roll_timer := 0.0
var dash_timer := 0.0

# ---------------------------------------------------------
# NODE REFS
# ---------------------------------------------------------
@onready var hazard_detector := $HazardDetector
@onready var anim_tree := $AnimationTree
@onready var sprite_upper := $SpriteUpper
@onready var sprite_lower := $SpriteLower


func _ready() -> void:
	anim_tree.active = true
	_reset_animation_states()
	
	# Listen to the global health updates
	GameManager.hp_changed.connect(_on_hp_changed)


func _on_hp_changed(new_hp: float) -> void:
	# If health hits zero and we aren't already dead, trigger the death sequence
	if new_hp <= 0 and not is_dead:
		die()

# ---------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		_apply_gravity(delta)
		_move()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")

	# ---------------------------------------------------------
	# UPDATE FACING DIRECTION
	# ---------------------------------------------------------
	if state != MoveState.ROLLING and state != MoveState.DASHING:
		if direction != 0:
			facing = -1 if direction < 0 else 1
			sprite_upper.scale.x = facing
			sprite_lower.scale.x = facing

	# ---------------------------------------------------------
	# INPUT BUFFERS
	# ---------------------------------------------------------
	if Input.is_action_just_pressed("ui_jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	if Input.is_action_pressed("ui_attack"):
		attack_timer = attack_buffer
	else:
		attack_timer = max(attack_timer - delta, 0.0)

	var attacking := attack_timer > 0.0
	_set_state("attacking", attacking)  # <-- FIXED

	# ---------------------------------------------------------
	# COYOTE TIMER
	# ---------------------------------------------------------
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
		
	# ---------------------------------------------------------
	# DASH INPUT
	# ---------------------------------------------------------
	if Input.is_action_just_pressed("ui_dash"):
		state = MoveState.DASHING
		dash_timer = 0.20  # dash duration
		velocity.x = facing * DASH_BOOST
		_set_state("dashing", true)
		# No return — we want the loop to continue normally


	# ---------------------------------------------------------
	# HORIZONTAL MOVEMENT (ALWAYS ALLOWED)
	# ---------------------------------------------------------
	if state != MoveState.ROLLING and state != MoveState.DASHING:
		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)


	# Force falling state if we are in the air and moving downward/neutral
	if not is_on_floor() and velocity.y >= 0:
		state = MoveState.FALLING
	# ---------------------------------------------------------
	# STATE MACHINE
	# ---------------------------------------------------------
	match state:

		# -----------------------------------------------------
		# GROUNDED
		# -----------------------------------------------------
		MoveState.GROUNDED:
			_set_state("falling", false)
			_set_state("jumping", false)
			_set_state("double_jumping", false)

			# Crouch
			_set_state("crouching", y_dir > 0)

			# Roll
			if attacking and y_dir > 0:
				state = MoveState.ROLLING
				roll_timer = 0.25
				velocity.x = facing * ROLL_BOOST
				_set_state("rolling", true)
				return

			# Jump
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = JUMP_VELOCITY
				state = MoveState.JUMPING
				_set_state("jumping", true)
				return

			# Idle / Run
			_set_state("running", direction != 0)

		# -----------------------------------------------------
		# JUMPING
		# -----------------------------------------------------
		MoveState.JUMPING:
			_set_state("jumping", true)

			if velocity.y > 0:
				state = MoveState.FALLING

			# Double jump
			if jump_buffer_timer > 0 and can_double_jump:
				jump_buffer_timer = 0
				can_double_jump = false
				velocity.y = DOUBLE_JUMP_VELOCITY
				state = MoveState.DOUBLE_JUMPING
				_set_state("double_jumping", true)
				return

		# -----------------------------------------------------
		# DOUBLE JUMP (AIR SPIN)
		# -----------------------------------------------------
		MoveState.DOUBLE_JUMPING:
			_set_state("double_jumping", true)

			if velocity.y > 0:
				state = MoveState.FALLING

			attacking = false
			_set_state("attacking", false)

		# -----------------------------------------------------
		# FALLING
		# -----------------------------------------------------
		MoveState.FALLING:
			_set_state("falling", true)

			if is_on_floor():
				state = MoveState.GROUNDED
				return

			if jump_buffer_timer > 0 and can_double_jump:
				jump_buffer_timer = 0
				can_double_jump = false
				velocity.y = DOUBLE_JUMP_VELOCITY
				state = MoveState.DOUBLE_JUMPING
				_set_state("double_jumping", true)
				return

		# -----------------------------------------------------
		# ROLLING
		# -----------------------------------------------------
		MoveState.ROLLING:
			roll_timer -= delta
			_set_state("rolling", true)

			if roll_timer <= 0:
				_set_state("rolling", false)
				state = MoveState.GROUNDED
				return

		# -----------------------------------------------------
		# DASHING (SCAFFOLDED)
		# -----------------------------------------------------
		MoveState.DASHING:
			dash_timer -= delta
			_set_state("dashing", true)

			if dash_timer <= 0:
				_set_state("dashing", false)
				state = MoveState.GROUNDED
				return

	# ---------------------------------------------------------
	# APPLY MOVEMENT
	# ---------------------------------------------------------
	_apply_gravity(delta)
	_move()


# ----------------------------------------------------------
# STATE + ANIMATION HELPERS
# ----------------------------------------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _set_state(name: String, value: bool) -> void:
	var pos := "is_" + name
	var neg := "is_not_" + name

	
	anim_tree["parameters/LowerState/conditions/" + pos] = value
	anim_tree["parameters/LowerState/conditions/" + neg] = !value
	anim_tree["parameters/UpperState/conditions/" + pos] = value
	anim_tree["parameters/UpperState/conditions/" + neg] = !value


func _reset_animation_states() -> void:
	_set_state("jumping", false)
	_set_state("falling", false)
	_set_state("double_jumping", false)
	_set_state("running", false)
	_set_state("crouching", false)
	_set_state("attacking", false)
	_set_state("rolling", false)
	_set_state("dead", false)
	_set_state("dashing", false)


func _move() -> void:
	move_and_slide()
	check_slide_hazards()
	check_area_hazards()


func check_slide_hazards() -> void:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("hazards"):
			die()
			return


func check_area_hazards() -> void:
	if hazard_detector:
		for area in hazard_detector.get_overlapping_areas():
			if area.is_in_group("hazards"):
				die()
				return


func die() -> void:
	if is_dead:
		return

	is_dead = true
	_reset_animation_states()
	_set_state("dead", true)

	velocity = Vector2.ZERO

	await get_tree().create_timer(1.2).timeout
	GameManager.reset_health()
	get_tree().reload_current_scene()
