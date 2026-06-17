extends Area2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Tracks if this specific checkpoint has already been turned on
var is_activated := false

func _ready() -> void:
	# Natively connect the body entered signal in code
	body_entered.connect(_on_body_entered)
	
	# Play the default unactivated visual state
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

func _on_body_entered(body: Node2D) -> void:
	# Check if the colliding node is the player and isn't already turned on
	if body.is_in_group("player") and not is_activated:
		activate_checkpoint()

func activate_checkpoint() -> void:
	is_activated = true
	
	# CRITICAL LINE: Records this object's exact world position to your GameManager
	GameManager.last_checkpoint_position = global_position
	
	# Visual/Audio Feedback
	if animated_sprite and animated_sprite.sprite_frames.has_animation("activated"):
		animated_sprite.play("activated")
		
	print("Checkpoint safely recorded at coordinates: ", global_position)
