extends Sprite2D

@export var start := 2000
@export var end := -5000
@export var speed := 0.2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position.x = start
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x -= speed
	if position.x < end:
		position.x = start
	pass
