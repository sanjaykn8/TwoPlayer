extends SceneTree
## Generates the Phase 8 development campaign (two small levels in world "w1") and the save
## test harness. These exist to exercise saving, loading, level transitions and the team wipe
## with every kind of persistent entity; they are NOT the production levels (Phase 10).
## Run:  godot --headless --path . --script res://tools/build_phase8_content.gd -- content
##
## w1_l1: slime, fruit and jar, save point, two-plate lock + latch gate, moving platform over a
##        pit, timed and collapsing platforms, purple slime, spikes, a small lava pit, save
##        point, exit.
## w1_l2: slime, momentary switch + timed gate (far switch reopens it), disappearing platform,
##        blue jar, save point, exit (the end of the development campaign).

const LevelBuilder := preload("res://tools/level_builder.gd")
const T := LevelBuilder.TILE
const ROWS := 30
const FLOOR_ROW := 28
const FLOOR_Y := FLOOR_ROW * T  # 448
const GATE_ROW := 25           # gates fill rows 25-27
const P := "res://scenes/puzzles/"
const HARNESS_PATH := "res://scenes/dev/save_test_room.tscn"

var _root: Node2D
var _groups := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("content") or args.is_empty():
		_build_w1_l1()
		_build_w1_l2()
		_build_harness()
	quit()


func _build_w1_l1() -> void:
	var cols := 100
	var solid := _frame(cols)
	var one_way := {}
	LevelBuilder.fill(solid, 38, 1, 38, GATE_ROW - 1)          # wall above the puzzle gate
	for x in range(42, 51):                                   # pit under the moving platform
		solid.erase(Vector2i(x, FLOOR_ROW)); solid.erase(Vector2i(x, FLOOR_ROW + 1))
	for x in range(74, 77):                                   # lava pit, one tile deep
		solid.erase(Vector2i(x, FLOOR_ROW))
	_begin("w1_l1", cols, solid, one_way, [0, cols - 1, 38])
	_spawns()
	_inst("Enemies", "res://scenes/enemies/green_slime.tscn", "SlimeA", Vector2(240, FLOOR_Y), {"save_id": "w1l1_slime_a", "patrol_left": -40.0, "patrol_right": 40.0})
	_inst("Items", "res://scenes/collectibles/fruit.tscn", "FruitYellow", Vector2(320, FLOOR_Y), {"fruit_type": 1, "tier": 1, "collectible_id": "w1_l1_fruit_yellow"})
	_inst("Items", "res://scenes/collectibles/jar.tscn", "JarGreen", Vector2(352, FLOOR_Y), {"jar_type": 0, "collectible_id": "w1_l1_jar_green"})
	_inst("Items", "res://scenes/collectibles/fruit.tscn", "FruitRed", Vector2(384, FLOOR_Y), {"fruit_type": 3, "tier": 1, "collectible_id": "w1_l1_fruit_red"})
	_inst("Campaign", "res://scenes/campaign/save_point.tscn", "SavePoint1", Vector2(430, FLOOR_Y), {"save_id": "w1l1_sp_1"})
	_inst("Puzzles", P + "pressure_plate.tscn", "PlateA", Vector2(480, FLOOR_Y), {"puzzle_id": "w1l1_plate_a"})
	_inst("Puzzles", P + "pressure_plate.tscn", "PlateB", Vector2(544, FLOOR_Y), {"puzzle_id": "w1l1_plate_b"})
	_logic("Lock", Vector2(590, 380), "w1l1_lock", ["PlateA", "PlateB"], 0, {"distinct_players": true, "latch": true})
	_gate("Gate", 38, "Lock", 1, {"puzzle_id": "w1l1_gate"})
	_inst("Platforms", "res://scenes/platforms/moving_platform.tscn", "Lift", Vector2(42 * T + 8, FLOOR_Y),
		{"save_id": "w1l1_lift", "width_tiles": 3, "travel": Vector2(51 * T - 8 - 48 - (42 * T + 8), 0), "speed": 40.0})
	_inst("Platforms", "res://scenes/platforms/timed_platform.tscn", "Timed", Vector2(54 * T, FLOOR_Y - 40), {"save_id": "w1l1_timed"})
	_inst("Platforms", "res://scenes/platforms/collapsing_platform.tscn", "Crumble", Vector2(60 * T, FLOOR_Y - 40), {"save_id": "w1l1_crumble"})
	_inst("Enemies", "res://scenes/enemies/purple_slime.tscn", "SlimeB", Vector2(1040, FLOOR_Y), {"save_id": "w1l1_slime_b", "patrol_left": -32.0, "patrol_right": 32.0})
	_inst("Hazards", "res://scenes/hazards/spikes.tscn", "Spikes", Vector2(1120, FLOOR_Y - 16), {"size": Vector2(32, 16)})
	_inst("Hazards", "res://scenes/hazards/lava.tscn", "Lava", Vector2(74 * T, FLOOR_Y), {"size": Vector2(48, 16)})
	_inst("Campaign", "res://scenes/campaign/save_point.tscn", "SavePoint2", Vector2(1300, FLOOR_Y), {"save_id": "w1l1_sp_2"})
	_inst("Campaign", "res://scenes/campaign/level_exit.tscn", "Exit", Vector2(1500, FLOOR_Y), {"size": Vector2(24, 40)})
	_inst("Clues", P + "puzzle_clue.tscn", "Clue", Vector2(110, FLOOR_Y), {"text": "The road remembers\nwhat you carry."})
	_inst("Clues", P + "puzzle_clue.tscn", "ClueLock", Vector2(512, FLOOR_Y), {"text": "Two stones.\nTwo knights."})
	_finish("res://scenes/levels/w1/w1_l1.tscn", cols)


