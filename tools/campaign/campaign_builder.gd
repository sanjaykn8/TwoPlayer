extends RefCounted
## Builds one campaign level scene from a level spec (tools/campaign/world_*.gd), using only
## the game's reusable scenes. Coordinates are TILES (16 px). A "floor row" r is the row of
## the solid tile whose top is the walking surface, so feet stand at y = r * 16.
##
## Spec: {"id", "title", "world", "width", "height", "spawn": [x, r], "ops": [...]}.
## Ops (first element is the op name):
##   ["ground", x0, x1, r]               solid from row r to the bottom
##   ["fill", x0, y0, x1, y1]            solid rectangle      ["clear", x0, y0, x1, y1]  carve
##   ["ledge", x0, x1, r]                one-way tiles on row r
##   ["ladder", x, top_r, bottom_r]      one-way tile at (x, top_r) + a ladder down to bottom_r
##   ["spikes", x0, x1, r]               spikes standing on floor row r
##   ["lava", x0, x1, r, depth?]         carve rows r.. and fill them with lava (surface r*16)
##   ["hot", x0, x1, r]                  carve rows r, r+1 and put hot ground there
##   ["slime", "g"|"p", x, r, left, right, props?]   patrol limits in tiles from x
##   ["fruit", type, tier, x, r]  ["jar", type, x, r]  ["coins", n, x, r]  ["tile", x, r]
##   ["save", x, r]  ["exit", x, r]  ["clue", x, r, text]
##   ["plate", name, x, r, props?]  ["switch", name, x, r, props?]  ["target", name, x, r, props?]
##   ["zone", name, x0, y0, x1, y1, props?]   ["logic", name, inputs, mode, props?]
##   ["gate", name, x, r, height, controller, mode, props?]  (gate stands on floor row r)
##   ["moving"|"timed"|"collapse"|"blink", name, x, r, width, props?]  (surface at r*16;
##       moving: props.travel = Vector2i tiles)
##   ["control", platform, controller, mode]   ["seal", name]
##   ["boss", stats, x, r, arena_left, arena_right, seal]   ["deco", cell, x, r]
## Overhaul ops:
##   ["enemy", kind, x, r, left, right, props?]  kind: grunt brute guard archer bat ember
##       warchief captain crowned (bat: r = the row it hangs in, under a ceiling)
##   ["spring", x, r, props?]  ["fire", x, r, height, props?]  ["rock", x, r] (hangs from the
##       ceiling above row r)  ["saw", x, y, dx, dy, props?] (rail from the tile centre)
##   ["updraft"|"wind", x0, y0, x1, y1, props?]  ["ice", x0, x1, r]
##   ["crack", name, x, y, w, h]  cracked block (its cells are carved from the terrain)
##   ["lantern", x, y]  ["torch", x, y]  ["dark"]
##   ["arena", name, x0, y0, x1, y1, props?]  encounter zone; its gates FOLLOW it (mode 0)
## Ids are "<level id>_<name>" (stable: written into the scene at build time, never generated
## at run time). Every collectible id is unique in the whole campaign because of the prefix.

