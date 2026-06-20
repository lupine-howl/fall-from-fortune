extends CanvasLayer

var lbl_physics: Label
var lbl_anim: Label
var anim_cache: Dictionary = {}

func _ready() -> void:
	# Setup Physics Label (Left)
	lbl_physics = Label.new()
	lbl_physics.position = Vector2(16, 16)
	lbl_physics.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_physics.add_theme_constant_override("outline_size", 4)
	add_child(lbl_physics)
	
	# Setup Anim Label (Right)
	lbl_anim = Label.new()
	lbl_anim.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_anim.add_theme_constant_override("outline_size", 4)
	lbl_anim.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_anim.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl_anim.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_anim.position = Vector2(-16, 16)
	add_child(lbl_anim)

func update_physics(player: CharacterBody2D) -> void:
	var text := "--- CORE ---\n"
	text += "State: " + player.MoveState.keys()[player.state] + "\n"
	text += "Velocity: " + str(player.velocity.round()) + "\n"
	text += "Facing: " + str(player.facing) + "\n\n"
	
	text += "--- ENGINE PHYSICS ---\n"
	text += "On Floor: " + str(player.is_on_floor()) + "\n"
	text += "On Wall: " + str(player.is_on_wall()) + "\n"
	text += "On Ceiling: " + str(player.is_on_ceiling()) + "\n\n"
	
	text += "--- CUSTOM ENVIRONMENT ---\n"
	text += "Submerged: " + str(player.is_submerged) + "\n"
	text += "On Ladder: " + str(player.is_on_ladder) + "\n"
	text += "Wall Raycast: " + str(player.wall_detector.is_colliding() if player.wall_detector else false) + "\n"
	text += "Ledge Raycast: " + str(player.ledge_detector.is_colliding() if player.ledge_detector else false) + "\n\n"
	
	text += "--- TIMERS & COMBAT ---\n"
	text += "Jump Buffer: " + str(snapped(player.jump_buffer_timer, 0.01)) + "\n"
	text += "Coyote Timer: " + str(snapped(player.coyote_timer, 0.01)) + "\n"
	text += "Can Double Jump: " + str(player.can_double_jump) + "\n"
	text += "Invincible: " + str(player.is_invincible) + "\n"
	
	lbl_physics.text = text

func update_anim_state(state_name: String, value: bool) -> void:
	anim_cache[state_name] = value
	
	var anim_text := "--- ANIMATION STATES ---\n"
	var keys = anim_cache.keys()
	keys.sort()
	
	for key in keys:
		var val_str = "TRUE" if anim_cache[key] else "false"
		anim_text += str(key) + ": " + val_str + "\n"
		
	lbl_anim.text = anim_text
