extends RefCounted
## Shared helpers for the code-generated development levels (tools/build_phase*_content.gd).
## Use with: const LevelBuilder := preload("res://tools/level_builder.gd")

const TILESET_PATH := "res://resources/tilesets/dev_world_tileset.tres"
const WORLD_SOURCE := 0
const PLATFORM_SOURCE := 1
const GRASS_TOP := Vector2i(0, 0)
const DIRT := Vector2i(0, 1)
const WALL := Vector2i(8, 1)
const TILE := 16


## Marks every cell in the inclusive rectangle (x0, y0)-(x1, y1).
static func fill(cells: Dictionary, x0: int, y0: int, x1: int, y1: int, value: Variant = true) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells[Vector2i(x, y)] = value


## Builds a TileMapLayer from solid cells and one-way cells (cell -> platform material row).
static func build_terrain(solid: Dictionary, one_way: Dictionary, wall_columns: Array) -> TileMapLayer:
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = load(TILESET_PATH)
	for cell: Vector2i in solid:
		terrain.set_cell(cell, WORLD_SOURCE, solid_atlas(cell, solid, wall_columns))
	for cell: Vector2i in one_way:
		terrain.set_cell(cell, PLATFORM_SOURCE, platform_atlas(cell, one_way))
	return terrain


## Wall columns use stone; other solid cells use grass on exposed tops and dirt below.
static func solid_atlas(cell: Vector2i, solid: Dictionary, wall_columns: Array) -> Vector2i:
	if cell.x in wall_columns:
		return WALL
	return DIRT if solid.has(cell + Vector2i.UP) else GRASS_TOP


## Chains platform pieces: a left cap starts each pair, a right cap ends it,
## and an isolated cell uses the short single platform.
static func platform_atlas(cell: Vector2i, one_way: Dictionary) -> Vector2i:
	var row: int = one_way[cell]
	var has_left := one_way.has(cell + Vector2i.LEFT)
	var has_right := one_way.has(cell + Vector2i.RIGHT)
	if not has_left and not has_right:
		return Vector2i(0, row)
	if not has_left or (has_right and cell.x % 2 == 0):
		return Vector2i(1, row)
	return Vector2i(2, row)


## Top-centre position for a Climbable whose top sits on tile row `top_row` in column `col`.
static func climbable_top(col: int, top_row: int) -> Vector2:
	return Vector2(col * TILE + TILE * 0.5, top_row * TILE)


static func make_label(text: String, at: Vector2, color := Color(0.1, 0.12, 0.2, 0.85)) -> Label:
	var label := Label.new()
	label.name = text.validate_node_name().replace(" ", "").replace("-", "") + "Label"
	label.text = text
	label.position = at
	label.add_theme_font_size_override(&"font_size", 8)
	label.add_theme_color_override(&"font_color", color)
	return label


## Adds `child` under `parent` and makes it part of the scene saved from `root`.
static func add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child, true)
	child.owner = root


static func save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	report(path, err)


static func report(path: String, err: Error) -> void:
	if err == OK:
		print("wrote ", path)
	else:
		push_error("failed to write %s: %s" % [path, error_string(err)])