const T := 16
const WORLD_SOURCE := 0
const PLATFORM_SOURCE := 1
const TILESET := "res://resources/tilesets/dev_world_tileset.tres"
const WORLD_PNG := preload("res://assets/sprites/world_tileset.png")
const P := "res://scenes/puzzles/"
const SCENES := {
	"g": "res://scenes/enemies/green_slime.tscn",
	"p": "res://scenes/enemies/purple_slime.tscn",
	"fruit": "res://scenes/collectibles/fruit.tscn",
	"jar": "res://scenes/collectibles/jar.tscn",
	"coins": "res://scenes/collectibles/coin_stash.tscn",
	"tile": "res://scenes/collectibles/power_tile.tscn",
	"save": "res://scenes/campaign/save_point.tscn",
	"exit": "res://scenes/campaign/level_exit.tscn",
	"clue": "res://scenes/puzzles/puzzle_clue.tscn",
	"plate": "res://scenes/puzzles/pressure_plate.tscn",
	"switch": "res://scenes/puzzles/attack_switch.tscn",
	"target": "res://scenes/puzzles/puzzle_target.tscn",
	"zone": "res://scenes/puzzles/trigger_zone.tscn",
	"logic": "res://scenes/puzzles/puzzle_logic.tscn",
	"gate": "res://scenes/puzzles/puzzle_gate.tscn",
	"control": "res://scenes/puzzles/platform_controller.tscn",
	"moving": "res://scenes/platforms/moving_platform.tscn",
	"timed": "res://scenes/platforms/timed_platform.tscn",
	"collapse": "res://scenes/platforms/collapsing_platform.tscn",
	"blink": "res://scenes/platforms/disappearing_platform.tscn",
	"spikes": "res://scenes/hazards/spikes.tscn",
	"lava": "res://scenes/hazards/lava.tscn",
	"hot": "res://scenes/hazards/hot_ground.tscn",
	"fall": "res://scenes/hazards/fall_boundary.tscn",
	"ladder": "res://scenes/objects/ladder.tscn",
	"boss": "res://scenes/enemies/boss/boss_slime.tscn",
	"seal": "res://scenes/enemies/boss/boss_seal.tscn",
	"knight": "res://scenes/players/knight.tscn",
	"spring": "res://scenes/mechanisms/spring_mushroom.tscn",
	"envzone": "res://scenes/mechanisms/environment_zone.tscn",
	"saw": "res://scenes/mechanisms/saw_blade.tscn",
	"fire": "res://scenes/mechanisms/fire_jet.tscn",
	"rock": "res://scenes/mechanisms/falling_rock.tscn",
	"crack": "res://scenes/mechanisms/breakable_block.tscn",
	"lantern": "res://scenes/mechanisms/pogo_lantern.tscn",
	"arena": "res://scenes/mechanisms/encounter_zone.tscn",
	"dark": "res://scenes/mechanisms/darkness.tscn",
	"torch": "res://scenes/mechanisms/torch.tscn",
}
const ENEMIES := {
	"grunt": "res://scenes/enemies/orc_grunt.tscn",
	"brute": "res://scenes/enemies/orc_brute.tscn",
	"guard": "res://scenes/enemies/orc_guard.tscn",
	"archer": "res://scenes/enemies/hollow_archer.tscn",
	"bat": "res://scenes/enemies/cave_bat.tscn",
	"ember": "res://scenes/enemies/ember_slime.tscn",
	"warchief": "res://scenes/enemies/boss/orc_warchief.tscn",
	"captain": "res://scenes/enemies/boss/hollow_captain.tscn",
	"crowned": "res://scenes/enemies/boss/crowned_hollow.tscn",
}
const FRUIT := {"green": 0, "yellow": 1, "red": 2, "purple": 3}
const JAR := {"green": 0, "red": 1, "yellow": 2, "blue": 3}

var spec: Dictionary
var theme: Dictionary
var root: Node2D
var solid := {}
var one_way := {}
var occupied := {}
var ids := {}
var errors := PackedStringArray()
var _groups := {}
var _named := {}
var _counters := {}


