extends CharacterBody2D

enum FlightMode { HORIZONTAL_FLY, FALLING, CLIMBING, BOUNCING }
var current_mode: FlightMode = FlightMode.HORIZONTAL_FLY

@export_category("Enemy Settings")
@export var speed := 100.0
@export var damage_amount := 16.0
@export var horizontal_dir := -1 

@export_category("Easing Settings")
@export var use_easing := true
@export var acceleration := 4.0 

@export_category("Flapping / Bounce Settings")
@export var flap_force := -250.0
@export var flap_cooldown := 0.4 

@onready var sprite = $AnimatedSprite2D
@onready var ledge_check = $RayCast2D
@onready var hurtbox = $Hurtbox

var base_gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_gravity := 0.0 
var target_velocity := Vector2.ZERO
var current_velocity := Vector2.ZERO
var target_y_altitude := 0.0
var flap_timer := 0.0

func _ready() -> void:
	if sprite.sprite_frames.has_animation("flying"): sprite.play("flying")
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
	if horizontal_dir != 0:
		sprite.flip_h = (horizontal_dir == 1)
		ledge_check.position.x = 15 * (1 if horizontal_dir > 0 else -1)

	if is_on_wall():
		horizontal_dir *= -1
		if not use_easing: current_velocity.x = horizontal_dir * speed
	elif is_on_floor() and not ledge_check.is_colliding():
		horizontal_dir *= -1
		if not use_easing: current_velocity.x = horizontal_dir * speed

	match current_mode:
		FlightMode.HORIZONTAL_FLY:
			target_velocity.x = horizontal_dir * speed; target_velocity.y = 0
		FlightMode.FALLING:
			target_velocity.x = horizontal_dir * speed; target_velocity.y += base_gravity * delta
			if is_on_floor(): current_gravity = 0.0; target_velocity.y = 0; current_mode = FlightMode.HORIZONTAL_FLY
		FlightMode.CLIMBING:
			target_velocity.x = horizontal_dir * speed; target_velocity.y = -speed
			if global_position.y <= target_y_altitude: global_position.y = target_y_altitude; target_velocity.y = 0; current_mode = FlightMode.HORIZONTAL_FLY
		FlightMode.BOUNCING:
			target_velocity.x = horizontal_dir * speed; target_velocity.y += base_gravity * delta
			flap_timer -= delta
			if flap_timer <= 0.0:
				if use_easing: current_velocity.y = flap_force
				else: target_velocity.y = flap_force
				flap_timer = flap_cooldown 

	if use_easing:
		current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
		velocity = current_velocity
	else: velocity = target_velocity
	move_and_slide()

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
				current_mode = FlightMode.HORIZONTAL_FLY
				if area.target_direction.x != 0: horizontal_dir = 1 if area.target_direction.x > 0 else -1
				if not use_easing: current_velocity = Vector2(horizontal_dir * speed, 0)
		1: # FALL
			current_mode = FlightMode.FALLING
		2: # TRAMPOLINE
			current_mode = FlightMode.BOUNCING; flap_timer = 0.0
			if not use_easing: target_velocity.y = flap_force

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		GameManager.take_damage(damage_amount)
		if body.has_method("take_damage"):
			var dir = (body.global_position - global_position).normalized()
			dir.y = -0.5 
			body.take_damage(dir, 500.0)
