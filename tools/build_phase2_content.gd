extends SceneTree
## Generates the Phase 2 camera test level and room.
##   godot --headless --path . --script res://tools/build_phase2_content.gd
## Outputs:
##   res://scenes/dev/camera_test_level.tscn  (terrain, ladders, knights, CameraBounds, markers)
##   res://scenes/dev/camera_test_room.tscn   (level + SplitScreenRig + camera debug overlay)
## Threshold markers on the floor are computed from resources/config/camera_config.tres,
## so re-run this tool after changing the split/merge ratios or the safe margin.

const LevelBuilder := preload("res://tools/level_builder.gd")
const LEVEL_PATH := "res://scenes/dev/camera_test_level.tscn"
const ROOM_PATH := "res://scenes/dev/camera_test_room.tscn"
const CONFIG_PATH := "res://resources/config/camera_config.tres"
const COLS := 120
const ROWS := 60
const T := LevelBuilder.TILE
const FLOOR_Y := 58 * T  # floor surface


func _init() -> void:
	_build_level()
	_build_room()
	quit()


func _build_level() -> void:
	var solid := {}
	var one_way := {}
	var fill := LevelBuilder.fill
	fill.call(solid, 0, 0, 0, ROWS - 1)                 # left wall
	fill.call(solid, COLS - 1, 0, COLS - 1, ROWS - 1)   # right wall
	fill.call(solid, 1, 0, COLS - 2, 0)                 # ceiling
	fill.call(solid, 1, 58, COLS - 2, 59)               # floor, surface y = 928 (wide horizontal area)
	# West side: two ladders up to a mid ledge and an upper ledge (vertical separation).
	fill.call(solid, 5, 40, 36, 40)                     # mid ledge, y = 640
	fill.call(one_way, 4, 40, 4, 40, 1)                 # ladder L1 top
	fill.call(solid, 20, 22, 33, 22)                    # upper ledge, y = 352
	fill.call(solid, 35, 22, 60, 22)
	fill.call(one_way, 34, 22, 34, 22, 1)               # ladder L2 top
	# Corridor block: 32 px passage underneath, with a 16 px crawl section.
	fill.call(solid, 72, 50, 90, 55)
	fill.call(solid, 80, 56, 84, 56)
	# Tower: tall shaft with a ladder and a zig-zag of one-way platforms.
	fill.call(solid, 91, 11, 91, 55)                    # tower west wall
	fill.call(solid, 105, 10, 105, 55)                  # tower east wall
	fill.call(solid, 60, 10, 91, 10)                    # high walkway, y = 160
	fill.call(one_way, 92, 10, 104, 10, 1)              # tower top (incl. ladder L3 top at col 96)
	var step := 0
	for row in range(55, 12, -3):
		var x0 := 98 if step % 2 == 0 else 101
		fill.call(one_way, x0, row, x0 + 2, row, 0)
		step += 1
	# East: large open area with floating platforms at several heights.
	for i in 6:
		var x0 := 107 if i % 2 == 0 else 113
		fill.call(one_way, x0, 54 - i * 3, x0 + 3, 54 - i * 3, 3)
	fill.call(solid, 106, 36, 118, 36)                  # east ledge, y = 576

	var root := Node2D.new()
	root.name = "CameraTestLevel"

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

	var climbables := Node2D.new()
	climbables.name = "Climbables"
	LevelBuilder.add(root, root, climbables)
	var ladder_scene: PackedScene = load("res://scenes/objects/ladder.tscn")
	# [name, column, top row, bottom surface y]
	for spec: Array in [["LadderL1", 4, 40, FLOOR_Y], ["LadderL2", 34, 22, 40 * T], ["LadderTower", 96, 10, FLOOR_Y]]:
		var ladder: Node2D = ladder_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		ladder.name = spec[0]
		ladder.position = LevelBuilder.climbable_top(spec[1], spec[2])
		ladder.set(&"size", Vector2(16, spec[3] - spec[2] * T))
		LevelBuilder.add(root, climbables, ladder)

	_add_markers(root)

	var spawn_1 := Marker2D.new()
	spawn_1.name = "SpawnP1"
	spawn_1.position = Vector2(8 * T + 8, FLOOR_Y)
	LevelBuilder.add(root, root, spawn_1)
	var spawn_2 := Marker2D.new()
	spawn_2.name = "SpawnP2"
	spawn_2.position = Vector2(12 * T + 8, FLOOR_Y)
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


