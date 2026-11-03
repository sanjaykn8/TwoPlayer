extends SceneTree
## Generates Phase 3 content. Run from the project root, in two passes:
##   godot --headless --path . --script res://tools/build_phase3_content.gd -- art
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_phase3_content.gd -- content
## Outputs:
##   art:     res://assets/created/knife_slash.png (4 frames of 40x40, slash facing right)
##   content: res://scenes/dev/combat_test_level.tscn, res://scenes/dev/combat_test_room.tscn

const LevelBuilder := preload("res://tools/level_builder.gd")
const SLASH_PNG := "res://assets/created/knife_slash.png"
const LEVEL_PATH := "res://scenes/dev/combat_test_level.tscn"
const ROOM_PATH := "res://scenes/dev/combat_test_room.tscn"
const COLS := 70
const ROWS := 30
const T := LevelBuilder.TILE
const FLOOR_Y := 28 * T  # 448

# Knight palette (docs/ASSET_CATALOG.md) so the knife matches the sprites.
const OUTLINE := Color("0e0d0e")
const BLADE_LIGHT := Color("eadfd1")
const BLADE_MID := Color("b3aaa1")
const HANDLE := Color("67332d")
const FRAME := 40
const PIVOT := Vector2(20, 20)


func _init() -> void:
	var step := "content"
	if not OS.get_cmdline_user_args().is_empty():
		step = OS.get_cmdline_user_args()[0]
	match step:
		"art":
			_build_slash_png()
		"content":
			_build_level()
			_build_room()
		_:
			push_error("Unknown step %s (use art or content)" % step)
	quit()


# --- Knife slash art -----------------------------------------------------------------

