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
const MAP_SIZE := Vector2i(40, 36)

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
