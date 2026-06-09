# EnvironmentalTrigger.gd (The Marker Tile)
extends Area2D

enum TriggerType { DIRECTION, FALL, TRAMPOLINE }

@export_category("Trigger Configuration")
@export var trigger_type: TriggerType = TriggerType.DIRECTION
@export var wait_for_player := false 
@export var is_one_shot := false # FEATURE 1: Disables itself after one use

@export_category("Speed Customization")
# FEATURE 2: If greater than 0, it forces the platform to this new exact speed
@export var override_speed := 0.0 

@export_category("Visual Setup")
@export_enum("Right", "Left", "Up", "Down") var arrow_direction: String = "Right":
	set(value):
		arrow_direction = value
		_update_direction_properties()

var target_direction := Vector2.RIGHT
var is_active := true # Internal track to see if a one-shot tile has popped
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("navigation_markers")
	visible = false
	_update_direction_properties()

func deactivate_trigger() -> void:
	is_active = false
	# Visual cue for students: fade out slightly to show it's used up!
	modulate.a = 0.25 

func _update_direction_properties() -> void:
	if not is_node_ready() or not sprite:
		await ready
	
	if trigger_type == TriggerType.DIRECTION:
		match arrow_direction:
			"Right": target_direction = Vector2.RIGHT; #rotation_degrees = 0
			"Left": target_direction = Vector2.LEFT; #rotation_degrees = 180
			"Up": target_direction = Vector2.UP; #rotation_degrees = -90
			"Down": target_direction = Vector2.DOWN; #rotation_degrees = 90
	else:
		rotation_degrees = 0
