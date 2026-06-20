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

@export_category("Debug")
@export var show_debug_ui := true

# ---------------------------------------------------------
# STATES
# ---------------------------------------------------------
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
var wall_jump_lock := 0.0 
var spawn_point
var is_submerged := false 
var is_on_ladder := false 

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

# --- MODULE REFERENCES ---
@onready var debug_hud := $DebugHUD 
var states_map: Dictionary = {}
var active_state_component: Node

@onready var sprite_pivot := $SpritePivot
@onready var anim_tree := $AnimationTree
@onready var hazard_detector := $SpritePivot/HazardDetector
@onready var sprite_upper := $SpritePivot/SpriteContainer/SpriteUpper
@onready var sprite_lower := $SpritePivot/SpriteContainer/SpriteLower
@onready var attack_area := $SpritePivot/AttackArea
@onready var wall_detector := $SpritePivot/WallDetector 
@onready var ledge_detector := $SpritePivot/LedgeDetector

func _ready() -> void:
	spawn_point = global_position 
	anim_tree.active = true
	GameManager.hp_changed.connect(_on_hp_changed)
	
	if not show_debug_ui and debug_hud:
		debug_hud.queue_free()
		debug_hud = null
		
	_initialize_modular_states()
	_reset_animation_states()

func _initialize_modular_states() -> void:
	var climb_comp = Node.new()
	climb_comp.set_script(preload("res://player/scripts/ClimbState.gd"))
	add_child(climb_comp)
	if climb_comp.has_method("init"):
		climb_comp.init(self)
	
	states_map[MoveState.LADDER_CLIMBING] = climb_comp
	states_map[MoveState.WALL_CLIMBING] = climb_comp
	states_map[MoveState.LEDGE_CLIMBING] = climb_comp
	
	_change_state(MoveState.GROUNDED)

func _change_state(new_state: MoveState) -> void:
	if active_state_component and active_state_component.has_method("exit"):
		active_state_component.exit()
		
	state = new_state
	active_state_component = states_map.get(state, null)
	
	if active_state_component and active_state_component.has_method("enter"):
		active_state_component.enter()

func _physics_process(delta: float) -> void:
	if velocity.y > 10000: die()
	if is_dead:
		_apply_gravity(delta); velocity.x *= 0.9; _move(); return
	if state == MoveState.KNOCKBACK:
		knockback_timer -= delta
		if knockback_timer <= 0: _change_state(MoveState.GROUNDED)
		_apply_gravity(delta); move_and_slide(); return

	if wall_jump_lock > 0: wall_jump_lock -= delta

	# Process Timers & Raycasts
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")
	var pressing_into_wall: bool = (direction != 0 and sign(direction) == facing)
	var touching_wall: bool = wall_detector and wall_detector.is_colliding()
	var over_ledge: bool = ledge_detector and not ledge_detector.is_colliding()
	
	var valid_climb_window: bool = velocity.y >= -150.0 
	
	# Global State Checks
	if state != MoveState.LEDGE_CLIMBING and touching_wall and over_ledge and not is_on_floor() and valid_climb_window:
		if pressing_into_wall or state == MoveState.WALL_CLIMBING:
			_change_state(MoveState.LEDGE_CLIMBING)
			
	var can_wall_climb: bool = wall_detector and wall_detector.is_colliding() and not is_on_floor() and wall_jump_lock <= 0.0
	if can_wall_climb and state != MoveState.WALL_CLIMBING and state != MoveState.LEDGE_CLIMBING and pressing_into_wall:
		_change_state(MoveState.WALL_CLIMBING)

	if is_on_ladder and state != MoveState.LADDER_CLIMBING and y_dir != 0:
		_change_state(MoveState.LADDER_CLIMBING)

	# Update Shared Engine Loops
	if Input.is_action_just_pressed("ui_jump"): jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if Input.is_action_pressed("ui_attack"): attack_timer = attack_buffer
	else: attack_timer = max(attack_timer - delta, 0.0)
	_set_state("attacking", attack_timer > 0.0)

	# Ground & Double Jump Timers
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
	else: 
		coyote_timer = max(coyote_timer - delta, 0.0)
		
	# FIXED: Ensure double jump reloads upon grabbing a climbing surface
	if state == MoveState.WALL_CLIMBING or state == MoveState.LADDER_CLIMBING or state == MoveState.LEDGE_CLIMBING:
		can_double_jump = true

	# DELEGATION SYSTEM: Route to external module if attached
	if active_state_component and active_state_component.has_method("physics_update"):
		active_state_component.physics_update(delta)
	else:
		_fallback_state_process(delta, direction, y_dir)

	_apply_gravity(delta)
	_move()
	
	_set_state("on_ground", is_on_floor())
	
	if debug_hud:
		debug_hud.update_physics(self)
		
	
