class_name SteerableCharacterBody2D
extends CharacterBody2D

@export var speed := 150.0
@export var current_direction := Vector2.RIGHT

func _ready() -> void:
	# Look for the center detector area automatically when the node spawns
	var nav_detector = get_node_or_null("NavigationDetector")
	if nav_detector:
		nav_detector.area_entered.connect(_on_navigation_area_entered)
	else:
		push_warning("Warning: " + name + " is missing a NavigationDetector Area2D child node!")

func _physics_process(delta: float) -> void:
	# Define a unified core movement loop for all steerable characters
	velocity = current_direction * speed
	move_and_slide()

func _on_navigation_area_entered(area: Area2D) -> void:
	if "target_direction" in area:
		current_direction = area.target_direction
		
		# Perfect grid-snapping onto the arrow marker's center
		global_position = area.global_position