func build(level_spec: Dictionary, world_theme: Dictionary) -> Node2D:
	spec = level_spec
	theme = world_theme
	var level_id: String = spec.id
	root = Node2D.new()
	root.name = level_id.to_pascal_case()
	root.set_meta(&"level_id", level_id)
	for op: Array in spec.ops:
		_terrain_op(op)
	_background()
	_backdrop()
	var terrain := _terrain()
	_add(root, terrain)
	var bounds: Node2D = (load("res://components/camera/camera_bounds.gd") as GDScript).new()
	bounds.name = "CameraBounds"
	bounds.set(&"size", Vector2(spec.width * T, spec.height * T))
	_add(root, bounds)
	var sx: int = spec.spawn[0]
	var sr: int = spec.spawn[1]
	for i in 2:
		var marker := Marker2D.new()
		marker.name = "SpawnP%d" % (i + 1)
		marker.position = Vector2((sx + i * 2) * T + 8, sr * T)
		_add(root, marker)
	for op: Array in spec.ops:
		_entity_op(op)
	_decorate()
	var fall := _inst("Hazards", SCENES.fall, "FallBoundary", Vector2(0, spec.height * T + 32))
	fall.set(&"size", Vector2(spec.width * T, 64))
	for i in 2:
		var knight: Node2D = (load(SCENES.knight) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		knight.name = "Knight%d" % (i + 1)
		knight.position = Vector2((sx + i * 2) * T + 8, sr * T)
		if i == 1:
			knight.set(&"profile", load("res://resources/players/p2_profile.tres"))
		_add(_group("Knights"), knight)
	return root


# --- Terrain ---------------------------------------------------------------------------------

func _terrain_op(op: Array) -> void:
	match op[0]:
		"ground":
			_fill(solid, op[1], op[3], op[2], spec.height - 1, true)
		"fill":
			_fill(solid, op[1], op[2], op[3], op[4], true)
		"clear":
			_fill(solid, op[1], op[2], op[3], op[4], false)
			_fill(one_way, op[1], op[2], op[3], op[4], false)
		"ledge":
			_fill(one_way, op[1], op[3], op[2], op[3], true)
		"ladder":
			one_way[Vector2i(op[1], op[2])] = true
		"lava":
			var depth: int = op[4] if op.size() > 4 else 1
			_fill(solid, op[1], op[3], op[2], op[3] + depth - 1, false)
		"hot":
			_fill(solid, op[1], op[3], op[2], op[3] + 1, false)
		"crack":
			_fill(solid, op[2], op[3], op[2] + op[4] - 1, op[3] + op[5] - 1, false)


func _fill(cells: Dictionary, x0: int, y0: int, x1: int, y1: int, on: bool) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if on:
				cells[Vector2i(x, y)] = true
			else:
				cells.erase(Vector2i(x, y))


func _terrain() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = load(TILESET)
	for cell: Vector2i in solid:
		var top := not solid.has(cell + Vector2i.UP)
		var atlas: Vector2i = theme.top if top else theme.fill
		if not top and solid.has(cell + Vector2i.LEFT) == false and solid.has(cell + Vector2i.RIGHT) == false:
			atlas = theme.wall
		layer.set_cell(cell, WORLD_SOURCE, atlas)
	for cell: Vector2i in one_way:
		if not solid.has(cell):
			layer.set_cell(cell, PLATFORM_SOURCE, _platform_atlas(cell))
	return layer


func _platform_atlas(cell: Vector2i) -> Vector2i:
	var row: int = theme.platform_row
	var left := one_way.has(cell + Vector2i.LEFT)
	var right := one_way.has(cell + Vector2i.RIGHT)
	if not left and not right:
		return Vector2i(0, row)
	if not left or (right and cell.x % 2 == 0):
		return Vector2i(1, row)
	return Vector2i(2, row)


func _background() -> void:
	var sky := TextureRect.new()
	sky.name = "Sky"
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	var a: Color = theme.sky_top
	var b: Color = theme.sky_bottom
	gradient.colors = PackedColorArray([a, a.lerp(b, 0.25), a.lerp(b, 0.5), a.lerp(b, 0.75), b])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = Vector2(spec.width * T, spec.height * T)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -20
	_add(root, sky)


## Far scenery: dark, non-colliding silhouettes of the world's own wall tiles (ruined
## columns, cave pillars, towers) standing on the ground behind the play space. Seeded by the
## level id, so every build is identical.
func _backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spec.id + "_far")
	var tex := AtlasTexture.new()
	tex.atlas = WORLD_PNG
	var cell: Vector2i = theme.wall
	tex.region = Rect2(cell.x * T, cell.y * T, T, T)
	var x := rng.randi_range(2, 8)
	while x < spec.width - 2:
		var surface := -1
		for r in range(2, spec.height):
			if solid.has(Vector2i(x, r)):
				surface = r
				break
		if surface > 6:
			var rows := rng.randi_range(3, mini(12, surface - 3))
			var cols := rng.randi_range(1, 3)
			var column := TextureRect.new()
			column.texture = tex
			column.stretch_mode = TextureRect.STRETCH_TILE
			column.position = Vector2(x * T, (surface - rows) * T)
			column.size = Vector2(cols * T, rows * T)
			# Faint and translucent: clearly scenery, never mistaken for a wall.
			var tint: Color = Color(theme.sky_bottom).lerp(Color(theme.sky_top), 0.5)
			column.modulate = Color(tint.lightened(0.1), 0.28)
			column.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.z_index = -15
			_add(_group("FarScenery"), column)
		x += rng.randi_range(9, 20)


