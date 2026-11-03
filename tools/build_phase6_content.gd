extends SceneTree
## Generates Phase 6 content.
##   godot --headless --path . --script res://tools/build_phase6_content.gd -- art
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_phase6_content.gd -- content
## art:     res://assets/created/spikes.png (16x16, the bundle has no spikes)
## content: res://scenes/dev/hazard_test_level.tscn, res://scenes/dev/hazard_test_room.tscn

const LevelBuilder := preload("res://tools/level_builder.gd")
const SPIKES_PNG := "res://assets/created/spikes.png"
const LEVEL_PATH := "res://scenes/dev/hazard_test_level.tscn"
const ROOM_PATH := "res://scenes/dev/hazard_test_room.tscn"
const COLS := 112
const ROWS := 34
const T := LevelBuilder.TILE
const FLOOR_Y := 32 * T  # 512

# Knight / tileset palette (docs/ASSET_CATALOG.md).
const OUTLINE := Color("0e0d0e")
const STEEL_LIGHT := Color("b3aaa1")
const STEEL_DARK := Color("7c776f")
const HIGHLIGHT := Color("eadfd1")


func _init() -> void:
	var step := "content"
	if not OS.get_cmdline_user_args().is_empty():
		step = OS.get_cmdline_user_args()[0]
	match step:
		"art":
			_build_spikes_png()
		"content":
			_build_level()
			_build_room()
		_:
			push_error("Unknown step %s (use art or content)" % step)
	quit()


## Three steel spikes standing on the bottom of a 16x16 cell; tips at y = 8.
func _build_spikes_png() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for base_x: int in [0, 5, 10]:
		for y in range(8, 16):
			var half := int((y - 8) * 0.5) + 1          # 1..4 px half-width going down
			var cx := base_x + 3
			for x in range(cx - half, cx + half):
				if x < 0 or x > 15:
					continue
				var edge := x == cx - half or x == cx + half - 1 or y == 15
				var colour := OUTLINE if edge else (STEEL_LIGHT if x < cx else STEEL_DARK)
				img.set_pixel(x, y, colour)
		img.set_pixel(base_x + 2, 8, HIGHLIGHT)
		img.set_pixel(base_x + 3, 8, OUTLINE)
	DirAccess.make_dir_recursive_absolute("res://assets/created")
	LevelBuilder.report(SPIKES_PNG, img.save_png(SPIKES_PNG))


