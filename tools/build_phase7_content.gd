extends SceneTree
## Generates the Phase 7 cooperative puzzle test room (development content, not a campaign
## level). Run:
##   godot --headless --path . --script res://tools/build_phase7_content.gd -- content
##
## One corridor (floor y = 512), sections left to right, each closed by a stone gate:
##   1 TWO STONES     two plates, different knights, latched lock            -> Gate1 (latch)
##   2 HOLD           hold plate opens Gate2 while held; far-side latch switch keeps it open
##   3 TWO BLADES     two targets struck by different knights within 2 s     -> Gate3 (latch)
##   4 TIMED          high switch opens TimedGate4 for 3 s; far-side switch reopens it
##   5 ROUTES         upper and lower routes, a latch switch at each end, different knights
##   6 BOTH SIDES     a plate on each side of Gate6 holds it open for the other knight
##   7 BRIDGE         plates on both sides of a pit extend a moving platform across
##   8 DISTRACTION    a purple slime guards the switch of Gate8
##   9 RISK           a plate on hot ground (costs 1 HP) or a safe far-side plate holds Gate9
##   10 END           both knights reunited (two-knight trigger zone); clues in every section

const LevelBuilder := preload("res://tools/level_builder.gd")
const LEVEL_PATH := "res://scenes/dev/puzzle_test_level.tscn"
const ROOM_PATH := "res://scenes/dev/puzzle_test_room.tscn"
const LEVEL_ID := "dev/puzzle_test"
const COLS := 262
const ROWS := 34
const T := LevelBuilder.TILE
const FLOOR_Y := 32 * T  # 512
const GATE_ROW := 29     # gates fill rows 29-31 (y 464-512)
const WALL_COLS := [20, 44, 70, 100, 140, 153, 225, 245]
const PIT := [170, 190]
const HOT := [230, 232]
const P := "res://scenes/puzzles/"

var _root: Node2D
var _groups := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("content") or args.is_empty():
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
	fill.call(solid, 1, 32, COLS - 2, 33)
	for c: int in WALL_COLS:
		fill.call(solid, c, 1, c, GATE_ROW - 1)   # wall above each gate
	for x in range(PIT[0], PIT[1] + 1):            # section 7: bottomless pit
		solid.erase(Vector2i(x, 32)); solid.erase(Vector2i(x, 33))
	for x in range(HOT[0], HOT[1] + 1):            # section 9: hot ground is its own body
		solid.erase(Vector2i(x, 32)); solid.erase(Vector2i(x, 33))
	fill.call(one_way, 72, 25, 77, 25)             # section 4: switch ledge (ladder top at 77)
	fill.call(solid, 105, 20, 134, 21)             # section 5: band between upper and lower routes
	one_way[Vector2i(104, 20)] = true              # section 5: ladder top to the upper route

	_root = Node2D.new()
	_root.name = "PuzzleTestLevel"
	_root.set_meta(&"level_id", LEVEL_ID)
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color(0.42, 0.72, 0.92)
	sky.size = Vector2(COLS * T, ROWS * T)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_to(_root, sky)
	_add_to(_root, LevelBuilder.build_terrain(solid, one_way, [0, COLS - 1] + WALL_COLS))
	var bounds: Node2D = (load("res://components/camera/camera_bounds.gd") as GDScript).new()
	bounds.name = "CameraBounds"
	bounds.set(&"size", Vector2(COLS * T, ROWS * T))
	_add_to(_root, bounds)

	_build_world_objects()
	_build_puzzles()
	_build_clues()
	_build_labels()
	_build_knights()
	LevelBuilder.save_scene(_root, LEVEL_PATH)
	_root.free()