func _build_w1_l2() -> void:
	var cols := 70
	var solid := _frame(cols)
	var one_way := {}
	LevelBuilder.fill(solid, 40, 1, 40, GATE_ROW - 1)
	_begin("w1_l2", cols, solid, one_way, [0, cols - 1, 40])
	_spawns()
	_inst("Enemies", "res://scenes/enemies/green_slime.tscn", "Slime", Vector2(300, FLOOR_Y), {"save_id": "w1l2_slime_a", "patrol_left": -48.0, "patrol_right": 48.0})
	_inst("Puzzles", P + "attack_switch.tscn", "Switch", Vector2(420, FLOOR_Y - 22), {"puzzle_id": "w1l2_switch", "mode": 1, "active_time": 0.5})
	_inst("Puzzles", P + "attack_switch.tscn", "FarSwitch", Vector2(42 * T, FLOOR_Y - 22), {"puzzle_id": "w1l2_far_switch", "mode": 1, "active_time": 0.5})
	_logic("Lock", Vector2(620, 380), "w1l2_lock", ["Switch", "FarSwitch"], 1, {})
	_gate("Gate", 40, "Lock", 2, {"puzzle_id": "w1l2_gate", "open_time": 4.0, "warning_time": 1.0})
	_inst("Platforms", "res://scenes/platforms/disappearing_platform.tscn", "Blink", Vector2(48 * T, FLOOR_Y - 40), {"save_id": "w1l2_blink"})
	_inst("Items", "res://scenes/collectibles/jar.tscn", "JarBlue", Vector2(900, FLOOR_Y), {"jar_type": 3, "collectible_id": "w1_l2_jar_blue"})
	_inst("Campaign", "res://scenes/campaign/save_point.tscn", "SavePoint", Vector2(960, FLOOR_Y), {"save_id": "w1l2_sp_1"})
	_inst("Campaign", "res://scenes/campaign/level_exit.tscn", "Exit", Vector2(1060, FLOOR_Y), {"size": Vector2(24, 40)})
	_inst("Clues", P + "puzzle_clue.tscn", "Clue", Vector2(380, FLOOR_Y), {"text": "The door counts.\nOne strikes, one runs."})
	_finish("res://scenes/levels/w1/w1_l2.tscn", cols)


