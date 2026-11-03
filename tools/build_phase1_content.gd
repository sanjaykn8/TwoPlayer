extends SceneTree
## Generates Phase 1 content that is impractical to write by hand.
## Run from the project root, in two passes (the PNG must be imported before use):
##   godot --headless --path . --script res://tools/build_phase1_content.gd -- art
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_phase1_content.gd -- content
## Outputs:
##   art:     res://assets/created/ladder.png
##   content: res://resources/players/knight_frames.tres
##            res://resources/tilesets/dev_world_tileset.tres
##            res://scenes/dev/phase_1_test_room.tscn

const KNIGHT_SHEET := "res://assets/sprites/knight.png"
const WORLD_SHEET := "res://assets/sprites/world_tileset.png"
const PLATFORM_SHEET := "res://assets/sprites/platforms.png"
const LADDER_PNG := "res://assets/created/ladder.png"
const FRAMES_PATH := "res://resources/players/knight_frames.tres"
const TILESET_PATH := "res://resources/tilesets/dev_world_tileset.tres"
const ROOM_PATH := "res://scenes/dev/phase_1_test_room.tscn"

const WORLD_SOURCE := 0
const PLATFORM_SOURCE := 1
const GRASS_TOP := Vector2i(0, 0)
const DIRT := Vector2i(0, 1)
const WALL := Vector2i(8, 1)
const ROOM_COLS := 40
const ROOM_ROWS := 22


func _init() -> void:
	var step := "content"
	if not OS.get_cmdline_user_args().is_empty():
		step = OS.get_cmdline_user_args()[0]
	match step:
		"art":
			_build_ladder_png()
		"content":
			_build_knight_frames()
			_build_tileset()
			_build_test_room()
		_:
			push_error("Unknown step %s (use art or content)" % step)
	quit()


# --- Art ---------------------------------------------------------------------------

## 16x16 vertically tileable ladder using the wood palette of the tileset fence (9,3).
func _build_ladder_png() -> void:
	var outline := Color("231c19")
	var light := Color("d89e58")
	var mid := Color("b66b3a")
	var dark := Color("67332d")
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		for rail: int in [2, 10]:
			img.set_pixel(rail, y, outline)
			img.set_pixel(rail + 1, y, light)
			img.set_pixel(rail + 2, y, mid)
			img.set_pixel(rail + 3, y, outline)
	for rung_top: int in [4, 12]:
		for x in range(6, 10):
			img.set_pixel(x, rung_top, outline)
			img.set_pixel(x, rung_top + 1, light)
			img.set_pixel(x, rung_top + 2, dark)
			img.set_pixel(x, rung_top + 3, outline)
	DirAccess.make_dir_recursive_absolute("res://assets/created")
	_report(LADDER_PNG, img.save_png(LADDER_PNG))


# --- Knight animations -------------------------------------------------------------

func _build_knight_frames() -> void:
	var sheet: Texture2D = load(KNIGHT_SHEET)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# Cells are (column, row) in 32x32 units; see docs/ASSET_CATALOG.md. Label cells are never used.
	_add_animation(frames, sheet, &"idle", _row(0, 0, 4), 6.0, true)
	_add_animation(frames, sheet, &"run", _row(2, 0, 8) + _row(3, 0, 8), 16.0, true)
	_add_animation(frames, sheet, &"jump", [Vector2i(0, 2)], 1.0, true)      # placeholder: run stride
	_add_animation(frames, sheet, &"fall", [Vector2i(7, 5)], 1.0, true)      # placeholder: roll recovery
	_add_animation(frames, sheet, &"crouch", [Vector2i(2, 5)], 1.0, true)    # placeholder: compact roll pose
	_add_animation(frames, sheet, &"climb", [Vector2i(0, 0)], 1.0, true)     # placeholder: idle, flipped in code
	_add_animation(frames, sheet, &"hurt", _row(6, 0, 4), 10.0, false)
	_add_animation(frames, sheet, &"death", _row(7, 0, 4), 8.0, false)
	DirAccess.make_dir_recursive_absolute(FRAMES_PATH.get_base_dir())
	_report(FRAMES_PATH, ResourceSaver.save(frames, FRAMES_PATH))


