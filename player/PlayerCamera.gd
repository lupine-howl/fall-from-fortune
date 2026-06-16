extends Camera2D

# How fast the camera zooms in/out
@export var zoom_speed : float = 0.1

# The minimum and maximum zoom levels allowed
@export var min_zoom : float = 0.1
@export var max_zoom : float = 50.0

# How smoothly the camera transitions to the target zoom (lower = smoother)
@export var zoom_smoothing : float = 0.2

# Internal target zoom vector
var target_zoom : Vector2

func _ready():
	# Initialize target zoom to the camera's starting zoom
	target_zoom = zoom

func _process(_delta):
	# Smoothly interpolate the current zoom toward the target zoom
	zoom = zoom.lerp(target_zoom, zoom_smoothing)

func _unhandled_input(event):
	# Check for mouse wheel scrolling
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				# Zoom In: Increase the zoom vector values
				target_zoom += Vector2(zoom_speed, zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Zoom Out: Decrease the zoom vector values
				target_zoom -= Vector2(zoom_speed, zoom_speed)
			
			# Clamp the target zoom to stay within our defined min/max limits
			target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
			target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)