func _build_harness() -> void:
	var root := Node.new()
	root.name = "SaveTestRoom"
	root.set_script(load("res://scenes/dev/save_test_room.gd"))
	for spec: Array in [["SplitScreenRig", "res://scenes/camera/split_screen_rig.tscn"],
			["SaveDebugHud", "res://scenes/dev/save_debug_hud.tscn"]]:
		var node: Node = (load(spec[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = spec[0]
		LevelBuilder.add(root, root, node)
	LevelBuilder.save_scene(root, HARNESS_PATH)
	root.free()


# --- Helpers ---------------------------------------------------------------------------

func _frame(cols: int) -> Dictionary:
	var solid := {}
	LevelBuilder.fill(solid, 0, 0, 0, ROWS - 1)
	LevelBuilder.fill(solid, cols - 1, 0, cols - 1, ROWS - 1)
	LevelBuilder.fill(solid, 1, 0, cols - 2, 0)
	LevelBuilder.fill(solid, 1, FLOOR_ROW, cols - 2, FLOOR_ROW + 1)
	return solid


func _begin(level_id: String, cols: int, solid: Dictionary, one_way: Dictionary, walls: Array) -> void:
	_groups.clear()
	_root = Node2D.new()
	_root.name = level_id.to_pascal_case()
	_root.set_meta(&"level_id", level_id)
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color(0.42, 0.72, 0.92)
	sky.size = Vector2(cols * T, ROWS * T)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_to(_root, sky)
	_add_to(_root, LevelBuilder.build_terrain(solid, one_way, walls))
	var bounds: Node2D = (load("res://components/camera/camera_bounds.gd") as GDScript).new()
	bounds.name = "CameraBounds"
	bounds.set(&"size", Vector2(cols * T, ROWS * T))
	_add_to(_root, bounds)


func _spawns() -> void:
	for i in 2:
		var spawn := Marker2D.new()
		spawn.name = "SpawnP%d" % (i + 1)
		spawn.position = Vector2(40 + 32 * i, FLOOR_Y)
		_add_to(_root, spawn)


func _finish(path: String, cols: int) -> void:
	_inst("Hazards", "res://scenes/hazards/fall_boundary.tscn", "FallBoundary", Vector2(0, ROWS * T + 32), {"size": Vector2(cols * T, 64)})
	var knight_scene: PackedScene = load("res://scenes/players/knight.tscn")
	for i in 2:
		var knight: Node2D = knight_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		knight.name = "Knight%d" % (i + 1)
		knight.position = Vector2(40 + 32 * i, FLOOR_Y)
		if i == 1:
			knight.set(&"profile", load("res://resources/players/p2_profile.tres"))
		_add_to(_group("Knights"), knight)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	LevelBuilder.save_scene(_root, path)
	_root.free()


func _group(group_name: String) -> Node2D:
	if not _groups.has(group_name):
		var node := Node2D.new()
		node.name = group_name
		_add_to(_root, node)
		_groups[group_name] = node
	return _groups[group_name]


func _add_to(parent: Node, child: Node) -> void:
	LevelBuilder.add(_root, parent, child)


func _inst(group_name: String, path: String, node_name: String, at: Vector2, props: Dictionary) -> Node:
	var node: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = node_name
	node.position = at
	for key: String in props:
		node.set(key, props[key])
	_add_to(_group(group_name), node)
	return node


## mode: 0 ALL, 1 ANY, 2 SYNC, 3 SEQUENCE
func _logic(node_name: String, at: Vector2, id: String, input_names: Array, mode: int, props: Dictionary) -> void:
	var logic := _inst("Puzzles", P + "puzzle_logic.tscn", node_name, at, props)
	var paths: Array[NodePath] = []
	for input_name: String in input_names:
		paths.append(logic.get_path_to(_group("Puzzles").get_node(input_name)))
	logic.set(&"inputs", paths)
	logic.set(&"puzzle_id", id)
	logic.set(&"mode", mode)


## mode: 0 FOLLOW, 1 LATCH, 2 TIMED
func _gate(node_name: String, col: int, controller_name: String, mode: int, props: Dictionary) -> void:
	var gate := _inst("Puzzles", P + "puzzle_gate.tscn", node_name, Vector2(col * T, GATE_ROW * T), props)
	gate.set(&"controller", gate.get_path_to(_group("Puzzles").get_node(controller_name)))
	gate.set(&"mode", mode)