func _row(row: int, first: int, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c in range(first, first + count):
		cells.append(Vector2i(c, row))
	return cells


func _add_animation(frames: SpriteFrames, sheet: Texture2D, anim: StringName,
		cells: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for cell: Vector2i in cells:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(cell.x * 32, cell.y * 32, 32, 32)
		atlas.filter_clip = true
		frames.add_frame(anim, atlas)


# --- Tileset -----------------------------------------------------------------------

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)   # world
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 2)   # one_way
	ts.set_physics_layer_collision_mask(1, 0)

	var world := TileSetAtlasSource.new()
	world.texture = load(WORLD_SHEET)
	world.texture_region_size = Vector2i(16, 16)
	ts.add_source(world, WORLD_SOURCE)
	var square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	# Terrain rows 0-2, columns 0-8 are full 16x16 blocks (docs/ASSET_CATALOG.md section 4).
	for y in 3:
		for x in 9:
			var coords := Vector2i(x, y)
			world.create_tile(coords)
			var data := world.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)

	var platforms := TileSetAtlasSource.new()
	platforms.texture = load(PLATFORM_SHEET)
	platforms.texture_region_size = Vector2i(16, 16)
	ts.add_source(platforms, PLATFORM_SOURCE)
	# Platform art is 9 px tall at the top of the cell; collide with the top 6 px, one-way.
	var slab := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -2), Vector2(-8, -2)])
	for y in 4:
		for x in 3:
			var coords := Vector2i(x, y)
			platforms.create_tile(coords)
			var data := platforms.get_tile_data(coords, 0)
			data.add_collision_polygon(1)
			data.set_collision_polygon_points(1, 0, slab)
			data.set_collision_polygon_one_way(1, 0, true)
	DirAccess.make_dir_recursive_absolute(TILESET_PATH.get_base_dir())
	_report(TILESET_PATH, ResourceSaver.save(ts, TILESET_PATH))


# --- Test room ---------------------------------------------------------------------

