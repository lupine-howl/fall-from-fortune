extends CharacterBody2D
class_name BaseEnemy

enum FlightMode { HORIZONTAL_FLY, FALLING, CLIMBING, BOUNCING, GROUND_WALK }

@export_category("General Enemy Setup")
@export var sprite_frames: SpriteFrames
@export var default_animation := "flying"
@export var starting_mode: FlightMode = FlightMode.HORIZONTAL_FLY

@export_category("Enemy Settings")
@export var speed := 100.0
@export var damage_amount := 16.0
@export var horizontal_dir := -1 
@export var max_hp := 50.0

@export_category("Easing Settings")
@export var use_easing := true
@export var acceleration := 4.0 

@export_category("Flapping / Bounce Settings")
@export var flap_force := -250.0
@export var flap_cooldown := 0.4 

@onready var sprite = $AnimatedSprite2D
@onready var ledge_check = $RayCast2D
@onready var hurtbox = $Hurtbox
@onready var launcher = $ProjectileLauncher

# Physics and Internal State
var current_hp: float
var current_mode: FlightMode = FlightMode.HORIZONTAL_FLY
var base_gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var target_velocity := Vector2.ZERO
var current_velocity := Vector2.ZERO
var target_y_altitude := 0.0
var flap_timer := 0.0
var turn_timer := 0.0
var knockback_velocity := Vector2.ZERO
var knockback_timer := 0.0
const TURN_COOLDOWN := 0.5 

func _ready() -> void:
	current_hp = max_hp
	current_mode = starting_mode
	
	# Fallback logic for sprite frames
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
	
	# Only attempt to play if the assigned (or default) sprite_frames is valid
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(default_animation):
		sprite.play(default_animation)
	
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	
	var nav_detector = get_node_or_null("NavigationDetector")
	if nav_detector:
		nav_detector.area_entered.connect(_on_navigation_area_entered)
		await get_tree().physics_frame
		for area in nav_detector.get_overlapping_areas():
			if "trigger_type" in area and area.get("is_active") != false:
				_process_trigger_logic(area); break
				
	target_velocity = Vector2(horizontal_dir * speed, 0); current_velocity = target_velocity

func _physics_process(delta: float) -> void:
	
	# --- KNOCKBACK HANDLING ---
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		return # Skip standard movement logic while being knocked back
	
	if turn_timer > 0: turn_timer -= delta

	if horizontal_dir != 0:
		sprite.flip_h = (horizontal_dir == 1)
		ledge_check.position.x = 15 * (1 if horizontal_dir > 0 else -1)

	if turn_timer <= 0:
		var at_ledge = (current_mode == FlightMode.GROUND_WALK or is_on_floor()) and not ledge_check.is_colliding()
		if is_on_wall() or at_ledge:
			horizontal_dir *= -1
			turn_timer = TURN_COOLDOWN 
			if not use_easing: current_velocity.x = horizontal_dir * speed
			update_launcher_velocity() # Update projectile direction when turning
				
	# Apply progressive down-force gravity to structural airborne modes
	if current_mode == FlightMode.GROUND_WALK or current_mode == FlightMode.FALLING or current_mode == FlightMode.BOUNCING:
		if is_on_floor():
			target_velocity.y = 0 # Zero out downward force when standing on solid ground
		else:
			target_velocity.y += base_gravity * delta # Accumulate fall acceleration natively over frames

	match current_mode:
		FlightMode.HORIZONTAL_FLY:
			target_velocity.x = horizontal_dir * speed
			target_velocity.y = 0
		FlightMode.FALLING:
			target_velocity.x = horizontal_dir * speed
			if is_on_floor(): 
				current_mode = FlightMode.GROUND_WALK if starting_mode == FlightMode.GROUND_WALK else FlightMode.HORIZONTAL_FLY
		FlightMode.CLIMBING:
			target_velocity.x = horizontal_dir * speed
			target_velocity.y = -speed
			if global_position.y <= target_y_altitude: 
				global_position.y = target_y_altitude
				target_velocity.y = 0
				current_mode = FlightMode.HORIZONTAL_FLY
		FlightMode.BOUNCING:
			target_velocity.x = horizontal_dir * speed
			flap_timer -= delta
			if flap_timer <= 0.0:
				if use_easing: current_velocity.y = flap_force
				else: target_velocity.y = flap_force
				flap_timer = flap_cooldown 
		FlightMode.GROUND_WALK:
			target_velocity.x = horizontal_dir * speed

	if use_easing:
		current_velocity.x = lerp(current_velocity.x, target_velocity.x, acceleration * delta)
		if current_mode == FlightMode.GROUND_WALK or current_mode == FlightMode.FALLING or current_mode == FlightMode.BOUNCING:
			# Directly pass our accumulated downward frame gravity unconstrained by horizontal lerping
			current_velocity.y = target_velocity.y
		else:
			current_velocity.y = lerp(current_velocity.y, target_velocity.y, acceleration * delta)
		velocity = current_velocity
	else: 
		velocity = target_velocity
		
	move_and_slide()