func _build_world_objects() -> void:
	_inst("Climbables", "res://scenes/objects/ladder.tscn", "LadderS4", Vector2(77 * T + 8, 25 * T), {"size": Vector2(16, 7 * T)})
	_inst("Climbables", "res://scenes/objects/ladder.tscn", "LadderS5", Vector2(104 * T + 8, 20 * T), {"size": Vector2(16, 12 * T)})
	_inst("Hazards", "res://scenes/hazards/spikes.tscn", "SpikesS2", Vector2(480, FLOOR_Y - 16), {"size": Vector2(32, 16)})
	_inst("Hazards", "res://scenes/hazards/spikes.tscn", "SpikesS5Upper", Vector2(1840, 20 * T - 16), {"size": Vector2(48, 16)})
	_inst("Hazards", "res://scenes/hazards/spikes.tscn", "SpikesS5Lower", Vector2(1888, FLOOR_Y - 16), {"size": Vector2(32, 16)})
	_inst("Hazards", "res://scenes/hazards/hot_ground.tscn", "HotGroundS9", Vector2(HOT[0] * T, FLOOR_Y), {"size": Vector2((HOT[1] - HOT[0] + 1) * T, 32)})
	_inst("Hazards", "res://scenes/hazards/fall_boundary.tscn", "FallBoundary", Vector2(0, ROWS * T + 32), {"size": Vector2(COLS * T, 64)})
	_inst("Platforms", "res://scenes/platforms/moving_platform.tscn", "BridgeS7", Vector2(PIT[0] * T + 8, FLOOR_Y),
		{"width_tiles": 3, "travel": Vector2((PIT[1] + 1) * T - 8 - 48 - (PIT[0] * T + 8), 0), "speed": 60.0, "auto_start": false})
	_inst("Enemies", "res://scenes/enemies/purple_slime.tscn", "GuardS8", Vector2(3480, FLOOR_Y),
		{"patrol_left": -40.0, "patrol_right": 40.0})
	_inst("Items", "res://scenes/collectibles/fruit.tscn", "HealS9", Vector2(4040, FLOOR_Y),
		{"fruit_type": 0, "tier": 1, "collectible_id": "dev_p7_heal"})