## Four frames, slash toward +x around the pivot at the frame centre (the knight's body centre):
## 0 windup (knife raised), 1 upper arc, 2 full arc, 3 fading lower arc.
func _build_slash_png() -> void:
	var img := Image.create(FRAME * 4, FRAME, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# [arc from deg, arc to deg, arc alpha, knife angle deg]
	var frames := [[0, 0, 0.0, -100], [-70, -10, 1.0, -40], [-70, 60, 1.0, 35], [10, 60, 0.45, 55]]
	for i in frames.size():
		var f: Array = frames[i]
		var origin := Vector2i(i * FRAME, 0)
		if f[2] > 0.0:
			_draw_arc(img, origin, f[0], f[1], f[2])
		_draw_knife(img, origin, f[3])
	DirAccess.make_dir_recursive_absolute("res://assets/created")
	LevelBuilder.report(SLASH_PNG, img.save_png(SLASH_PNG))


func _draw_arc(img: Image, origin: Vector2i, from_deg: float, to_deg: float, alpha: float) -> void:
	for y in FRAME:
		for x in FRAME:
			var d := Vector2(x + 0.5, y + 0.5) - PIVOT
			var r := d.length()
			var a := rad_to_deg(d.angle())
			if a < from_deg or a > to_deg or r < 12.5 or r > 17.5:
				continue
			var colour := Color.WHITE if r > 15.0 else BLADE_LIGHT
			colour.a = alpha * (1.0 if r > 14.0 else 0.6)
			img.set_pixel(origin.x + x, origin.y + y, colour)


func _draw_knife(img: Image, origin: Vector2i, angle_deg: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	var hand := PIVOT + Vector2(4, 0)
	var pixels: Array[Vector2i] = []
	var colours: Array[Color] = []
	for t in 11:
		var p := Vector2i((hand + dir * t).round())
		pixels.append(p)
		colours.append(HANDLE if t < 3 else (BLADE_LIGHT if t % 2 == 0 else BLADE_MID))
	for p in pixels:  # outline first
		for o: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q := p + o
			if q.x >= 0 and q.y >= 0 and q.x < FRAME and q.y < FRAME:
				img.set_pixel(origin.x + q.x, origin.y + q.y, OUTLINE)
	for i in pixels.size():
		var p := pixels[i]
		if p.x >= 0 and p.y >= 0 and p.x < FRAME and p.y < FRAME:
			img.set_pixel(origin.x + p.x, origin.y + p.y, colours[i])


# --- Combat test level ---------------------------------------------------------------

func _build_level() -> void:
	var solid := {}
	var one_way := {}
	var fill := LevelBuilder.fill
	fill.call(solid, 0, 0, 0, ROWS - 1)
	fill.call(solid, COLS - 1, 0, COLS - 1, ROWS - 1)
	fill.call(solid, 1, 0, COLS - 2, 0)
	fill.call(solid, 1, 28, COLS - 2, 29)        # floor, surface y = 448
	fill.call(one_way, 18, 23, 21, 23, 0)        # platform with a target standing on it
	fill.call(one_way, 32, 22, 36, 22, 1)        # ladder platform (ladder at col 34)
	fill.call(solid, 46, 24, 47, 27)             # 2x4 pillar with a target behind it
	fill.call(solid, 52, 25, 62, 25)             # corridor ceiling: 32 px passage
	fill.call(solid, 52, 21, 62, 24)             # corridor block above

	var root := Node2D.new()
	root.name = "CombatTestLevel"
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
	var ladder: Node2D = (load("res://scenes/objects/ladder.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ladder.name = "Ladder"
	ladder.position = LevelBuilder.climbable_top(34, 22)
	ladder.set(&"size", Vector2(16, FLOOR_Y - 22 * T))
	LevelBuilder.add(root, climbables, ladder)

	# Thin wall (4 px) with a target right behind it: the hitbox reaches the target,
	# the wall must block it.
	var wall := StaticBody2D.new()
	wall.name = "ThinWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(682, FLOOR_Y - 24)
	LevelBuilder.add(root, root, wall)
	var wall_shape := CollisionShape2D.new()
	wall_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 48)
	wall_shape.shape = rect
	LevelBuilder.add(root, wall, wall_shape)
	var wall_visual := ColorRect.new()
	wall_visual.name = "Visual"
	wall_visual.color = Color("67332d")
	wall_visual.position = Vector2(-2, -24)
	wall_visual.size = Vector2(4, 48)
	wall_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	LevelBuilder.add(root, wall, wall_visual)

	var targets := Node2D.new()
	targets.name = "Targets"
	LevelBuilder.add(root, root, targets)
	var dummy_scene: PackedScene = load("res://scenes/objects/training_dummy.tscn")
	# name -> feet position. See docs/MANUAL_COMBAT_TEST.md for what each one tests.
	# "Above" hangs 50 px up: on solid ground Up also jumps, so up attacks there are jump attacks.
	var spots := {
		"Left": Vector2(40, FLOOR_Y), "Right": Vector2(232, FLOOR_Y),
		"RangeEdge": Vector2(342, FLOOR_Y), "OutOfRange": Vector2(424, FLOOR_Y),
		"OnPlatform": Vector2(312, 23 * T), "Above": Vector2(480, FLOOR_Y - 50),
		"LadderFoot": Vector2(552, FLOOR_Y), "JumpOver": Vector2(616, FLOOR_Y),
		"BehindThinWall": Vector2(690, FLOOR_Y), "BehindPillar": Vector2(774, FLOOR_Y),
		"Corridor": Vector2(920, FLOOR_Y), "PairA": Vector2(1036, FLOOR_Y), "PairB": Vector2(1052, FLOOR_Y),
	}
	for dummy_name: String in spots:
		var dummy: Node2D = dummy_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		dummy.name = dummy_name
		dummy.position = spots[dummy_name]
		dummy.set(&"respawn_delay", 3.0)
		LevelBuilder.add(root, targets, dummy)

	var labels := Node2D.new()
	labels.name = "Labels"
	LevelBuilder.add(root, root, labels)
	var label_spots := {
		"LEFT": Vector2(24, 404), "RIGHT": Vector2(216, 404), "STAND": Vector2(306, 452),
		"EDGE": Vector2(330, 404), "TOO FAR": Vector2(406, 404), "STAND ": Vector2(386, 452),
		"ON PLATFORM": Vector2(288, 322), "UP": Vector2(474, 346), "LADDER DOWN": Vector2(520, 330),
		"JUMP + DOWN": Vector2(592, 404), "WALL": Vector2(668, 380), "PILLAR": Vector2(736, 368),
		"CORRIDOR": Vector2(900, 320), "TWO AT ONCE": Vector2(1020, 404),
	}
	for text: String in label_spots:
		LevelBuilder.add(root, labels, LevelBuilder.make_label(text.strip_edges(), label_spots[text]))
	# Floor ticks where a knight stands for the range-edge and out-of-range targets.
	for x: float in [320.0, 400.0]:
		var tick := ColorRect.new()
		tick.name = "StandTick%d" % int(x)
		tick.color = Color(0.2, 0.25, 0.6)
		tick.position = Vector2(x - 1, FLOOR_Y - 6)
		tick.size = Vector2(2, 6)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		LevelBuilder.add(root, labels, tick)

	var spawn_1 := Marker2D.new()
	spawn_1.name = "SpawnP1"
	spawn_1.position = Vector2(6 * T + 8, FLOOR_Y)
	LevelBuilder.add(root, root, spawn_1)
	var spawn_2 := Marker2D.new()
	spawn_2.name = "SpawnP2"
	spawn_2.position = Vector2(10 * T + 8, FLOOR_Y)
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
	root.name = "CombatTestRoom"
	root.set_script(load("res://scenes/dev/combat_test_room.gd"))
	var level: Node = (load(LEVEL_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	level.name = "Level"
	LevelBuilder.add(root, root, level)
	var rig: Node = (load("res://scenes/camera/split_screen_rig.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	rig.name = "SplitScreenRig"
	LevelBuilder.add(root, root, rig)
	var hud: Node = (load("res://scenes/dev/combat_debug_hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	hud.name = "CombatDebugHud"
	LevelBuilder.add(root, root, hud)
	LevelBuilder.save_scene(root, ROOM_PATH)
	root.free()