## Background scenery from the world's palette on open floor, behind everything, placed
## with a fixed seed (the same every build).
func _decorate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spec.id)
	var pieces: Array = theme.deco
	if pieces.is_empty():
		return
	var x := 3
	while x < spec.width - 3:
		x += rng.randi_range(5, 11)
		for r in range(2, spec.height):
			var c := Vector2i(x, r)
			if solid.has(c) and not solid.has(c + Vector2i.UP) and not solid.has(c + Vector2i(0, -2)) \
					and not one_way.has(c + Vector2i.UP) and not occupied.has(c + Vector2i.UP) and not occupied.has(c):
				var piece: Array = pieces[rng.randi_range(0, pieces.size() - 1)]
				var region := Rect2(piece[0] * T, piece[1] * T, T, piece[2] * T)
				var sprite := Sprite2D.new()
				sprite.texture = WORLD_PNG
				sprite.region_enabled = true
				sprite.region_rect = region
				sprite.centered = false
				sprite.position = Vector2(x * T, r * T - region.size.y)
				sprite.modulate = theme.deco_tint
				sprite.z_index = -5
				_add(_group("Scenery"), sprite)
				break


# --- Entities ---------------------------------------------------------------------------------

func _entity_op(op: Array) -> void:
	var lid: String = spec.id
	match op[0]:
		"ladder":
			var ladder := _inst("Climbables", SCENES.ladder, _auto("Ladder"), Vector2(op[1] * T + 8, op[2] * T))
			ladder.set(&"size", Vector2(16, (op[3] - op[2]) * T))
			_mark(op[1] - 1, op[2] - 1, op[1] + 1, op[3])
		"spikes":
			var n := _inst("Hazards", SCENES.spikes, _auto("Spikes"), Vector2(op[1] * T, (op[3] - 1) * T))
			n.set(&"size", Vector2((op[2] - op[1] + 1) * T, T))
			_mark(op[1], op[3] - 1, op[2], op[3] - 1)
		"lava":
			var depth: int = op[4] if op.size() > 4 else 1
			var n := _inst("Hazards", SCENES.lava, _auto("Lava"), Vector2(op[1] * T, op[3] * T))
			n.set(&"size", Vector2((op[2] - op[1] + 1) * T, depth * T))
			_mark(op[1], op[3] - 1, op[2], op[3] + depth - 1)
		"hot":
			var n := _inst("Hazards", SCENES.hot, _auto("HotGround"), Vector2(op[1] * T, op[3] * T))
			n.set(&"size", Vector2((op[2] - op[1] + 1) * T, 2 * T))
			_mark(op[1], op[3] - 1, op[2], op[3] + 1)
		"slime":
			var name := _auto("Slime")
			var n := _inst("Enemies", SCENES[op[1]], name, _feet(op[2], op[3]))
			n.set(&"save_id", _id(name))
			n.set(&"patrol_left", float(op[4]) * T)
			n.set(&"patrol_right", float(op[5]) * T)
			_props(n, op, 6)
			_mark(op[2], op[3] - 1, op[2], op[3] - 1)
		"fruit":
			var name := _auto("Fruit%s" % str(op[1]).capitalize())
			var n := _inst("Items", SCENES.fruit, name, _feet(op[3], op[4]))
			n.set(&"fruit_type", FRUIT[op[1]])
			n.set(&"tier", op[2])
			n.set(&"collectible_id", _id(name))
			_mark(op[3], op[4] - 1, op[3], op[4] - 1)
		"jar":
			var name := _auto("Jar%s" % str(op[1]).capitalize())
			var n := _inst("Items", SCENES.jar, name, _feet(op[2], op[3]))
			n.set(&"jar_type", JAR[op[1]])
			n.set(&"collectible_id", _id(name))
			_mark(op[2], op[3] - 1, op[2], op[3] - 1)
		"coins":
			var name := _auto("Coins")
			var n := _inst("Items", SCENES.coins, name, _feet(op[2], op[3]))
			n.set(&"amount", op[1])
			n.set(&"collectible_id", _id(name))
			_mark(op[2], op[3] - 1, op[2], op[3] - 1)
		"tile":
			_inst("Items", SCENES.tile, _auto("PowerTile"), Vector2(op[1] * T + 8, op[2] * T + 8))
			solid_extra[Vector2i(op[1], op[2])] = true
			_mark(op[1], op[2], op[1], op[2])
		"save":
			var name := _auto("SavePoint")
			var n := _inst("Campaign", SCENES.save, name, _feet(op[1], op[2]))
			n.set(&"save_id", _id(name))
			_mark(op[1] - 1, op[2] - 2, op[1] + 1, op[2] - 1)
		"exit":
			_inst("Campaign", SCENES.exit, "Exit", Vector2(op[1] * T + 4, op[2] * T))
			_mark(op[1], op[2] - 3, op[1] + 1, op[2] - 1)
		"clue":
			var n := _inst("Clues", SCENES.clue, _auto("Clue"), _feet(op[1], op[2]))
			n.set(&"text", op[3])
			_mark(op[1] - 3, op[2] - 3, op[1] + 3, op[2] - 1)
		"plate":
			var n := _puzzle(op[1], SCENES.plate, Vector2(op[2] * T, op[3] * T))
			_props(n, op, 4)
			_mark(op[2], op[3] - 1, op[2] + 1, op[3] - 1)
		"switch", "target":
			var n := _puzzle(op[1], SCENES[op[0]], Vector2(op[2] * T + 8, op[3] * T - 22))
			_props(n, op, 4)
			_mark(op[2] - 1, op[3] - 2, op[2] + 1, op[3] - 1)
		"zone":
			var n := _puzzle(op[1], SCENES.zone, Vector2(op[2] * T, op[3] * T))
			n.set(&"size", Vector2((op[4] - op[2] + 1) * T, (op[5] - op[3] + 1) * T))
			_props(n, op, 6)
		"seal":
			_puzzle(op[1], SCENES.seal, Vector2.ZERO)
		"logic":
			var n := _puzzle(op[1], SCENES.logic, Vector2.ZERO)
			var paths: Array[NodePath] = []
			for input_name: String in op[2]:
				paths.append(n.get_path_to(_named[input_name]))
			n.set(&"inputs", paths)
			n.set(&"mode", op[3])
			_props(n, op, 4)
		"gate":
			var n := _puzzle(op[1], SCENES.gate, Vector2(op[2] * T, (op[3] - op[4]) * T))
			n.set(&"height_tiles", op[4])
			n.set(&"controller", n.get_path_to(_named[op[5]]))
			n.set(&"mode", op[6])
			_props(n, op, 7)
			_mark(op[2] - 1, op[3] - op[4], op[2] + 1, op[3] - 1)
		"moving", "timed", "collapse", "blink":
			var n := _inst("Platforms", SCENES[op[0]], op[1], Vector2(op[2] * T, op[3] * T))
			_named[op[1]] = n
			n.set(&"save_id", _id(op[1]))
			n.set(&"width_tiles", op[4])
			if op.size() > 5:
				var props: Dictionary = op[5].duplicate()
				if props.has("travel"):
					props["travel"] = Vector2(props.travel) * T
				for key: String in props:
					n.set(key, props[key])
			_mark(op[2], op[3], op[2] + op[4] - 1, op[3])
		"control":
			var n := _inst("Puzzles", SCENES.control, _auto("Control"), Vector2.ZERO)
			n.set(&"platform", n.get_path_to(_named[op[1]]))
			n.set(&"controller", n.get_path_to(_named[op[2]]))
			n.set(&"mode", op[3])
		"boss":
			var name := _auto("Boss")
			var n := _inst("Enemies", SCENES.boss, name, _feet(op[2], op[3]))
			n.set(&"stats", load("res://resources/enemies/%s.tres" % op[1]))
			n.set(&"save_id", _id(name))
			n.set(&"arena_left", float(op[4]) * T)
			n.set(&"arena_right", float(op[5]) * T)
			n.set(&"seal", n.get_path_to(_named[op[6]]))
		"enemy":
			var name := _auto(str(op[1]).capitalize())
			var at := _feet(op[2], op[3]) if op[1] != "bat" else Vector2(op[2] * T + 8, op[3] * T + 12)
			var n := _inst("Enemies", ENEMIES[op[1]], name, at)
			n.set(&"save_id", _id(name))
			n.set(&"patrol_left", float(op[4]) * T)
			n.set(&"patrol_right", float(op[5]) * T)
			_props(n, op, 6)
			_mark(op[2], op[3] - 1, op[2], op[3] - 1)
		"spring":
			var n := _inst("Mechanisms", SCENES.spring, _auto("Spring"), _feet(op[1], op[2]))
			_props(n, op, 3)
			_mark(op[1], op[2] - 1, op[1], op[2] - 1)
		"fire":
			var n := _inst("Mechanisms", SCENES.fire, _auto("FireJet"), _feet(op[1], op[2]))
			n.set(&"height_tiles", op[3])
			_props(n, op, 4)
			_mark(op[1], op[2] - op[3], op[1], op[2] - 1)
		"rock":
			var n := _inst("Mechanisms", SCENES.rock, _auto("Rock"), Vector2(op[1] * T + 8, op[2] * T))
			_props(n, op, 3)
		"saw":
			var n := _inst("Mechanisms", SCENES.saw, _auto("Saw"), Vector2(op[1] * T + 8, op[2] * T + 8))
			n.set(&"travel", Vector2(op[3], op[4]) * T)
			_props(n, op, 5)
		"updraft", "wind":
			var n := _inst("Mechanisms", SCENES.envzone, _auto(str(op[0]).capitalize()), Vector2(op[1] * T, op[2] * T))
			n.set(&"kind", EnvironmentZone.Kind.UPDRAFT if op[0] == "updraft" else EnvironmentZone.Kind.WIND)
			n.set(&"size", Vector2((op[3] - op[1] + 1) * T, (op[4] - op[2] + 1) * T))
			_props(n, op, 5)
		"ice":
			var n := _inst("Mechanisms", SCENES.envzone, _auto("Ice"), Vector2(op[1] * T, (op[3] - 1) * T))
			n.set(&"kind", EnvironmentZone.Kind.ICE)
			n.set(&"size", Vector2((op[2] - op[1] + 1) * T, T))
		"crack":
			var n := _inst("Mechanisms", SCENES.crack, op[1], Vector2(op[2] * T, op[3] * T))
			n.set(&"block_id", _id(op[1]))
			n.set(&"size_tiles", Vector2i(op[4], op[5]))
			var fill: Vector2i = theme.fill
			n.set(&"tile_region", Rect2(fill.x * T, fill.y * T, T, T))
			_mark(op[2], op[3], op[2] + op[4] - 1, op[3] + op[5] - 1)
		"lantern":
			_inst("Mechanisms", SCENES.lantern, _auto("Lantern"), Vector2(op[1] * T + 8, op[2] * T + 8))
		"torch":
			_inst("Scenery", SCENES.torch, _auto("Torch"), Vector2(op[1] * T + 8, op[2] * T + 12))
		"dark":
			_inst("Mechanisms", SCENES.dark, "Darkness", Vector2.ZERO)
		"arena":
			var n := _puzzle(op[1], SCENES.arena, Vector2(op[2] * T, op[3] * T))
			n.set(&"size", Vector2((op[4] - op[2] + 1) * T, (op[5] - op[3] + 1) * T))
			_props(n, op, 6)
		"deco":
			var cell: Array = op[1]
			var sprite := Sprite2D.new()
			sprite.texture = WORLD_PNG
			sprite.region_enabled = true
			sprite.region_rect = Rect2(cell[0] * T, cell[1] * T, T, cell[2] * T)
			sprite.centered = false
			sprite.position = Vector2(op[2] * T, op[3] * T - cell[2] * T)
			sprite.z_index = -5
			_add(_group("Scenery"), sprite)