## Labels, teleport markers and floor ticks showing the split/merge distances.
func _add_markers(root: Node2D) -> void:
	var config: Resource = load(CONFIG_PATH)
	var view := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")) / float(config.get(&"zoom"))
	var safe: Vector2 = view - (config.get(&"safe_margin") as Vector2) * 2.0
	var enter: float = config.get(&"split_enter_ratio")
	var exit: float = config.get(&"split_exit_ratio")

	var markers := Node2D.new()
	markers.name = "Markers"
	LevelBuilder.add(root, root, markers)
	var spots := {"TowerTop": Vector2(99 * T + 8, 10 * T), "FarRight": Vector2(115 * T + 8, FLOOR_Y)}
	for marker_name: String in spots:
		var m := Marker2D.new()
		m.name = marker_name
		m.position = spots[marker_name]
		LevelBuilder.add(root, markers, m)

	var labels := Node2D.new()
	labels.name = "Labels"
	LevelBuilder.add(root, root, labels)
	var label_spots := {
		"TOGETHER": Vector2(110, 904), "UPPER LEDGE": Vector2(340, 330), "MID LEDGE": Vector2(160, 618),
		"CORRIDOR": Vector2(1160, 786), "CRAWL": Vector2(1290, 884), "TOWER": Vector2(1480, 906),
		"OPEN AREA": Vector2(1716, 520), "WALKWAY": Vector2(1100, 146), "FAR RIGHT": Vector2(1800, 906),
	}
	for text: String in label_spots:
		LevelBuilder.add(root, labels, LevelBuilder.make_label(text, label_spots[text]))

	# Horizontal threshold lane: P1 stands at the post, P2 walks between MERGE and SPLIT.
	var post_x := 30 * T + 8
	var ticks := {
		"P1 HERE": [post_x, Color(0.2, 0.25, 0.6)],
		"MERGE": [post_x + exit * safe.x, Color(0.1, 0.55, 0.2)],
		"SPLIT": [post_x + enter * safe.x, Color(0.75, 0.15, 0.15)],
	}
	for text: String in ticks:
		var x: float = ticks[text][0]
		var colour: Color = ticks[text][1]
		var tick := ColorRect.new()
		tick.name = text.replace(" ", "") + "Tick"
		tick.color = colour
		tick.position = Vector2(roundf(x) - 1, FLOOR_Y - 40)
		tick.size = Vector2(2, 40)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		LevelBuilder.add(root, labels, tick)
		LevelBuilder.add(root, labels, LevelBuilder.make_label(text, Vector2(roundf(x) + 3, FLOOR_Y - 40), colour))
	# Vertical threshold ticks beside ladder L1: P1 waits at the foot, P2 climbs.
	var foot_y := float(FLOOR_Y)
	for pair: Array in [["MERGE HEIGHT", exit * safe.y, Color(0.1, 0.55, 0.2)], ["SPLIT HEIGHT", enter * safe.y, Color(0.75, 0.15, 0.15)]]:
		var y := roundf(foot_y - pair[1])
		var tick := ColorRect.new()
		tick.name = (pair[0] as String).replace(" ", "") + "Tick"
		tick.color = pair[2]
		tick.position = Vector2(82, y - 1)
		tick.size = Vector2(40, 2)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		LevelBuilder.add(root, labels, tick)
		LevelBuilder.add(root, labels, LevelBuilder.make_label(pair[0], Vector2(124, y - 5), pair[2]))


func _build_room() -> void:
	var root := Node.new()
	root.name = "CameraTestRoom"
	root.set_script(load("res://scenes/dev/camera_test_room.gd"))
	var level: Node = (load(LEVEL_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	level.name = "Level"
	LevelBuilder.add(root, root, level)
	var rig: Node = (load("res://scenes/camera/split_screen_rig.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	rig.name = "SplitScreenRig"
	LevelBuilder.add(root, root, rig)
	var hud: Node = (load("res://scenes/dev/camera_debug_hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	hud.name = "CameraDebugHud"
	LevelBuilder.add(root, root, hud)
	LevelBuilder.save_scene(root, ROOM_PATH)
	root.free()
