class_name MapNavigation
extends TileMapLayer


func terrain_at_world_position(world_position: Vector2) -> String:
	var tile_data := get_cell_tile_data(local_to_map(to_local(world_position)))
	if tile_data == null:
		return "outside"
	return tile_data.get_custom_data("TerrainType")


func is_walkable_at_world_position(world_position: Vector2) -> bool:
	var tile_data := get_cell_tile_data(local_to_map(to_local(world_position)))
	return tile_data != null and not tile_data.get_custom_data("IsCellBlocked")
