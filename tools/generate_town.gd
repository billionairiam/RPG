@tool
extends SceneTree
## Regenerates the town map inside res://town.tscn.
##
##   godot --headless --path . --script res://tools/generate_town.gd
##
## map1.png is the visible map. The generated TileMap layers remain hidden as
## scaffolding for future navigation, collision, and interactive overlays.

const SRC := 0  # TileSetAtlasSource 0 = maps/tilesets/town_tilemap.png
const SCENE_PATH := "res://town.tscn"
const SCENE_UID := "uid://ym64rrpsg8qh"  # unchanged since before the map existed
const BACKGROUND_PATH := "res://maps/tilesets/map1.png"
const NAVIGATION_SCRIPT := preload("res://map_navigation.gd")
const MAP_SIZE := Vector2i(40, 36)
const NAVIGATION_SIZE := Vector2i(79, 79)

static var WATER_POLYGONS := [
	PackedVector2Array([
		Vector2(710, 0), Vector2(815, 0), Vector2(815, 105), Vector2(840, 145),
		Vector2(825, 220), Vector2(875, 255), Vector2(860, 625),
		Vector2(750, 625), Vector2(760, 350), Vector2(720, 275),
	]),
	PackedVector2Array([
		Vector2(0, 790), Vector2(75, 790), Vector2(95, 825), Vector2(210, 825),
		Vector2(245, 900), Vector2(350, 920), Vector2(420, 1030),
		Vector2(385, 1135), Vector2(260, 1160), Vector2(0, 1150),
	]),
	PackedVector2Array([
		Vector2(950, 885), Vector2(1254, 900), Vector2(1254, 1254),
		Vector2(885, 1254), Vector2(900, 1090), Vector2(930, 1030),
	]),
]

# Large solid features traced from map1.png. Thin decorative fences intentionally
# remain walkable so the 16 px navigation grid does not create narrow dead ends.
const BLOCKED_RECTS := [
	Rect2i(0, 0, 1254, 32), Rect2i(0, 1222, 1254, 32),
	Rect2i(0, 0, 32, 1254), Rect2i(1222, 0, 32, 1254),
	Rect2i(38, 170, 205, 190), Rect2i(28, 475, 240, 180),
	Rect2i(925, 300, 225, 220), Rect2i(650, 675, 300, 185),
	Rect2i(0, 880, 255, 175), Rect2i(525, 950, 270, 220),
	Rect2i(510, 510, 135, 115), Rect2i(1080, 32, 70, 105),
	Rect2i(1030, 500, 150, 130), Rect2i(205, 365, 135, 95),
]

const TREE_BLOCKERS := [
	Vector2i(65, 55), Vector2i(250, 30), Vector2i(330, 55), Vector2i(470, 15),
	Vector2i(550, 35), Vector2i(625, 95), Vector2i(675, 165), Vector2i(900, 55),
	Vector2i(970, 90), Vector2i(1040, 45), Vector2i(1180, 100), Vector2i(315, 170),
	Vector2i(390, 205), Vector2i(445, 195), Vector2i(310, 310), Vector2i(410, 350),
	Vector2i(520, 325), Vector2i(680, 395), Vector2i(800, 575), Vector2i(1200, 380),
	Vector2i(300, 555), Vector2i(310, 680), Vector2i(405, 760), Vector2i(470, 735),
	Vector2i(1030, 690), Vector2i(1130, 715), Vector2i(1190, 660), Vector2i(980, 790),
	Vector2i(1080, 800), Vector2i(1170, 790), Vector2i(440, 850), Vector2i(480, 1010),
	Vector2i(390, 1120), Vector2i(300, 1180), Vector2i(570, 1210), Vector2i(830, 1120),
	Vector2i(930, 1050), Vector2i(1050, 1170), Vector2i(1160, 1140),
]

const LEGEND := {
	".": Vector2i(0, 0),    # grass
	",": Vector2i(1, 0),    # grass, tufts
	"*": Vector2i(2, 0),    # grass, dandelions
	"#": Vector2i(1, 2),    # dirt
	"^": Vector2i(1, 1),    # dirt, grass along its top edge
	"v": Vector2i(1, 3),    # dirt, grass along its bottom edge
	"<": Vector2i(0, 2),    # dirt, grass along its left edge
	">": Vector2i(2, 2),    # dirt, grass along its right edge
	"P": Vector2i(1, 9),    # courtyard paving
	"A": Vector2i(0, 8), "T": Vector2i(1, 8), "D": Vector2i(2, 8),   # courtyard wall, top
	"L": Vector2i(0, 9), "R": Vector2i(2, 9),                         # courtyard wall, sides
	"E": Vector2i(0, 10), "U": Vector2i(1, 10), "F": Vector2i(2, 10), # courtyard wall, bottom
}

# Rectangles are [x, y, width, height]. Overlapping paths form natural junctions.
const PATH_RECTS := [
	Rect2i(18, 0, 3, 36),
	Rect2i(0, 16, 40, 3),
	Rect2i(18, 8, 20, 3),
	Rect2i(7, 16, 3, 13),
	Rect2i(0, 27, 21, 3),
	Rect2i(30, 8, 3, 11),
	Rect2i(28, 17, 3, 13),
	Rect2i(18, 32, 15, 3),
]