func _build_test_room() -> void:
	var solid := {}
	var one_way := {}  # cell -> platform material row
	_fill(solid, 0, 0, 0, ROOM_ROWS - 1)                          # left wall
	_fill(solid, ROOM_COLS - 1, 0, ROOM_COLS - 1, ROOM_ROWS - 1)  # right wall
	_fill(solid, 1, 20, ROOM_COLS - 2, 21)    # floor, surface at y = 320
	_fill(solid, 10, 19, 11, 19)              # 1-tile step (edge at ground level)
	_fill(solid, 13, 17, 18, 18)              # low-ceiling slab: 16 px gap, crouch only
	_fill(solid, 21, 17, 27, 17)              # corridor ceiling: 32 px gap, no jumping over
	_fill(solid, 23, 14, 26, 14)              # floating solid platform
	_fill(solid, 31, 11, 38, 11)              # high ledge (platform edge at x = 480)
	_fill(solid, 32, 4, 33, 4)                # passage exit, left
	_fill(solid, 37, 4, 38, 4)                # passage exit, right
	_fill(one_way, 2, 17, 6, 17, 0)           # one-way stack over the spawn area
	_fill(one_way, 4, 14, 8, 14, 0)
	_fill(one_way, 2, 11, 6, 11, 0)
	_fill(one_way, 30, 11, 30, 11, 1)         # ladder top
	_fill(one_way, 34, 4, 36, 4, 1)           # passage top

	var root := Node2D.new()
	root.name = "Phase1TestRoom"
	root.set_script(load("res://scenes/dev/phase_1_test_room.gd"))

	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color(0.42, 0.72, 0.92)
	sky.size = Vector2(640, 360)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, root, sky)

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = load(TILESET_PATH)
	for cell: Vector2i in solid:
		terrain.set_cell(cell, WORLD_SOURCE, _solid_atlas(cell, solid))
	for cell: Vector2i in one_way:
		terrain.set_cell(cell, PLATFORM_SOURCE, _platform_atlas(cell, one_way))
	_add(root, root, terrain)

	var climbables := Node2D.new()
	climbables.name = "Climbables"
	_add(root, root, climbables)
	var ladder: Node2D = load("res://scenes/objects/ladder.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ladder.name = "Ladder"
	ladder.position = Vector2(30 * 16 + 8, 11 * 16)
	ladder.set(&"size", Vector2(16, 9 * 16))
	_add(root, climbables, ladder)
	var passage: Node2D = load("res://scenes/objects/climb_passage.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	passage.name = "Passage"
	passage.position = Vector2(35 * 16 + 8, 4 * 16)
	passage.set(&"size", Vector2(48, 7 * 16))
	_add(root, climbables, passage)

	var labels := Node2D.new()
	labels.name = "Labels"
	_add(root, root, labels)
	var label_spots := {
		"ONE-WAY": Vector2(44, 150), "STEP": Vector2(156, 292), "CROUCH": Vector2(222, 262),
		"CORRIDOR": Vector2(352, 262), "LADDER": Vector2(436, 290), "EDGE": Vector2(474, 164),
		"LANDING": Vector2(552, 290), "PASSAGE": Vector2(546, 52),
	}
	for text: String in label_spots:
		var label := Label.new()
		label.name = text.replace("-", "") + "Label"
		label.text = text
		label.position = label_spots[text]
		label.add_theme_font_size_override(&"font_size", 8)
		label.add_theme_color_override(&"font_color", Color(0.1, 0.12, 0.2, 0.85))
		_add(root, labels, label)

	var spawn_1 := Marker2D.new()
	spawn_1.name = "SpawnP1"
	spawn_1.position = Vector2(4 * 16 + 8, 320)
	_add(root, root, spawn_1)
	var spawn_2 := Marker2D.new()
	spawn_2.name = "SpawnP2"
	spawn_2.position = Vector2(8 * 16 + 8, 320)
	_add(root, root, spawn_2)

	var knights := Node2D.new()
	knights.name = "Knights"
	_add(root, root, knights)
	var knight_scene: PackedScene = load("res://scenes/players/knight.tscn")
	for i in 2:
		var knight: Node2D = knight_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		knight.name = "Knight%d" % (i + 1)
		knight.position = spawn_1.position if i == 0 else spawn_2.position
		knight.set(&"profile", load("res://resources/players/p%d_profile.tres" % (i + 1)))
		knight.set(&"show_debug_tag", true)
		_add(root, knights, knight)

	var hud: Node = load("res://scenes/dev/input_debug_hud.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	hud.name = "InputDebugHud"
	_add(root, root, hud)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		_report(ROOM_PATH, err)
		return
	_report(ROOM_PATH, ResourceSaver.save(packed, ROOM_PATH))
	root.free()


func _fill(cells: Dictionary, x0: int, y0: int, x1: int, y1: int, value: Variant = true) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells[Vector2i(x, y)] = value


func _solid_atlas(cell: Vector2i, solid: Dictionary) -> Vector2i:
	if cell.x == 0 or cell.x == ROOM_COLS - 1:
		return WALL
	return DIRT if solid.has(cell + Vector2i.UP) else GRASS_TOP


## Chains platform pieces: a left cap starts each pair, a right cap ends it,
## and an isolated cell uses the short single platform.
func _platform_atlas(cell: Vector2i, one_way: Dictionary) -> Vector2i:
	var row: int = one_way[cell]
	var has_left := one_way.has(cell + Vector2i.LEFT)
	var has_right := one_way.has(cell + Vector2i.RIGHT)
	if not has_left and not has_right:
		return Vector2i(0, row)
	if not has_left or (has_right and cell.x % 2 == 0):
		return Vector2i(1, row)
	return Vector2i(2, row)


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


func _report(path: String, err: Error) -> void:
	if err == OK:
		print("wrote ", path)
	else:
		push_error("failed to write %s: %s" % [path, error_string(err)])
