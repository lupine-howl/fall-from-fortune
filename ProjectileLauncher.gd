extends Node2D

@export var projectile_scene: PackedScene 
@export var shoot_interval := 2.0

# Store the velocity here so it's ready when the timer fires
var initial_velocity: Vector2 = Vector2(0,0)

@onready var timer = $Timer
@onready var spawn_point = $Marker2D

func _ready() -> void:
	timer.wait_time = shoot_interval
	timer.timeout.connect(shoot)

# Allow the Enemy to update the launch direction/force dynamically
func set_launch_velocity(vel: Vector2):
	initial_velocity = vel

func start_launching(): 
	timer.start()
	
func stop_launching(): 
	timer.stop()

func shoot():
	if not projectile_scene: return
	var b = projectile_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = spawn_point.global_position
	
	if b.has_method("set_initial_velocity"):
		b.set_initial_velocity(initial_velocity)
		
