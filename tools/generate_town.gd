@tool
extends SceneTree
## Regenerates the town map inside res://town.tscn.
##
##   godot --headless --path . --script res://tools/generate_town.gd
##
## Ground terrain is authored below as ASCII art (one character per 16x16 tile).
## Houses and trees are placed from the coordinate lists further down.

const SRC := 0  # TileSetAtlasSource 0 = maps/tilesets/town_tilemap.png
const SCENE_PATH := "res://town.tscn"
const SCENE_UID := "uid://ym64rrpsg8qh"  # unchanged since before the map existed

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

const GROUND := [
	"............................,..*........",
	".......................,................",
	"...,..*.......,....,....................",
	"..*.....*.......,.^^....................",
	"...*..............<>.....ATTTTTTD.......",
	".............**...<>..,..LPPPPPPR.......",
	"...............,..<>.....LPPPPPPR.......",
	"...,...,..........<>.....LPPPPPPR.......",
	".*.....*..........<>.....LPPPPPPR.....,,",
	"......,..*........<>....,LPPPPPPR.......",
	"..................<>*...,LPPPPPPR.......",
	"...............,..<>.....EUU##UUF.......",
	"...^^^^^^^^^^^^^^^##^^^^^^^^##^^^^^^^^..",
	"...<#################################>..",
	"...vvvvvvvvvvvvvvv##vvvvvvvvvvvvvvvvvv..",
	"..................<>.........,..........",
	"..............,...<>......,.............",
	"...........,...,..<>....................",
	"............*.....<>...,................",
	"..................<>......,.............",
	"......,........,..<>.,.......,..........",
	"..................<>....................",
	"................,.<>.*.......,.....,....",
	".................,<>....,...............",
	".............,...,<>,..*................",
	",.................vv,....*.....*........",
	",,......,...................,...........",
	".........,.,...,.....................*..",
]

# --- houses: [x, y, "stone"|"red"], anchor is the TOP-LEFT tile (4x3) -------
const HOUSES := [
	[4, 9, "stone"], [6, 20, "stone"], [9, 16, "stone"], [13, 9, "stone"],
	[21, 18, "stone"], [33, 16, "stone"], [4, 16, "red"], [9, 9, "red"],
	[12, 21, "red"], [13, 16, "red"], [27, 19, "red"], [33, 9, "red"],
]

# --- 1x1 decorations: [x, y, kind] -----------------------------------------
const TREES := [
	[4, 3, "pine"], [17, 3, "autumn"], [35, 3, "bush"], [37, 15, "autumn"], [5, 22, "autumn"],
	[16, 22, "pine"], [34, 20, "bush"], [26, 25, "pine"], [13, 6, "mushroom"], [21, 5, "pine"],
	[36, 8, "autumn"], [9, 19, "bush"], [30, 17, "mushroom"], [22, 21, "autumn"], [3, 8, "pine"],
	[11, 25, "pine"], [7, 6, "pine"], [21, 9, "bush"], [23, 14, "pine"], [8, 24, "bush"],
	[32, 22, "pine"], [36, 21, "autumn"], [30, 24, "autumn"], [2, 11, "bush"], [13, 24, "mushroom"],
]

# --- 3x3 pine clumps: [x, y, "green"|"autumn"], anchor is TOP-LEFT ---------
const CLUMPS := [
	[0, 0, "green"], [0, 25, "green"], [3, 25, "green"], [6, 25, "autumn"], [9, 0, "green"],
	[12, 0, "autumn"], [15, 0, "green"], [15, 25, "autumn"], [18, 25, "green"], [21, 25, "green"],
	[24, 0, "green"], [27, 0, "green"], [30, 0, "autumn"], [30, 25, "green"], [33, 25, "autumn"],
	[36, 25, "green"], [0, 3, "green"], [37, 3, "autumn"], [37, 6, "green"], [37, 9, "autumn"],
	[0, 12, "green"], [0, 15, "green"], [0, 18, "green"], [37, 18, "green"], [37, 21, "autumn"],
	[37, 24, "green"],
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


func _initialize() -> void:
	var packed: PackedScene = load("res://town.tscn")
	var town := packed.instantiate()

	var ground: TileMapLayer = town.get_node("Ground")
	var buildings: TileMapLayer = town.get_node("Buildings")
	var trees: TileMapLayer = town.get_node("Trees")
	var tops: TileMapLayer = town.get_node("TreeTops")

	# Buildings/Trees/TreeTops ship with empty TileSets; share the painted one.
	var tileset: TileSet = ground.tile_set
	for layer in [buildings, trees, tops]:
		layer.tile_set = tileset

	for layer in [ground, buildings, trees, tops]:
		layer.clear()

	var placed := 0

	for y in GROUND.size():
		var row: String = GROUND[y]
		for x in row.length():
			var ch := row[x]
			assert(LEGEND.has(ch), "unknown ground char '%s' at %d,%d" % [ch, x, y])
			ground.set_cell(Vector2i(x, y), SRC, LEGEND[ch])
			placed += 1

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