func _build_puzzles() -> void:
	var y_switch := FLOOR_Y - 22.0  # a 16 px fixture at knight chest height
	# 1 TWO STONES: two plates, two different knights, remembered once done.
	_inst("Puzzles", P + "pressure_plate.tscn", "S1PlateA", Vector2(128, FLOOR_Y), {"puzzle_id": "s1_plate_a"})
	_inst("Puzzles", P + "pressure_plate.tscn", "S1PlateB", Vector2(192, FLOOR_Y), {"puzzle_id": "s1_plate_b"})
	_logic("S1Lock", Vector2(300, 440), "s1_lock", ["S1PlateA", "S1PlateB"], 0, {"distinct_players": true, "latch": true})
	_gate("Gate1", 20, "S1Lock", 1, {"puzzle_id": "s1_gate"})
	# 2 HOLD THE LIGHT: held plate, or the far-side latch switch, keeps Gate2 open.
	_inst("Puzzles", P + "pressure_plate.tscn", "S2HoldPlate", Vector2(352, FLOOR_Y), {"puzzle_id": "s2_hold"})
	_inst("Puzzles", P + "attack_switch.tscn", "S2FarSwitch", Vector2(736, y_switch), {"puzzle_id": "s2_far_switch", "mode": 2})
	_logic("S2Lock", Vector2(680, 440), "s2_lock", ["S2HoldPlate", "S2FarSwitch"], 1, {})
	_gate("Gate2", 44, "S2Lock", 0, {"puzzle_id": "s2_gate", "close_delay": 1.0})
	# 3 TWO BLADES: two targets, two knights, one heartbeat (2 s).
	_inst("Puzzles", P + "puzzle_target.tscn", "S3TargetL", Vector2(800, y_switch), {"puzzle_id": "s3_target_l"})
	_inst("Puzzles", P + "puzzle_target.tscn", "S3TargetR", Vector2(1008, y_switch), {"puzzle_id": "s3_target_r"})
	_logic("S3Lock", Vector2(1100, 440), "s3_lock", ["S3TargetL", "S3TargetR"], 2,
		{"distinct_players": true, "latch": true, "window": 2.0})
	_gate("Gate3", 70, "S3Lock", 1, {"puzzle_id": "s3_gate"})
	# 4 TIMED GATE: the ledge switch opens it for 3 s; the far switch reopens it.
	_inst("Puzzles", P + "attack_switch.tscn", "S4LedgeSwitch", Vector2(73 * T, 25 * T - 18), {"puzzle_id": "s4_switch", "mode": 1, "active_time": 0.5, "block_material": 0})
	_inst("Puzzles", P + "attack_switch.tscn", "S4FarSwitch", Vector2(102 * T, y_switch), {"puzzle_id": "s4_far_switch", "mode": 1, "active_time": 0.5, "block_material": 0})
	_logic("S4Lock", Vector2(1580, 440), "s4_lock", ["S4LedgeSwitch", "S4FarSwitch"], 1, {})
	_gate("Gate4", 100, "S4Lock", 2, {"puzzle_id": "s4_gate", "open_time": 3.0, "warning_time": 1.0})
	# 5 SEPARATE ROUTES: one latch switch at the end of each route, different knights.
	_inst("Puzzles", P + "attack_switch.tscn", "S5UpperSwitch", Vector2(131 * T, 20 * T - 18), {"puzzle_id": "s5_upper", "mode": 2, "block_material": 1})
	_inst("Puzzles", P + "attack_switch.tscn", "S5LowerSwitch", Vector2(131 * T, y_switch), {"puzzle_id": "s5_lower", "mode": 2, "block_material": 1})
	_logic("S5Lock", Vector2(2220, 440), "s5_lock", ["S5UpperSwitch", "S5LowerSwitch"], 0, {"distinct_players": true, "latch": true})
	_gate("Gate5", 140, "S5Lock", 1, {"puzzle_id": "s5_gate"})
	# 6 BOTH SIDES: either plate holds Gate6, so each knight holds it for the other.
	_inst("Puzzles", P + "pressure_plate.tscn", "S6PlateLeft", Vector2(2272, FLOOR_Y), {"puzzle_id": "s6_left"})
	_inst("Puzzles", P + "pressure_plate.tscn", "S6PlateRight", Vector2(2592, FLOOR_Y), {"puzzle_id": "s6_right"})
	_logic("S6Lock", Vector2(2456, 440), "s6_lock", ["S6PlateLeft", "S6PlateRight"], 1, {})
	_gate("Gate6", 153, "S6Lock", 0, {"puzzle_id": "s6_gate", "close_delay": 0.5})
	# 7 BRIDGE: a plate on either side extends the platform across the pit.
	_inst("Puzzles", P + "pressure_plate.tscn", "S7PlateNear", Vector2(167 * T, FLOOR_Y), {"puzzle_id": "s7_near"})
	_inst("Puzzles", P + "pressure_plate.tscn", "S7PlateFar", Vector2(193 * T, FLOOR_Y), {"puzzle_id": "s7_far"})
	_logic("S7Lock", Vector2(2900, 420), "s7_lock", ["S7PlateNear", "S7PlateFar"], 1, {})
	var controller: Node = (load(P + "platform_controller.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	controller.name = "S7BridgeControl"
	_add_to(_group("Puzzles"), controller)
	controller.set(&"platform", controller.get_path_to(_group("Platforms").get_node("BridgeS7")))
	controller.set(&"controller", controller.get_path_to(_group("Puzzles").get_node("S7Lock")))
	controller.set(&"mode", 1)
	# 8 DISTRACTION: the switch sits in the slime's patrol.
	_inst("Puzzles", P + "attack_switch.tscn", "S8Switch", Vector2(3552, y_switch), {"puzzle_id": "s8_switch", "mode": 2, "block_material": 2})
	_gate("Gate8", 225, "S8Switch", 1, {"puzzle_id": "s8_gate"})
	# 9 RISK: the near plate is on hot ground; the far plate is safe.
	_inst("Puzzles", P + "pressure_plate.tscn", "S9HotPlate", Vector2(HOT[0] * T + 8, FLOOR_Y), {"puzzle_id": "s9_hot"})
	_inst("Puzzles", P + "pressure_plate.tscn", "S9SafePlate", Vector2(248 * T, FLOOR_Y), {"puzzle_id": "s9_safe"})
	_logic("S9Lock", Vector2(3900, 440), "s9_lock", ["S9HotPlate", "S9SafePlate"], 1, {})
	_gate("Gate9", 245, "S9Lock", 0, {"puzzle_id": "s9_gate", "close_delay": 1.0})
	# 10 END: both knights together.
	_inst("Puzzles", P + "trigger_zone.tscn", "EndZone", Vector2(253 * T, FLOOR_Y - 48),
		{"puzzle_id": "end_reunion", "size": Vector2(7 * T, 48), "required_count": 2, "mode": 1})


func _build_clues() -> void:
	for c: Array in [
			["ClueS1", Vector2(96, FLOOR_Y), "One stone remembers.\nTwo stones awaken."],
			["ClueS2", Vector2(424, FLOOR_Y), "Hold the light.\nLet the other pass."],
			["ClueS3", Vector2(904, FLOOR_Y), "Two blades.\nOne heartbeat."],
			["ClueS4", Vector2(1344, FLOOR_Y), "The door counts.\nOne strikes, one runs."],
			["ClueS5", Vector2(1736, FLOOR_Y), "Above and below.\nTwo hands, one door."],
			["ClueS6", Vector2(2360, FLOOR_Y), "The gate listens\nto both sides."],
			["ClueS7", Vector2(2632, FLOOR_Y), "The bridge walks\nonly when watched."],
			["ClueS8", Vector2(3296, FLOOR_Y), "It hungers for one.\nThe other works."],
			["ClueS9", Vector2(3784, FLOOR_Y), "Warm stone, open door.\nOne pays. Both pass."],
			["ClueEnd", Vector2(4100, FLOOR_Y), "Two knights.\nOne way forward."]]:
		_inst("Clues", P + "puzzle_clue.tscn", c[0], c[1], {"text": c[2], "sign_style": 1 if c[0] == "ClueS9" else 0})


func _build_labels() -> void:
	var spots := {
		"1 PLATES": Vector2(150, 360), "2 HOLD": Vector2(420, 360), "3 TARGETS": Vector2(870, 360),
		"4 TIMED": Vector2(1300, 300), "5 ROUTES": Vector2(1900, 200), "6 BOTH SIDES": Vector2(2380, 360),
		"7 BRIDGE": Vector2(2830, 360), "8 DISTRACT": Vector2(3420, 360), "9 RISK": Vector2(3760, 360),
		"10 END": Vector2(4090, 360),
	}
	for text: String in spots:
		_add_to(_group("Labels"), LevelBuilder.make_label(text, spots[text]))


func _build_knights() -> void:
	var spawns := [Vector2(40, FLOOR_Y), Vector2(72, FLOOR_Y)]
	for i in 2:
		var spawn := Marker2D.new()
		spawn.name = "SpawnP%d" % (i + 1)
		spawn.position = spawns[i]
		_add_to(_root, spawn)
	var knight_scene: PackedScene = load("res://scenes/players/knight.tscn")
	for i in 2:
		var knight: Node2D = knight_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		knight.name = "Knight%d" % (i + 1)
		knight.position = spawns[i]
		if i == 1:
			knight.set(&"profile", load("res://resources/players/p2_profile.tres"))
		knight.set(&"show_debug_tag", true)
		_add_to(_group("Knights"), knight)


# --- Helpers -----------------------------------------------------------------------

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


func _build_room() -> void:
	var root := Node.new()
	root.name = "PuzzleTestRoom"
	root.set_script(load("res://scenes/dev/puzzle_test_room.gd"))
	for spec: Array in [["Level", LEVEL_PATH], ["SplitScreenRig", "res://scenes/camera/split_screen_rig.tscn"],
			["PuzzleDebugHud", "res://scenes/dev/puzzle_debug_hud.tscn"]]:
		var node: Node = (load(spec[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = spec[0]
		LevelBuilder.add(root, root, node)
	LevelBuilder.save_scene(root, ROOM_PATH)
	root.free()