const PLAZA := Rect2i(13, 12, 14, 12)

# [x, y, tile] adds a little variation without obscuring walkable routes.
const GROUND_DECOR := [
	[4, 4, "*"], [10, 3, ","], [15, 5, "*"], [23, 3, ","], [35, 4, "*"],
	[2, 12, ","], [7, 13, "*"], [11, 11, ","], [28, 13, "*"], [36, 14, ","],
	[2, 23, "*"], [12, 25, ","], [24, 27, "*"], [35, 23, ","], [37, 27, "*"],
	[4, 32, ","], [11, 33, "*"], [24, 31, ","], [35, 32, "*"],
]

# --- houses: [x, y, "stone"|"red"], anchor is the TOP-LEFT tile (4x3) -------
const HOUSES := [
	[4, 6, "stone"], [11, 7, "red"], [23, 5, "stone"], [33, 11, "red"],
	[3, 21, "red"], [10, 24, "stone"], [23, 26, "red"], [33, 27, "stone"],
]

# --- 1x1 decorations: [x, y, kind] -----------------------------------------
const TREES := [
	[3, 4, "pine"], [9, 4, "autumn"], [15, 3, "bush"], [24, 3, "pine"],
	[35, 6, "autumn"], [3, 11, "bush"], [8, 12, "pine"], [14, 10, "autumn"],
	[24, 10, "bush"], [28, 6, "pine"], [36, 20, "autumn"], [3, 25, "bush"],
	[12, 31, "pine"], [25, 32, "autumn"], [35, 24, "pine"], [34, 33, "bush"],
	[11, 15, "mushroom"], [29, 14, "mushroom"], [11, 21, "bush"], [28, 23, "autumn"],
	[6, 14, "mushroom"], [16, 26, "pine"], [22, 29, "mushroom"], [37, 25, "bush"],
]

# --- 3x3 pine clumps: [x, y, "green"|"autumn"], anchor is TOP-LEFT ---------
const CLUMPS := [
	[0, 0, "green"], [3, 0, "autumn"], [6, 0, "green"], [12, 0, "green"],
	[15, 0, "autumn"], [21, 0, "green"], [27, 0, "autumn"], [30, 0, "green"],
	[33, 0, "green"], [37, 0, "autumn"], [0, 3, "autumn"], [37, 3, "green"],
	[0, 9, "green"], [37, 9, "autumn"], [0, 18, "green"], [37, 18, "green"],
	[0, 30, "autumn"], [37, 30, "green"], [0, 33, "green"], [3, 33, "green"],
	[6, 33, "autumn"], [9, 33, "green"], [15, 33, "autumn"], [21, 33, "green"],
	[27, 33, "green"], [33, 33, "autumn"], [37, 33, "green"],
]

const HOUSE_TILES := {
	"stone": [[Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)],
	          [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)],
	          [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6)]],
	"red":   [[Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)],
	          [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)],
	          [Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6)]],
}

const SMALL_TILES := {
	"pine": Vector2i(4, 1), "autumn": Vector2i(3, 1),
	"bush": Vector2i(5, 1), "mushroom": Vector2i(5, 2),
}

const CLUMP_ORIGIN := {"green": Vector2i(6, 0), "autumn": Vector2i(9, 0)}  # 3x3 block


func _build_navigation_tileset(source_tileset: TileSet) -> TileSet:
	var tileset := source_tileset.duplicate(true) as TileSet
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(1, "TerrainType")
	tileset.set_custom_data_layer_type(1, TYPE_STRING)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	var atlas := tileset.get_source(SRC) as TileSetAtlasSource
	var ground_data := atlas.get_tile_data(Vector2i(0, 0), 0)
	ground_data.set_custom_data("IsCellBlocked", false)
	ground_data.set_custom_data("TerrainType", "ground")

	var water_data := atlas.get_tile_data(Vector2i(7, 3), 0)
	water_data.set_custom_data("IsCellBlocked", true)
	water_data.set_custom_data("TerrainType", "water")
	_add_full_cell_collision(water_data)

	var obstacle_data := atlas.get_tile_data(Vector2i(8, 3), 0)
	obstacle_data.set_custom_data("IsCellBlocked", true)
	obstacle_data.set_custom_data("TerrainType", "obstacle")
	_add_full_cell_collision(obstacle_data)
	return tileset


func _add_full_cell_collision(tile_data: TileData) -> void:
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(
		0,
		0,
		PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
		]),
	)


func _navigation_terrain_at(pixel: Vector2) -> String:
	for polygon in WATER_POLYGONS:
		if Geometry2D.is_point_in_polygon(pixel, polygon):
			return "water"
	for rect in BLOCKED_RECTS:
		if rect.has_point(Vector2i(pixel)):
			return "obstacle"
	for tree in TREE_BLOCKERS:
		if pixel.distance_squared_to(tree) <= 24.0 * 24.0:
			return "obstacle"
	return "ground"


