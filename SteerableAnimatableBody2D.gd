class_name SteerableAnimatableBody2D
extends AnimatableBody2D

enum PlatformState { NORMAL, WAITING, FALLING, TRAMPOLINE_BOUNCE }
var current_state: PlatformState = PlatformState.NORMAL

@export_category("Steering Settings")
@export var speed := 150.0
@export var current_direction := Vector2.RIGHT
@export var starting_state: PlatformState = PlatformState.NORMAL
@export var start_waiting_for_player := false 

@export_category("Easing Settings")
@export var use_easing := true 
@export var acceleration := 4.0 

@export_category("Physics Properties")
@export var fall_gravity := 800.0

@onready var sprite = $AnimatedSprite2D

# Internal physics tracking
var target_velocity := Vector2.ZERO
var current_velocity := Vector2.ZERO
var default_base_speed := 150.0 # Remembers our starting speed profile

# Storage to remember tile logic during WAITING phases
var pending_trigger_type: int = 0
var pending_direction := Vector2.RIGHT
var pending_speed_override := 0.0
var pending_trigger_ref: Area2D = null

func _ready() -> void:
	sync_to_physics = true
	default_base_speed = speed # Store default speed set in inspector
	
# Set the initial state based on the export
	current_state = starting_state
	
	# Override if the legacy "waiting" flag is set to true
	if start_waiting_for_player:
		current_state = PlatformState.WAITING
				
	target_velocity = current_direction * speed
	current_velocity = target_velocity
	
	var nav_detector = get_node_or_null("NavigationDetector")
	if nav_detector:
		nav_detector.area_entered.connect(_on_navigation_area_entered)
		
		await get_tree().physics_frame
		if current_state != PlatformState.WAITING:
			for area in nav_detector.get_overlapping_areas():
				if "target_direction" in area and area.get("is_active") != false:
					current_direction = area.target_direction
					global_position = area.global_position
					
					if area.override_speed > 0:
						speed = area.override_speed
						
					target_velocity = current_direction * speed
					current_velocity = target_velocity
					
					if area.is_one_shot:
						area.deactivate_trigger()
					break

func _physics_process(delta: float) -> void:
	if current_state == PlatformState.WAITING:
		if HasPlayerRider():
			# Trigger popped! Check if the marker node itself needs one-shot cleanup
			if pending_trigger_ref and is_instance_valid(pending_trigger_ref):
				if pending_trigger_ref.is_one_shot:
					pending_trigger_ref.deactivate_trigger()
					
			_execute_trigger_behavior(pending_trigger_type, pending_direction, pending_speed_override)

	if current_state == PlatformState.TRAMPOLINE_BOUNCE:
		if HasPlayerRider():
			LaunchPlayerRider()

	match current_state:
		PlatformState.WAITING:
			current_velocity = Vector2.ZERO
		PlatformState.NORMAL:
			target_velocity = current_direction * speed
			if use_easing:
				current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
			else:
				current_velocity = target_velocity
			global_position += current_velocity * delta
		PlatformState.FALLING:
			current_velocity.x = 0
			current_velocity.y += fall_gravity * delta
			global_position += current_velocity * delta
		PlatformState.TRAMPOLINE_BOUNCE:
			current_velocity = Vector2.ZERO

func _on_navigation_area_entered(area: Area2D) -> void:
	if "trigger_type" in area:
		# Completely ignore spent one-shot tiles
		if "is_active" in area and not area.is_active:
			return
			
		if area.wait_for_player and not HasPlayerRider():
			global_position = area.global_position
			current_velocity = Vector2.ZERO
			
			# Cache everything until a player jumps on
			pending_trigger_type = area.trigger_type
			pending_direction = area.target_direction
			pending_speed_override = area.override_speed
			pending_trigger_ref = area 
			current_state = PlatformState.WAITING
		else:
			global_position = area.global_position
			
			# Clean out one-shot instances immediately if we don't have to wait
			if area.is_one_shot:
				area.deactivate_trigger()
				
			_execute_trigger_behavior(area.trigger_type, area.target_direction, area.override_speed)

func _execute_trigger_behavior(type: int, target_dir: Vector2, speed_override: float) -> void:
	# Process speed changes first
	if speed_override > 0.0:
		speed = speed_override
	
	match type:
		0: # DIRECTION
			current_state = PlatformState.NORMAL
			current_direction = target_dir
			if not use_easing:
				current_velocity = current_direction * speed
		1: # FALL
			await get_tree().create_timer(0.2).timeout
			current_state = PlatformState.FALLING
		2: # TRAMPOLINE
			current_state = PlatformState.TRAMPOLINE_BOUNCE
			LaunchPlayerRider()

# --- INTERACTION HELPERS ---

func HasPlayerRider() -> bool:
	var detector = get_node_or_null("PassengerDetector")
	if detector:
		for body in detector.get_overlapping_bodies():
			if body is CharacterBody2D:
				return true
	return false

func LaunchPlayerRider() -> void:
	var detector = get_node_or_null("PassengerDetector")
	if detector:
		for body in detector.get_overlapping_bodies():
			if body is CharacterBody2D:
				body.velocity.y = -1100.0 
				if "state" in body:
					body.state = 1
					
					if sprite and sprite.sprite_frames.has_animation("bounce"):
						sprite.play("bounce")
