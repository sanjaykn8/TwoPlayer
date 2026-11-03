extends SceneTree
## Generates the Phase 5 collectible test level and room.
##   godot --headless --path . --script res://tools/build_phase5_content.gd
## Outputs res://scenes/dev/collectible_test_level.tscn and collectible_test_room.tscn.

const LevelBuilder := preload("res://tools/level_builder.gd")
const LEVEL_PATH := "res://scenes/dev/collectible_test_level.tscn"
const ROOM_PATH := "res://scenes/dev/collectible_test_room.tscn"
const FRUIT := "res://scenes/collectibles/fruit.tscn"
const JAR := "res://scenes/collectibles/jar.tscn"
const TILE := "res://scenes/collectibles/power_tile.tscn"
const COLS := 80
const ROWS := 30
const T := LevelBuilder.TILE
const FLOOR_Y := 28 * T  # 448


func _init() -> void:
	_build_level()
	_build_room()
	quit()


func _build_level() -> void:
	var solid := {}
	var one_way := {}
	var fill := LevelBuilder.fill
	fill.call(solid, 0, 0, 0, ROWS - 1)
	fill.call(solid, COLS - 1, 0, COLS - 1, ROWS - 1)
	fill.call(solid, 1, 0, COLS - 2, 0)
	fill.call(solid, 1, 28, COLS - 2, 29)            # floor, y = 448
	# Red-jar route: single-tile one-way steps, then a 32 px gap to the top of a tall pillar.
	fill.call(one_way, 27, 25, 27, 25, 1)            # step A (x 432-448, y 400)
	fill.call(one_way, 25, 22, 25, 22, 1)            # step B (x 400-416, y 352)
	fill.call(one_way, 27, 19, 27, 19, 1)            # step C (x 432-448, y 304)
	fill.call(solid, 30, 16, 31, 27)                 # pillar (x 480-512), top y = 256
	# Slime pens (2-tile walls the slimes cannot cross; knights can jump them).
	for col: int in [57, 64, 66, 73]:
		fill.call(solid, col, 26, col, 27)

	var root := Node2D.new()
	root.name = "CollectibleTestLevel"
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

	var items := Node2D.new()
	items.name = "Items"
	LevelBuilder.add(root, root, items)
	# Fruits: one column per colour; tier 1 on the floor, tier 2 needs a hop, tier 3 a jump.
	var fruit_columns := [["Green", 0, 136], ["Yellow", 1, 184], ["Red", 2, 232], ["Purple", 3, 280]]
	for col: Array in fruit_columns:
		for tier in [1, 2, 3]:
			var fruit: Node2D = (load(FRUIT) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			fruit.name = "Fruit%sT%d" % [col[0], tier]
			fruit.position = Vector2(col[2], FLOOR_Y - (tier - 1) * 22)
			fruit.set(&"fruit_type", col[1])
			fruit.set(&"tier", tier)
			fruit.set(&"collectible_id", "dev_fruit_%s_t%d" % [String(col[0]).to_lower(), tier])
			LevelBuilder.add(root, items, fruit)
	# Jars: green, yellow, blue near the floor; red on top of the pillar.
	var jars := [["Green", 0, Vector2(336, FLOOR_Y)], ["Yellow", 2, Vector2(368, FLOOR_Y)],
		["Blue", 3, Vector2(400, FLOOR_Y)], ["Red", 1, Vector2(496, 16 * T)]]
	for j: Array in jars:
		var jar: Node2D = (load(JAR) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		jar.name = "Jar%s" % j[0]
		jar.position = j[2]
		jar.set(&"jar_type", j[1])
		jar.set(&"collectible_id", "dev_jar_%s" % String(j[0]).to_lower())
		LevelBuilder.add(root, items, jar)

	var tiles := Node2D.new()
	tiles.name = "PowerTiles"
	LevelBuilder.add(root, root, tiles)
	for i in 3:
		var tile: Node2D = (load(TILE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		tile.name = "PowerTile%d" % (i + 1)
		tile.position = Vector2(560 + i * 40, FLOOR_Y - 8)
		LevelBuilder.add(root, tiles, tile)

	var enemies := Node2D.new()
	enemies.name = "Enemies"
	LevelBuilder.add(root, root, enemies)
	for e: Array in [["ShieldPenGreen", "res://scenes/enemies/green_slime.tscn", 976.0, 32.0],
			["PoisonPenPurple", "res://scenes/enemies/purple_slime.tscn", 1120.0, 32.0],
			["CoinSlimeA", "res://scenes/enemies/green_slime.tscn", 1216.0, 8.0],
			["CoinSlimeB", "res://scenes/enemies/green_slime.tscn", 1250.0, 8.0]]:
		var slime: Node2D = (load(e[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		slime.name = e[0]
		slime.position = Vector2(e[2], FLOOR_Y)
		slime.set(&"patrol_left", -float(e[3]))
		slime.set(&"patrol_right", float(e[3]))
		slime.set(&"detection_radius_override", 64.0)
		LevelBuilder.add(root, enemies, slime)

	var labels := Node2D.new()
	labels.name = "Labels"
	LevelBuilder.add(root, root, labels)
	var label_spots := {
		"HEAL": Vector2(122, 380), "SHIELD": Vector2(166, 380), "RANGE": Vector2(218, 380), "POISON": Vector2(262, 380),
		"JARS": Vector2(352, 404), "RED JAR": Vector2(476, 226), "? TILES": Vector2(574, 404),
		"SPEED LANE": Vector2(760, 404), "SHIELD TEST": Vector2(944, 380), "POISON TEST": Vector2(1088, 380),
		"COIN DROPS": Vector2(1204, 404),
	}
	for text: String in label_spots:
		LevelBuilder.add(root, labels, LevelBuilder.make_label(text, label_spots[text]))
	for i in 8:  # speed lane distance ticks every 32 px
		var tick := ColorRect.new()
		tick.name = "SpeedTick%d" % i
		tick.color = Color(0.2, 0.25, 0.6)
		tick.position = Vector2(700 + i * 32, FLOOR_Y - 6)
		tick.size = Vector2(2, 6)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		LevelBuilder.add(root, labels, tick)

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
	root.name = "CollectibleTestRoom"
	root.set_script(load("res://scenes/dev/collectible_test_room.gd"))
	for spec: Array in [["Level", LEVEL_PATH], ["SplitScreenRig", "res://scenes/camera/split_screen_rig.tscn"],
			["CollectibleDebugHud", "res://scenes/dev/collectible_debug_hud.tscn"]]:
		var node: Node = (load(spec[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = spec[0]
		LevelBuilder.add(root, root, node)
	LevelBuilder.save_scene(root, ROOM_PATH)
	root.free()
