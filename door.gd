extends Area2D

var is_open = false
var victory_text
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	victory_text = get_parent().get_node("Player").get_node("Victory")
	victory_text.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func open():
	if !is_open:
		is_open = true
		$AnimatedSprite2D.play("open")


func _on_body_entered(body: Node2D) -> void:
	if is_open:
		victory_text.visible = true	
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

		
	pass # Replace with function body.
