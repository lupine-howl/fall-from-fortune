extends Node

# Signals to notify the UI when things change
signal points_changed(new_points: int)
signal keys_changed(new_keys: int)
signal hp_changed(new_hp: float)

var points := 0
var keys := 0

# 1 heart = 16 pixels wide. 3 hearts = 48 pixels total max health.
var max_hp := 80.0
var current_hp := 80.0

# --- NEW CHECKPOINT PROPERTY ---
## Holds the global coordinates of the last checkpoint touched.
var last_checkpoint_position := Vector2.ZERO

func add_point() -> void:
	points += 1
	points_changed.emit(points)

func add_key() -> void:
	keys += 1
	print(keys)
	keys_changed.emit(keys)

func add_health(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp) # Added min() caps so health doesn't exceed maximum
	hp_changed.emit(current_hp)

# Call this from the player when restarting the level
func reset_health() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp)
	keys = 0
	keys_changed.emit(0)

# Call this whenever the player takes damage
func take_damage(amount: float) -> void:
	current_hp = max(current_hp - amount, 0.0)
	hp_changed.emit(current_hp)
	
	if current_hp <= 0:
		print("Player has run out of health! Waiting for death animation...")
		# DO NOT call trigger_player_respawn() here anymore! 
		# The player script's _on_hp_changed signal will handle starting the animation.

# Call this ONLY when the player's death animation has finished playing
func trigger_player_respawn() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp)
	
	var player = get_tree().get_first_node_in_group("player")
	
	if player and last_checkpoint_position != Vector2.ZERO:
		player.global_position = last_checkpoint_position
	else:
		get_tree().reload_current_scene()
