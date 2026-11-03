extends SceneTree
## Generates Phase 4 content.
##   godot --headless --path . --script res://tools/build_phase4_content.gd -- frames
##   godot --headless --path . --script res://tools/build_phase4_content.gd -- content
## frames:  res://resources/enemies/green_slime_frames.tres, purple_slime_frames.tres
## content: res://scenes/dev/enemy_test_level.tscn, res://scenes/dev/enemy_test_room.tscn

const LevelBuilder := preload("res://tools/level_builder.gd")
const LEVEL_PATH := "res://scenes/dev/enemy_test_level.tscn"
const ROOM_PATH := "res://scenes/dev/enemy_test_room.tscn"
const GREEN := "res://scenes/enemies/green_slime.tscn"
const PURPLE := "res://scenes/enemies/purple_slime.tscn"
const COLS := 96
const ROWS := 34
const T := LevelBuilder.TILE
const FLOOR_Y := 32 * T  # 512


func _init() -> void:
	var step := "content"
	if not OS.get_cmdline_user_args().is_empty():
		step = OS.get_cmdline_user_args()[0]
	match step:
		"frames":
			_build_frames("res://assets/sprites/slime_green.png", "res://resources/enemies/green_slime_frames.tres")
			_build_frames("res://assets/sprites/slime_purple.png", "res://resources/enemies/purple_slime_frames.tres")
		"content":
			_build_level()
			_build_room()
		_:
			push_error("Unknown step %s (use frames or content)" % step)
	quit()


# --- Slime animations -------------------------------------------------------------------

## Slime sheets: 4x3 cells of 24x24, frames 0-11 left to right (docs/ASSET_CATALOG.md):
## 0-3 puddle rising to full body, 4-9 bob cycle, 10 red hit flash, 11 normal.
func _build_frames(sheet_path: String, out_path: String) -> void:
	var sheet: Texture2D = load(sheet_path)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_anim(frames, sheet, &"idle", [4, 5, 6, 7, 8, 9], 6.0, true)
	_anim(frames, sheet, &"move", [4, 5, 6, 7, 8, 9], 10.0, true)
	_anim(frames, sheet, &"chase", [4, 5, 6, 7, 8, 9], 16.0, true)
	_anim(frames, sheet, &"hurt", [10, 11], 12.0, false)
	_anim(frames, sheet, &"stagger", [0, 1], 3.0, true)      # collapsed puddle
	_anim(frames, sheet, &"recover", [0, 1, 2, 3], 10.0, false)  # rising back up
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	LevelBuilder.report(out_path, ResourceSaver.save(frames, out_path))


func _anim(frames: SpriteFrames, sheet: Texture2D, anim: StringName, indices: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i: int in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2((i % 4) * 24, (i / 4) * 24, 24, 24)
		atlas.filter_clip = true
		frames.add_frame(anim, atlas)


# --- Enemy test level -------------------------------------------------------------------

func _build_level() -> void:
	var solid := {}
	var one_way := {}
	var fill := LevelBuilder.fill
	fill.call(solid, 0, 0, 0, ROWS - 1)
	fill.call(solid, COLS - 1, 0, COLS - 1, ROWS - 1)
	fill.call(solid, 1, 0, COLS - 2, 0)
	fill.call(solid, 1, 32, COLS - 2, 33)    # floor, surface y = 512
	fill.call(solid, 36, 27, 37, 31)         # pillar blocking line of sight (x 576-608)
	fill.call(solid, 44, 27, 53, 27)         # solid ledge (x 704-864, top y = 432) with edges
	fill.call(one_way, 50, 22, 58, 22, 1)    # higher one-way platform (x 800-944, y = 352)
	fill.call(solid, 62, 29, 72, 29)         # corridor ceiling (x 992-1168): 32 px passage
	fill.call(solid, 62, 25, 72, 28)

	var root := Node2D.new()
	root.name = "EnemyTestLevel"
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

	var enemies := Node2D.new()
	enemies.name = "Enemies"
	LevelBuilder.add(root, root, enemies)
	# [name, scene, feet position, patrol left, patrol right, detection radius (0 = default)]
	var placements := [
		["Green", GREEN, Vector2(264, FLOOR_Y), -48.0, 48.0, 0.0],
		["Purple", PURPLE, Vector2(440, FLOOR_Y), -48.0, 48.0, 0.0],
		["GreenBehindPillar", GREEN, Vector2(664, FLOOR_Y), -40.0, 24.0, 120.0],
		["GreenOnLedge", GREEN, Vector2(784, 27 * T), -120.0, 120.0, 0.0],
		["PurpleHigh", PURPLE, Vector2(872, 22 * T), -100.0, 100.0, 0.0],
		["GreenCorridor", GREEN, Vector2(1080, FLOOR_Y), -64.0, 64.0, 0.0],
		["CrowdGreenA", GREEN, Vector2(1232, FLOOR_Y), -40.0, 40.0, 80.0],
		["CrowdPurpleA", PURPLE, Vector2(1296, FLOOR_Y), -40.0, 40.0, 80.0],
		["CrowdGreenB", GREEN, Vector2(1368, FLOOR_Y), -40.0, 40.0, 80.0],
		["CrowdPurpleB", PURPLE, Vector2(1440, FLOOR_Y), -40.0, 40.0, 80.0],
	]
	for p: Array in placements:
		var slime: Node2D = (load(p[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		slime.name = p[0]
		slime.position = p[2]
		slime.set(&"patrol_left", p[3])
		slime.set(&"patrol_right", p[4])
		if p[5] > 0.0:
			slime.set(&"detection_radius_override", p[5])
		LevelBuilder.add(root, enemies, slime)

	var labels := Node2D.new()
	labels.name = "Labels"
	LevelBuilder.add(root, root, labels)
	var label_spots := {
		"ONE GREEN": Vector2(236, 440), "ONE PURPLE": Vector2(410, 440), "PILLAR": Vector2(572, 410),
		"BEHIND PILLAR": Vector2(624, 466), "LEDGE EDGES": Vector2(744, 400), "HIGH PLATFORM": Vector2(830, 320),
		"CORRIDOR": Vector2(1060, 384), "CROWD": Vector2(1310, 440),
	}
	for text: String in label_spots:
		LevelBuilder.add(root, labels, LevelBuilder.make_label(text, label_spots[text]))

	var spawn_1 := Marker2D.new()
	spawn_1.name = "SpawnP1"
	spawn_1.position = Vector2(4 * T + 8, FLOOR_Y)
	LevelBuilder.add(root, root, spawn_1)
	var spawn_2 := Marker2D.new()
	spawn_2.name = "SpawnP2"
	spawn_2.position = Vector2(7 * T + 8, FLOOR_Y)
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
	root.name = "EnemyTestRoom"
	root.set_script(load("res://scenes/dev/enemy_test_room.gd"))
	for spec: Array in [["Level", LEVEL_PATH], ["SplitScreenRig", "res://scenes/camera/split_screen_rig.tscn"],
			["EnemyDebugHud", "res://scenes/dev/enemy_debug_hud.tscn"]]:
		var node: Node = (load(spec[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = spec[0]
		LevelBuilder.add(root, root, node)
	LevelBuilder.save_scene(root, ROOM_PATH)
	root.free()