func _fallback_state_process(delta: float, direction: float, y_dir: float) -> void:
	if state != MoveState.ROLLING and state != MoveState.DASHING and wall_jump_lock <= 0.0:
		if direction != 0:
			facing = -1 if direction < 0 else 1
			sprite_pivot.scale.x = facing

	if Input.is_action_just_pressed("ui_dash") and not is_submerged:
		_change_state(MoveState.DASHING)
		dash_timer = 0.20
		velocity.x = facing * DASH_BOOST
		_set_state("dashing", true)

	if state != MoveState.ROLLING and state != MoveState.DASHING:
		var current_target_speed := SPEED
		if is_submerged: current_target_speed *= water_speed_multiplier
		var horiz_gravity := get_gravity().x
		
		if direction != 0: 
			var adaptive_target_speed: float = direction * current_target_speed + (horiz_gravity * 0.25)
			velocity.x = move_toward(velocity.x, adaptive_target_speed, SPEED * 8 * delta)
		else: 
			if is_on_floor(): horiz_gravity *= grounded_horizontal_current_dampening
			velocity.x = move_toward(velocity.x, horiz_gravity * 0.5, current_target_speed * 8 * delta)

	if not is_on_floor() and velocity.y >= 0: 
		_change_state(MoveState.FALLING)

	match state:
		MoveState.GROUNDED:
			_set_state("on_ground", true) 
			_set_state("falling", false); _set_state("jumping", false); _set_state("double_jumping", false)
			_set_state("crouching", y_dir > 0)
			if attack_timer > 0.0 and y_dir > 0 and not is_submerged:
				_change_state(MoveState.ROLLING); roll_timer = 0.25; velocity.x = facing * ROLL_BOOST; _set_state("rolling", true); return
			if jump_buffer_timer > 0:
				jump_buffer_timer = 0
				velocity.y = water_swim_velocity if is_submerged else JUMP_VELOCITY
				_change_state(MoveState.JUMPING); _set_state("jumping", true); return
			_set_state("running", direction != 0)
			
		MoveState.JUMPING:
			_set_state("jumping", true); _set_state("falling", false)
			if velocity.y > 0: _change_state(MoveState.FALLING)
			if jump_buffer_timer > 0:
				if is_submerged:
					jump_buffer_timer = 0; velocity.y = water_swim_velocity
				elif can_double_jump:
					jump_buffer_timer = 0; can_double_jump = false; velocity.y = DOUBLE_JUMP_VELOCITY
					_change_state(MoveState.DOUBLE_JUMPING); _set_state("double_jumping", true)
					
		MoveState.FALLING:
			_set_state("falling", true); _set_state("jumping", false)
			if is_on_floor(): _change_state(MoveState.GROUNDED); return
			if jump_buffer_timer > 0:
				if is_submerged:
					jump_buffer_timer = 0; velocity.y = water_swim_velocity
					_change_state(MoveState.JUMPING)
				elif can_double_jump:
					jump_buffer_timer = 0; can_double_jump = false; velocity.y = DOUBLE_JUMP_VELOCITY
					_change_state(MoveState.DOUBLE_JUMPING); _set_state("double_jumping", true)
					
		MoveState.ROLLING:
			roll_timer -= delta
			if roll_timer <= 0: _set_state("rolling", false); _change_state(MoveState.GROUNDED)
			
		MoveState.DASHING:
			dash_timer -= delta
			if dash_timer <= 0: _set_state("dashing", false); _change_state(MoveState.GROUNDED)

