extends CharacterBody2D

# ---------------------------------------------------------
# CONSTANTS & EXPORTS
# ---------------------------------------------------------
@export var SPEED := 300.0
@export var JUMP_VELOCITY := -800.0
@export var DOUBLE_JUMP_VELOCITY := -800.0
@export var ROLL_BOOST := 400.0
@export var DASH_BOOST := 400.0

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

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

@onready var hazard_detector := $HazardDetector
@onready var anim_tree := $AnimationTree
@onready var sprite_upper := $SpriteUpper
@onready var sprite_lower := $SpriteLower

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
	if is_dead:
		_apply_gravity(delta); _move(); return

	# Handle Knockback state
	if state == MoveState.KNOCKBACK:
		knockback_timer -= delta
		if knockback_timer <= 0: state = MoveState.GROUNDED
		_apply_gravity(delta); move_and_slide(); return

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
		
	if Input.is_action_just_pressed("ui_dash"):
		state = MoveState.DASHING
		dash_timer = 0.20
		velocity.x = facing * DASH_BOOST
		_set_state("dashing", true)

	if state != MoveState.ROLLING and state != MoveState.DASHING:
		if direction != 0: velocity.x = direction * SPEED
		else: velocity.x = move_toward(velocity.x, 0, SPEED)

	if not is_on_floor() and velocity.y >= 0: state = MoveState.FALLING

	match state:
		MoveState.GROUNDED:
			_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)
			_set_state("crouching", y_dir > 0)
			if attacking and y_dir > 0:
				state = MoveState.ROLLING; roll_timer = 0.25; velocity.x = facing * ROLL_BOOST; _set_state("rolling", true); return
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0; velocity.y = JUMP_VELOCITY; state = MoveState.JUMPING; _set_state("jumping", true); return
			_set_state("running", direction != 0)
		MoveState.JUMPING:
			_set_state("jumping", true)
			if velocity.y > 0: state = MoveState.FALLING
			if jump_buffer_timer > 0 and can_double_jump:
				jump_buffer_timer = 0; can_double_jump = false; velocity.y = DOUBLE_JUMP_VELOCITY; state = MoveState.DOUBLE_JUMPING; _set_state("double_jumping", true); return
		MoveState.DOUBLE_JUMPING:
			_set_state("double_jumping", true)
			if velocity.y > 0: state = MoveState.FALLING
		MoveState.FALLING:
			_set_state("falling", true)
			if is_on_floor(): state = MoveState.GROUNDED; return
			if jump_buffer_timer > 0 and can_double_jump:
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
	if not is_on_floor(): velocity += get_gravity() * delta

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

func check_slide_hazards() -> void:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i); var collider = col.get_collider()
		if collider and collider.is_in_group("hazards"): die()

func check_area_hazards() -> void:
	if hazard_detector:
		for area in hazard_detector.get_overlapping_areas():
			if area.is_in_group("hazards"): die()

func die() -> void:
	if is_dead: return

	is_dead = true
	_reset_animation_states()
	_set_state("dead", true)
	velocity = Vector2.ZERO

	await get_tree().create_timer(1.2).timeout
	
	# RESET LOGIC
	is_dead = false
	_reset_animation_states()
	
	# Force the state machine back to the entry point
	#var playback = anim_tree["parameters/playback"]
	#playback.travel("Start") 
	
	global_position = spawn_point
	state = MoveState.GROUNDED
	
	GameManager.reset_health()
	get_tree().reload_current_scene()

		
func _on_hp_changed(new_hp: float) -> void:
	if new_hp <= 0 and not is_dead: die()