func _build_level() -> void:
	var solid := {}
	var one_way := {}
	var fill := LevelBuilder.fill
	fill.call(solid, 0, 0, 0, ROWS - 1)
	fill.call(solid, COLS - 1, 0, COLS - 1, ROWS - 1)
	fill.call(solid, 1, 0, COLS - 2, 0)
	fill.call(solid, 1, 32, COLS - 2, 33)       # floor, y = 512; pits are carved out below
	for x in range(16, 20):                      # hot-ground section (its own solid body)
		solid.erase(Vector2i(x, 32)); solid.erase(Vector2i(x, 33))
	for x in range(22, 26):                      # lava pit, 16 px deep (row 33 stays)
		solid.erase(Vector2i(x, 32))
	for pit: Array in [[28, 30], [35, 44], [56, 63], [65, 72], [74, 81]]:
		for x in range(pit[0], pit[1] + 1):      # bottomless pits
			solid.erase(Vector2i(x, 32)); solid.erase(Vector2i(x, 33))
	fill.call(solid, 48, 21, 54, 21)             # high ledge reached by the vertical platform

	var root := Node2D.new()
	root.name = "HazardTestLevel"
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color(0.42, 0.72, 0.92)
	sky.size = Vector2(COLS * T, ROWS * T)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	LevelBuilder.add(root, root, sky)
	LevelBuilder.add(root, root, LevelBuilder.build_terrain(solid, one_way, [0, COLS - 1]))
	var bounds: Node2D = (load("res://components/camera/camera_bounds.gd") as GDScript).new()
	bounds.name = "CameraBounds"
	bounds.set(&"size", Vector2(COLS * T, ROWS * T))
	LevelBuilder.add(root, root, bounds)

	var hazards := Node2D.new()
	hazards.name = "Hazards"
	LevelBuilder.add(root, root, hazards)
	# [name, scene, top-left, size]
	for h: Array in [
			["Spikes", "res://scenes/hazards/spikes.tscn", Vector2(160, FLOOR_Y - 16), Vector2(48, 16)],
			["HotGround", "res://scenes/hazards/hot_ground.tscn", Vector2(256, FLOOR_Y), Vector2(64, 32)],
			["Lava", "res://scenes/hazards/lava.tscn", Vector2(352, FLOOR_Y), Vector2(64, 16)],
			["FallBoundary", "res://scenes/hazards/fall_boundary.tscn", Vector2(0, ROWS * T + 32), Vector2(COLS * T, 64)]]:
		var hazard: Node2D = (load(h[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		hazard.name = h[0]
		hazard.position = h[2]
		hazard.set(&"size", h[3])
		LevelBuilder.add(root, hazards, hazard)

	var platforms := Node2D.new()
	platforms.name = "Platforms"
	LevelBuilder.add(root, root, platforms)
	# [name, scene, top-left, properties]
	for p: Array in [
			["MovingH", "res://scenes/platforms/moving_platform.tscn", Vector2(576, 480), {"width_tiles": 3, "travel": Vector2(80, 0)}],
			["MovingV", "res://scenes/platforms/moving_platform.tscn", Vector2(736, 496), {"width_tiles": 2, "travel": Vector2(0, -160), "one_way": false}],
			["TimedA", "res://scenes/platforms/timed_platform.tscn", Vector2(912, 480), {"width_tiles": 2}],
			["TimedB", "res://scenes/platforms/timed_platform.tscn", Vector2(976, 480), {"width_tiles": 2, "start_offset": 2.0}],
			["BlinkA", "res://scenes/platforms/disappearing_platform.tscn", Vector2(1056, 480), {"width_tiles": 2}],
			["BlinkB", "res://scenes/platforms/disappearing_platform.tscn", Vector2(1120, 480), {"width_tiles": 2, "start_offset": 1.5}],
			["CrumbleA", "res://scenes/platforms/collapsing_platform.tscn", Vector2(1200, 480), {"width_tiles": 2}],
			["CrumbleB", "res://scenes/platforms/collapsing_platform.tscn", Vector2(1264, 480), {"width_tiles": 2}]]:
		var platform: Node2D = (load(p[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		platform.name = p[0]
		platform.position = p[2]
		for key: String in p[3]:
			platform.set(key, p[3][key])
		LevelBuilder.add(root, platforms, platform)

	var labels := Node2D.new()
	labels.name = "Labels"
	LevelBuilder.add(root, root, labels)
	var label_spots := {
		"SPIKES": Vector2(164, 470), "HOT GROUND": Vector2(254, 480), "LAVA": Vector2(368, 480),
		"PIT": Vector2(458, 480), "H-MOVE": Vector2(612, 440), "V-MOVE": Vector2(726, 300),
		"LEDGE": Vector2(800, 312), "TIMED": Vector2(944, 440), "BLINK": Vector2(1090, 440),
		"CRUMBLE": Vector2(1226, 440), "LANDING": Vector2(1400, 480),
	}
	for text: String in label_spots:
		LevelBuilder.add(root, labels, LevelBuilder.make_label(text, label_spots[text]))

	var spawn_1 := Marker2D.new()
	spawn_1.name = "SpawnP1"
	spawn_1.position = Vector2(40, FLOOR_Y)
	LevelBuilder.add(root, root, spawn_1)
	var spawn_2 := Marker2D.new()
	spawn_2.name = "SpawnP2"
	spawn_2.position = Vector2(72, FLOOR_Y)
	LevelBuilder.add(root, root, spawn_2)
	var knights := Node2D.new()
	knights.name = "Knights"
	LevelBuilder.add(root, root, knights)
	var knight_scene: PackedScene = load("res://scenes/players/knight.tscn")
	for i in 2:
		var knight: Node2D = knight_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		knight.name = "Knight%d" % (i + 1)
		knight.position = spawn_1.position if i == 0 else spawn_2.position
		if i == 1:
			knight.set(&"profile", load("res://resources/players/p2_profile.tres"))
		knight.set(&"show_debug_tag", true)
		LevelBuilder.add(root, knights, knight)

	LevelBuilder.save_scene(root, LEVEL_PATH)
	root.free()


func _build_room() -> void:
	var root := Node.new()
	root.name = "HazardTestRoom"
	root.set_script(load("res://scenes/dev/hazard_test_room.gd"))
	for spec: Array in [["Level", LEVEL_PATH], ["SplitScreenRig", "res://scenes/camera/split_screen_rig.tscn"],
			["HazardDebugHud", "res://scenes/dev/hazard_debug_hud.tscn"]]:
		var node: Node = (load(spec[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = spec[0]
		LevelBuilder.add(root, root, node)
	LevelBuilder.save_scene(root, ROOM_PATH)
	root.free()
