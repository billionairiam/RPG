# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 project named `OpenRPGReplay`. It is a single hand-built town map plus a `Gamepieces` node waiting for entities — no gameplay code yet (`ground.gd` is an empty stub).

## Commands

Godot 4.6.2 is installed at `/usr/local/bin/godot`:

```bash
godot -e --path .                    # open the editor
godot --path . town.tscn             # run a scene
godot --headless --path . --import   # (re)import assets without opening the editor

godot --headless --path . --script res://tools/generate_town.gd   # regenerate the map
```

There is no test framework configured (no GUT / gdUnit4) and no test directory. Do not assume a `make test` or similar entry point exists.

`.godot/` is gitignored and holds the imported texture cache. The `.import` sidecars next to each `.png` are committed and point into `.godot/imported/`, so a fresh clone must be imported before textures resolve.

## Architecture

### Everything lives in `town.tscn`

There is exactly one scene, `town.tscn`, and it is the entire game world. Its root is a `Node2D` named `Town` with `y_sort_enabled = true`, containing a fixed layer stack:

```
Town (Node2D, y_sort_enabled)
├── Ground      (TileMapLayer, has ground.gd)
├── Buildings   (TileMapLayer)
├── Trees       (TileMapLayer)
├── TreeTops    (TileMapLayer)
└── Gamepieces  (Node2D)
```

Because the root has `y_sort_enabled`, child draw order is resolved by Y position rather than tree order. `TreeTops` exists so tree canopies can sort *above* entities walking behind them. `Gamepieces` is a plain `Node2D` intended as the parent for character/entity scenes — adding entities there is what makes them y-sort against the trees.

When adding a new layer, place it in this stack deliberately; insertion order matters for sorting.

### The TileSet is defined inline, not as a shared resource

`town.tscn` declares its `TileSet` as an `[sub_resource]` containing two `TileSetAtlasSource`s (`town_tilemap.png` and `dungeon_tilemap.png`, both 12x11 grids with 1px separation). Editing the tileset in the inspector rewrites `town.tscn` itself — there is no `.tres` to edit separately. All four `TileMapLayer`s share the one `TileSet` sub-resource (`TileSet_tkreh`).

The map is 40x28 tiles of 16x16 (`203x186` atlas, `12x11` grid, 1px separation). `maps/tilesets/kenney_terrain_rebuild.tres` is an empty `TileSet` resource header that nothing references — it looks like a leftover.

### The map is generated, not hand-painted

Every cell in `town.tscn` comes from `tools/generate_town.gd`, which repaints all four layers from scratch and re-saves the scene. **Hand edits made in the editor are destroyed the next time it runs.** To change the map, edit the generator and re-run it:

```bash
godot --headless --path . --script res://tools/generate_town.gd
```

The generator holds the ground terrain as ASCII art (one character per tile, legend at the top of the file), plus coordinate lists for houses, 1x1 decorations, and 3x3 pine clumps. It preserves the scene's UID across saves, which `ResourceSaver` would otherwise drop.

### Atlas tile reference

The atlas is not labelled and several tiles are easy to misread — these were verified by rendering them in isolation. All coordinates are `(column, row)` in source 0 (`town_tilemap.png`).

| Purpose | Tiles |
| --- | --- |
| Flat dirt (seamless fill) | `(1,2)` only — `(3,3)`, `(5,3)`, `(6,3)` have grass tufts baked in |
| Dirt edge, grass above | `(1,1)` |
| Dirt edge, grass below | `(1,3)` |
| Dirt edge, grass left / right | `(0,2)` / `(2,2)` |
| Flat stone paving | `(1,9)` |
| Small trees / bushes | pine `(4,1)`, autumn `(3,1)`, bush `(5,1)`, mushrooms `(5,2)` |
| 3x3 pine clump | green `(6,0)`, autumn `(9,0)` — anchor is the **top-left** tile |
| House facade, stone | rows 4-6, cols 0-3 (`(3,4)` is a window, `(2,6)` the doorway) |
| House facade, red brick | rows 4-6, cols 4-7 |

Two traps:

- `(7,3)` looks like cobblestone but is **grass with stones** — do not use it as a road surface.
- `(0,8)`–`(2,10)` is not a floor texture; it is a 3x3 autotile for a **walled enclosure** (crenellated wall on top, wall bases on the bottom, paving inside). `tools/generate_town.gd` uses it for the walled courtyard, with a two-tile gap as the gate.

### Terrain sets and blocking

The tileset defines two terrain sets and one custom data layer:

- `terrain_set_0`: `GreenTrees 0`, `YellowTrees 1`
- `terrain_set_1`: `Dirt`, `Grass`, `Cobblestone2`
- `custom_data_layer_0`: named `IsCellBlocked`, type bool, set to `true` on a subset of tiles in the town atlas

`IsCellBlocked` is **custom data only** — the tileset defines no `physics_layer_*`, so nothing physically blocks movement yet. Any collision or pathfinding must read this custom data explicitly (e.g. via `get_cell_tile_data()`) rather than relying on engine physics.

Those flags also predate the map and do not describe it: they were set per-tile on the atlas, not per-cell, so every tile drawn from atlas rows 4-10 is flagged blocking. That happens to be right for the house facades but wrong for the courtyard paving `(1,9)`, which is walkable floor. Treat the current flags as a rough starting point and re-derive blocking from the actual map before building movement on top of it.

## Conventions

- `.uid` sidecar files (Godot 4.4+) accompany scripts and are referenced by scenes via `uid://` in `ExtResource`. Commit them and do not hand-edit or regenerate them — breaking a UID breaks the scene reference even if the path still resolves.
- `.editorconfig` is UTF-8 only; `.gitattributes` normalizes all text files to LF. Keep line endings LF.
