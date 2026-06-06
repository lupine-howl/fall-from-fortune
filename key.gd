extends Area2D

@onready var sprite = $AnimatedSprite2D

func _ready():
	sprite.play("default")
	
func _on_body_entered(body):
	#print(body)
	if body.is_in_group("player"):
		GameManager.add_key()
		queue_free()
