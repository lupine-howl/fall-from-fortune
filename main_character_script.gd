extends CharacterBody2D

const SPEED = 350.0
const JUMP_VELOCITY = -800.0
@onready var sprite_2d: AnimatedSprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Animation states
	if velocity.x > 1 or velocity.x < -1:
		sprite_2d.animation = "2"
	else:
		sprite_2d.animation = "3"

	# Handle Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sprite_2d.animation = "1"

	# Get input direction
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction:
		velocity.x = direction * SPEED
		# Keeps them facing the correct way when they stop
		sprite_2d.flip_h = (direction < 0)
	else:
		# Standard stop. Godot handles platform riding automatically.
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