# --- HEALTH LOGIC ---

func take_damage(amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	current_hp -= amount
	
	# --- FLASH EFFECT ---
	var original_modulate = modulate
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.1)
	tween.tween_property(self, "modulate", original_modulate, 0.1)
	
	if knockback_force != Vector2.ZERO:
		apply_knockback(knockback_force)
		
	if current_hp <= 0:
		die()

func apply_knockback(force: Vector2, duration: float = 0.2) -> void:
	knockback_velocity = force
	knockback_timer = duration

func die() -> void:
	# 1. If we are currently being knocked back, wait for it to finish
	if knockback_timer > 0:
		await get_tree().create_timer(knockback_timer).timeout
	
	# 2. Disable movement and interactions immediately
	set_physics_process(false)
	set_process(false)
	
	# Disable collisions safely
	for child in get_children():
		if child is CollisionShape2D or child is Area2D:
			child.set_deferred("disabled", true)
			child.set_deferred("monitorable", false)
	
	# 3. Fade-out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	
	# 4. Cleanup
	await tween.finished
	queue_free()
	
# --- PROJECTILE & TRIGGER LOGIC ---

func update_launcher_velocity():
	if not launcher: return
	var toss_vec = Vector2(0,0) # Default arc for flyers
	if current_mode == FlightMode.GROUND_WALK:
		toss_vec = Vector2(horizontal_dir * 500, -200) # Forward throw for walkers
	launcher.set_launch_velocity(toss_vec)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and launcher:
		update_launcher_velocity()
		launcher.call_deferred("shoot")
		launcher.start_launching()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and launcher:
		launcher.stop_launching()

func _on_navigation_area_entered(area: Area2D) -> void:
	if "is_active" in area and not area.is_active: return
	if "trigger_type" in area: _process_trigger_logic(area)

func _process_trigger_logic(area: Area2D) -> void:
	if area.get("is_one_shot"): area.deactivate_trigger()
	if area.get("override_speed") != null and area.override_speed > 0.0: speed = area.override_speed
	
	match area.trigger_type:
		0: # DIRECTION
			if area.target_direction == Vector2.UP:
				current_mode = FlightMode.CLIMBING; target_y_altitude = global_position.y - 200.0 
			else:
				current_mode = FlightMode.GROUND_WALK if starting_mode == FlightMode.GROUND_WALK else FlightMode.HORIZONTAL_FLY
				if area.target_direction.x != 0: horizontal_dir = 1 if area.target_direction.x > 0 else -1
				if not use_easing: current_velocity = Vector2(horizontal_dir * speed, current_velocity.y)
		1: # FALL
			current_mode = FlightMode.FALLING
		2: # TRAMPOLINE
			current_mode = FlightMode.BOUNCING; flap_timer = 0.0
	update_launcher_velocity() # Refresh throw vector when mode changes

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		GameManager.take_damage(damage_amount)
		if body.has_method("take_damage"):
			var dir = (body.global_position - global_position).normalized()
			dir.y = -0.5 
			body.take_damage(dir, 500.0)
