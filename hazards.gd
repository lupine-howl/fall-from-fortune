extends TileMapLayer

func _ready() -> void:
	_convert_tiles_to_scenes()

func _convert_tiles_to_scenes() -> void:
	var used_cells = get_used_cells()
	
	# Try to find a node named "Enemies" belonging to the same parent level.
	# If you make the "Enemies" node a Scene Unique Node (%), you can use get_node("%Enemies")
	var target_container = get_parent().get_node_or_null("Enemies")
	
	# Safety fallback: If you forgot to build the container in the editor,
	# it just defaults to using the root parent so the game doesn't crash.
	if target_container == null:
		target_container = get_parent()
	
	for cell_pos in used_cells:
		var tile_data: TileData = get_cell_tile_data(cell_pos)
		
		if tile_data:
			var object_scene = tile_data.get_custom_data("spawn_scene")
			
			if object_scene is PackedScene:
				var instance = object_scene.instantiate()
				
				# Calculate center position and spawn it
				instance.global_position = map_to_local(cell_pos)
				
				# Put it directly into the container we found
				target_container.add_child.call_deferred(instance)
				
				# Erase the placeholder tile
				erase_cell(cell_pos)