func _paint_navigation(navigation: TileMapLayer) -> void:
	const TILES := {
		"ground": Vector2i(0, 0),
		"water": Vector2i(7, 3),
		"obstacle": Vector2i(8, 3),
	}
	navigation.clear()
	for y in NAVIGATION_SIZE.y:
		for x in NAVIGATION_SIZE.x:
			var cell := Vector2i(x, y)
			var terrain := _navigation_terrain_at(Vector2(cell * 16) + Vector2(8, 8))
			navigation.set_cell(cell, SRC, TILES[terrain])

	# Bridges and stairs cross otherwise blocked water and cliff areas.
	for rect in [Rect2i(46, 15, 10, 5), Rect2i(9, 53, 13, 4), Rect2i(17, 65, 8, 4)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				navigation.set_cell(Vector2i(x, y), SRC, TILES["ground"])


func _paint_ground(ground: TileMapLayer) -> int:
	var dirt := {}
	for rect in PATH_RECTS:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				dirt[Vector2i(x, y)] = true

	var decor := {}
	for item in GROUND_DECOR:
		decor[Vector2i(item[0], item[1])] = item[2]

	var placed := 0
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var tile := Vector2i(0, 0)
			if PLAZA.has_point(cell):
				tile = LEGEND["P"]
			elif dirt.has(cell):
				tile = LEGEND["#"]
				if not dirt.has(cell + Vector2i.UP):
					tile = LEGEND["^"]
				elif not dirt.has(cell + Vector2i.DOWN):
					tile = LEGEND["v"]
				elif not dirt.has(cell + Vector2i.LEFT):
					tile = LEGEND["<"]
				elif not dirt.has(cell + Vector2i.RIGHT):
					tile = LEGEND[">"]
			elif decor.has(cell):
				tile = LEGEND[decor[cell]]
			ground.set_cell(cell, SRC, tile)
			placed += 1
	return placed


func _initialize() -> void:
	var packed: PackedScene = load("res://town.tscn")
	var town := packed.instantiate()

	var ground: TileMapLayer = town.get_node("Ground")
	var buildings: TileMapLayer = town.get_node("Buildings")
	var trees: TileMapLayer = town.get_node("Trees")
	var tops: TileMapLayer = town.get_node("TreeTops")
	var layers: Array[TileMapLayer] = [ground, buildings, trees, tops]

	var background := town.get_node_or_null("Map1Background") as Sprite2D
	if background == null:
		background = Sprite2D.new()
		background.name = "Map1Background"
		town.add_child(background)
		background.owner = town
	background.texture = load(BACKGROUND_PATH)
	background.centered = false
	background.z_index = -100
	town.move_child(background, 0)

	var navigation := town.get_node_or_null("Navigation") as TileMapLayer
	if navigation == null:
		navigation = TileMapLayer.new()
		navigation.name = "Navigation"
		town.add_child(navigation)
		navigation.owner = town
	navigation.set_script(NAVIGATION_SCRIPT)
	navigation.tile_set = _build_navigation_tileset(ground.tile_set)
	navigation.visible = false
	navigation.collision_enabled = true
	_paint_navigation(navigation)

	# Buildings/Trees/TreeTops ship with empty TileSets; share the painted one.
	var tileset: TileSet = ground.tile_set
	for layer in [buildings, trees, tops]:
		layer.tile_set = tileset

	for layer in layers:
		layer.clear()
		layer.visible = false

	var placed := 0

	placed += _paint_ground(ground)

	for h in HOUSES:
		var tiles: Array = HOUSE_TILES[h[2]]
		for dy in tiles.size():
			for dx in tiles[dy].size():
				buildings.set_cell(Vector2i(h[0] + dx, h[1] + dy), SRC, tiles[dy][dx])
				placed += 1

	for t in TREES:
		trees.set_cell(Vector2i(t[0], t[1]), SRC, SMALL_TILES[t[2]])
		placed += 1

	for c in CLUMPS:
		var origin: Vector2i = CLUMP_ORIGIN[c[2]]
		for dy in 3:
			for dx in 3:
				var cell := Vector2i(c[0] + dx, c[1] + dy)
				# the top row is canopy: it rides the TreeTops layer so it always
				# draws over anything standing behind the clump.
				var layer := tops if dy == 0 else trees
				layer.set_cell(cell, SRC, origin + Vector2i(dx, dy))
				placed += 1

	var out := PackedScene.new()
	var err := out.pack(town)
	assert(err == OK, "pack failed: %d" % err)
	err = ResourceSaver.save(out, SCENE_PATH)
	assert(err == OK, "save failed: %d" % err)

	# ResourceSaver drops the scene's own UID, so put it back. Without this the
	# scene loses its identity every time the map is regenerated.
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	if lines[0].begins_with("[gd_scene") and not lines[0].contains("uid="):
		lines[0] = '[gd_scene format=4 uid="%s"]' % SCENE_UID
		var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
		w.store_string("\n".join(lines))
		w.close()

	print("generate_town: placed %d cells -> %s" % [placed, SCENE_PATH])
	town.free()
	quit()