## Solid cells that are not terrain (power tiles); the analyzer reads them from the scene.
var solid_extra := {}


func _puzzle(name: String, path: String, at: Vector2) -> Node:
	var n := _inst("Puzzles", path, name, at)
	n.set(&"puzzle_id", _id(name))
	_named[name] = n
	return n


func _props(node: Node, op: Array, index: int) -> void:
	if op.size() > index and op[index] is Dictionary:
		for key: String in op[index]:
			node.set(key, op[index][key])


func _feet(x: int, r: int) -> Vector2:
	return Vector2(x * T + 8, r * T)


func _mark(x0: int, y0: int, x1: int, y1: int) -> void:
	_fill(occupied, x0, y0, x1, y1, true)


func _auto(prefix: String) -> String:
	_counters[prefix] = int(_counters.get(prefix, 0)) + 1
	return "%s%d" % [prefix, _counters[prefix]]


## "<level>_<node name in snake case>": stable, unique within the campaign.
func _id(name: String) -> String:
	var id := "%s_%s" % [spec.id, name.to_snake_case()]
	if ids.has(id):
		errors.append("duplicate id %s" % id)
	ids[id] = true
	return id


func _group(group_name: String) -> Node2D:
	if not _groups.has(group_name):
		var node := Node2D.new()
		node.name = group_name
		_add(root, node)
		_groups[group_name] = node
	return _groups[group_name]


func _inst(group_name: String, path: String, node_name: String, at: Vector2) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = node_name
	if node is Node2D:
		node.position = at
	_add(_group(group_name), node)
	return node


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child, true)
	child.owner = root
