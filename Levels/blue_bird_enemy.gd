extends CharacterBody2D

@export var speed := 100.0
@export var damage_amount := 16.0

@onready var sprite = $AnimatedSprite2D
@onready var ledge_check = $RayCast2D
@onready var hurtbox = $Hurtbox

# Get gravity from project settings if you want it to fall, 
# or set to 0 if it's a floating/flying bird!
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction := -1 # 1 = Right, -1 = Left

func _ready() -> void:
	sprite.play("flying")
	# Connect the Hurtbox area to detect the player
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _physics_process(delta: float) -> void:
	# 1. OPTIONAL: Apply Gravity (Remove these lines if it flies perfectly straight)
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. Handle Turning Around (Wall collision OR running out of floor)
	if is_on_wall() or (is_on_floor() and not ledge_check.is_colliding()):
		direction *= -1
		sprite.flip_h = (direction == 1)
		# Flip the raycast position so it looks ahead in the new direction
		ledge_check.position.x = 15 * direction

	# 3. Apply Horizontal Velocity
	velocity.x = direction * speed

	# 4. Move using Godot's physics engine
	move_and_slide()

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.take_damage(damage_amount)
