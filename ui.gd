extends CanvasLayer

@onready var points_label = %PointsLabel
@onready var keys_label = %KeysLabel

# Make sure these node names match your UI scene tree layout
@onready var hearts_foreground = %HeartsForeground 

func _ready() -> void:
	# 1. Connect to the global GameManager signals
	GameManager.points_changed.connect(update_points_display)
	GameManager.keys_changed.connect(update_keys_display)
	GameManager.hp_changed.connect(update_hearts_display)
	
	# 2. Run initial display sync so it loads correctly on startup
	update_points_display(GameManager.points)
	update_hearts_display(GameManager.current_hp)
	update_keys_display(GameManager.keys)

func update_points_display(points: int) -> void:
	points_label.text = "Points: " + str(points)

func update_keys_display(keys: int) -> void:
	keys_label.text = "Keys: " + str(keys)

func update_hearts_display(current_hp: float) -> void:
	# If health is 0 or less, explicitly hide the foreground hearts
	if current_hp <= 0:
		hearts_foreground.visible = false
		hearts_foreground.size.x = 0
	else:
		hearts_foreground.visible = true
		# Change the width dynamically
		hearts_foreground.size.x = current_hp
