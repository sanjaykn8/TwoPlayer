extends RefCounted
## Visual identity of each world, from the bundle's own art (docs/ASSET_CATALOG.md §4):
## terrain material (world_tileset top / fill / pillar cells), platform style
## (platforms.png row), a banded sky, and the background scenery scattered on open floor.
## deco entries are [column, row, height in tiles] of world_tileset.png.

const THEMES := {
	"forest": {
		"top": Vector2i(0, 0), "fill": Vector2i(0, 1), "wall": Vector2i(1, 1), "platform_row": 0,
		"sky_top": Color("3f8fd0"), "sky_bottom": Color("c8ecf7"), "deco_tint": Color(0.92, 1.0, 0.92),
		"deco": [[0, 3, 3], [1, 3, 1], [1, 4, 1], [1, 5, 1], [1, 6, 1], [9, 3, 1]],
	},
	"caves": {
		"top": Vector2i(6, 0), "fill": Vector2i(6, 1), "wall": Vector2i(8, 1), "platform_row": 3,
		"sky_top": Color("07080f"), "sky_bottom": Color("1f2a44"), "deco_tint": Color(0.75, 0.85, 1.0),
		"deco": [[7, 8, 1], [8, 8, 1], [7, 7, 1], [8, 7, 1], [6, 2, 1], [6, 7, 1]],
	},
	"ruins": {
		"top": Vector2i(2, 0), "fill": Vector2i(2, 1), "wall": Vector2i(3, 1), "platform_row": 1,
		"sky_top": Color("d98c4a"), "sky_bottom": Color("f7e0a8"), "deco_tint": Color(1.0, 0.95, 0.85),
		"deco": [[2, 8, 1], [8, 3, 1], [2, 2, 1], [9, 4, 1], [5, 8, 1], [3, 0, 1]],
	},
	"lava": {
		"top": Vector2i(4, 0), "fill": Vector2i(4, 1), "wall": Vector2i(5, 1), "platform_row": 2,
		"sky_top": Color("1a0505"), "sky_bottom": Color("6e2410"), "deco_tint": Color(1.0, 0.8, 0.7),
		"deco": [[5, 3, 3], [5, 6, 1], [5, 7, 1], [5, 8, 1], [4, 8, 1], [7, 5, 1]],
	},
	"fortress": {
		"top": Vector2i(8, 0), "fill": Vector2i(8, 1), "wall": Vector2i(8, 1), "platform_row": 1,
		"sky_top": Color("120c1d"), "sky_bottom": Color("3b2a4d"), "deco_tint": Color(0.85, 0.8, 0.95),
		"deco": [[7, 3, 1], [7, 4, 1], [8, 4, 1], [9, 4, 1], [2, 8, 1], [8, 7, 1]],
	},
	"citadel": {
		"top": Vector2i(7, 0), "fill": Vector2i(7, 1), "wall": Vector2i(6, 1), "platform_row": 3,
		"sky_top": Color("1b2133"), "sky_bottom": Color("7d8fb0"), "deco_tint": Color(0.9, 0.95, 1.0),
		"deco": [[6, 3, 3], [6, 6, 1], [6, 8, 1], [6, 2, 1], [7, 3, 1]],
	},
}
