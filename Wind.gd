extends Area2D

@export_category("Gravity Vectors")
## The starting gravity direction vector.
@export var vector_a := Vector2(-1, 0)
## The gravity speed/magnitude for Vector A.
@export var speed_a := 300.0

## The target gravity direction vector.
@export var vector_b := Vector2(1, 0)
## The gravity speed/magnitude for Vector B.
@export var speed_b := 300.0

@export_category("Timing Settings")
## How fast the gravity shifts back and forth (higher values = faster swing).
@export var swing_speed := 2.0
## How long the gravity area stays powered ON.
@export var time_powered_on := 3.0
## How long the gravity area stays powered OFF.
@export var time_powered_off := 2.0

# Internal state tracking
var time_passed := 0.0
var is_turning_on := true
var power_timer := 0.0

func _ready() -> void:
	gravity_space_override = Area2D.SPACE_OVERRIDE_REPLACE
	gravity_point = false
	power_timer = time_powered_on

func _physics_process(delta: float) -> void:
	_handle_power_cycle(delta)
	
	if monitoring:
		_handle_gravity_swing(delta)

func _handle_power_cycle(delta: float) -> void:
	power_timer -= delta
	if power_timer <= 0.0:
		is_turning_on = !is_turning_on
		set_deferred("monitoring", is_turning_on)
		visible = is_turning_on
		power_timer = time_powered_on if is_turning_on else time_powered_off

func _handle_gravity_swing(delta: float) -> void:
	time_passed += delta * swing_speed
	
	# Creates a perfect wave weight changing smoothly between 0.0 and 1.0
	var weight := (sin(time_passed) + 1.0) / 2.0
	
	# Extract exact target angle radians
	var angle_a := vector_a.angle()
	var angle_b := vector_b.angle()
	
	# Cleanly smoothly rotate the angle
	var target_angle := lerp_angle(angle_a, angle_b, weight)
	
	# SAFETY CHECK: If speeds match, don't let lerp or inspector bugs touch it
	var current_speed: float = speed_a
	if not is_equal_approx(speed_a, speed_b):
		current_speed = lerp(speed_a, speed_b, weight)
	
	# Direct assignment to native properties ensures updates register
	gravity_direction = Vector2.from_angle(target_angle)
	gravity = current_speed
