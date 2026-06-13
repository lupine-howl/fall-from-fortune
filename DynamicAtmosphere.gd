extends CanvasModulate

var player_body: Node2D = null

@export_category("Elevation Anchors")
@export var peak_y: float = -4000.0     # High up in the sky (Overexposed)
@export var neutral_y: float = -2000.0      # The ground/starting level (Normal lighting)
@export var deep_y: float = 200.0      # Deep underground (Darkness)

@export_category("Atmosphere Overrides")
# We use raw Color vectors so we can exceed the 1.0 limit for HDR overexposure
@export var overexposed_color: Color = Color(2.5, 2.3, 2.0) # Warm, blinding light (Values > 1.0)
@export var neutral_color: Color = Color(1.0, 1.0, 1.0)     # Normal, untouched game colors
@export var deep_color: Color = Color(0.1, 0.1, 0.18)       # Cool, dark cave tint

func _ready() -> void:
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		player_body = nodes[0] as Node2D

func _physics_process(_delta: float) -> void:
	if not player_body:
		return
		
	var current_y: float = player_body.global_position.y
	
	# ZONE 1: Going UP (Between ground level and the sky)
	if current_y < neutral_y:
		# Clamp position to avoid breaking the math past the peak sky limit
		var clamped_y = clamp(current_y, peak_y, neutral_y)
		# Remap: 0.0 means at the neutral midpoint, 1.0 means high up at the peak
		var sky_percentage = remap(clamped_y, neutral_y, peak_y, 0.0, 1.0)
		
		# Blend from normal colors into HDR overexposure
		self.color = neutral_color.lerp(overexposed_color, sky_percentage)
		
	# ZONE 2: Going DOWN (Between ground level and the deep)
	else:
		# Clamp position to avoid breaking math past the deepest floor limit
		var clamped_y = clamp(current_y, neutral_y, deep_y)
		# Remap: 0.0 means at the neutral midpoint, 1.0 means at maximum depth
		var cave_percentage = remap(clamped_y, neutral_y, deep_y, 0.0, 1.0)
		
		# Blend from normal colors into darkness
		self.color = neutral_color.lerp(deep_color, cave_percentage)
