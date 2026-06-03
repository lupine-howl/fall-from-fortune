extends AnimatableBody2D

@export var fall_speed: float = 0.0
@export var delay_time: float = 0.8 # Seconds before falling

@onready var fall_timer: Timer = $FallTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_falling: bool = false

func _ready() -> void:
	# Set up the timer based on our export variable
	fall_timer.wait_time = delay_time
	fall_timer.one_shot = true

func _physics_process(delta: float) -> void:
	if is_falling:
		# Move downwards smoothly
		global_position.y += fall_speed * delta
		fall_speed += 100

# This runs when something enters the Area2D trigger zone above the cloud
func _on_area_2d_body_entered(body: Node2D) -> void:
	# Make sure it's the player stepping on it and the timer hasn't started yet
	if body is CharacterBody2D and fall_timer.is_stopped() and not is_falling:
		fall_timer.start()
		# Optional: Add a little camera shake or sprite jiggle here!

# This runs when the FallTimer hits 0
func _on_fall_timer_timeout() -> void:
	is_falling = true
	# Turn off collisions so the player drops through it if they stay too long,
	# and so the falling platform doesn't block enemies/hazards below.
	collision_shape.set_deferred("disabled", true)
