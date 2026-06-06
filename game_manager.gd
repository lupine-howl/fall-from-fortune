extends Node

# Signals to notify the UI when things change
signal points_changed(new_points: int)
signal keys_changed(new_keys: int)
signal hp_changed(new_hp: float)

var points := 0
var keys := 0

# 1 heart = 16 pixels wide. 3 hearts = 48 pixels total max health.
var max_hp := 48.0
var current_hp := 48.0

func add_point() -> void:
	points += 1
	points_changed.emit(points)

func add_key() -> void:
	keys += 1
	print(keys)
	keys_changed.emit(keys)

# Call this whenever the player takes damage
# e.g., GameManager.take_damage(8.0) for a half-heart loss
func take_damage(amount: float) -> void:
	current_hp = max(current_hp - amount, 0.0)
	hp_changed.emit(current_hp)
	
	if current_hp <= 0:
		print("Player has run out of health!")
		# Trigger death/respawn logic here

# Call this from the player when restarting the level
func reset_health() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp)
