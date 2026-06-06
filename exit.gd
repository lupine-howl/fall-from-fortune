extends Area2D

@export var target_level: PackedScene
@export var keys_needed:= 1
@onready var sprite = $AnimatedSprite2D

var is_open = false

func _ready():
	GameManager.keys_changed.connect(on_keys_changed)
	on_keys_changed(0)
	sprite.play("default")
	
func on_keys_changed(keys: int) -> void:
	if keys >= keys_needed:
		is_open = true
		sprite.play("open")

func _on_body_entered(body):
	if is_open and body.is_in_group("player"):
		get_tree().change_scene_to_packed(target_level)