# ---------------------------------------------------------
# CORE UTILITIES & PIPELINE HELPERS
# ---------------------------------------------------------
func _set_state(name: String, value: bool) -> void:
	if debug_hud:
		debug_hud.update_anim_state(name, value)
		
	var pos := "is_" + name
	var neg := "is_not_" + name
	
	var lower_pos := "parameters/LowerState/conditions/" + pos
	var lower_neg := "parameters/LowerState/conditions/" + neg
	var upper_pos := "parameters/UpperState/conditions/" + pos
	var upper_neg := "parameters/UpperState/conditions/" + neg
	
	if lower_pos in anim_tree: anim_tree[lower_pos] = value
	if lower_neg in anim_tree: anim_tree[lower_neg] = !value
	if upper_pos in anim_tree: anim_tree[upper_pos] = value
	if upper_neg in anim_tree: anim_tree[upper_neg] = !value

func _reset_animation_states() -> void:
	if anim_tree and "parameters/ClimbScale/scale" in anim_tree:
		anim_tree["parameters/ClimbScale/scale"] = 1.0
	_set_state("on_ground", true) 
	_set_state("on_ladder", false); _set_state("on_wall", false); _set_state("wall_climbing", false); _set_state("on_ledge", false) 
	_set_state("jumping", false); _set_state("falling", false); _set_state("double_jumping", false)
	_set_state("running", false); _set_state("crouching", false); _set_state("attacking", false)
	_set_state("rolling", false); _set_state("dead", false); _set_state("dashing", false)

func finalize_ledge_climb() -> void:
	global_position += Vector2(16.0 * facing, -40.0)
	sprite_upper.position = Vector2.ZERO; sprite_lower.position = Vector2.ZERO
	_change_state(MoveState.GROUNDED)
	_reset_animation_states()

func _apply_gravity(delta: float) -> void:
	if state in [MoveState.LADDER_CLIMBING, MoveState.WALL_CLIMBING, MoveState.LEDGE_CLIMBING]: return
	var current_gravity := get_gravity()
	if current_gravity.x != 0:
		var applied_horiz_force = current_gravity.x * (grounded_horizontal_current_dampening if (is_on_floor() and Input.get_axis("ui_left", "ui_right") == 0) else 1.0)
		velocity.x += applied_horiz_force * delta
	
	if not is_on_floor():
		if is_submerged and current_gravity.y == ProjectSettings.get_setting("physics/2d/default_gravity"):
			velocity.y = min(velocity.y + current_gravity.y * water_gravity_multiplier * delta, water_terminal_velocity)
		else:
			velocity.y += current_gravity.y * delta

func take_damage(knockback_dir: Vector2, force: float):
	if is_invincible: return
	_change_state(MoveState.KNOCKBACK)
	knockback_timer = 0.2; velocity = knockback_dir * force; is_invincible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if not is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	is_invincible = false

func die() -> void:
	if is_dead: return
	is_dead = true; is_submerged = false 
	_reset_animation_states(); _set_state("dead", true); velocity = Vector2.ZERO
	await get_tree().create_timer(1.2).timeout
	is_dead = false; _reset_animation_states()
	_change_state(MoveState.GROUNDED)
	GameManager.trigger_player_respawn()

func _move() -> void: move_and_slide(); check_slide_hazards(); check_area_hazards()
func _on_hp_changed(new_hp: float) -> void: if new_hp <= 0 and not is_dead: die()

func check_slide_hazards() -> void:
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("hazards"): die()

func check_area_hazards() -> void:
	if not hazard_detector: return
	var overlapping_areas = hazard_detector.get_overlapping_areas()
	for area in overlapping_areas:
		if area.is_in_group("hazards"): die(); return
	
	is_on_ladder = overlapping_areas.any(func(area): return area.is_in_group("ladders"))
	if not is_on_ladder and state == MoveState.LADDER_CLIMBING: _change_state(MoveState.FALLING)
	is_submerged = hazard_detector.get_overlapping_bodies().any(func(body): return body is TileMapLayer)
