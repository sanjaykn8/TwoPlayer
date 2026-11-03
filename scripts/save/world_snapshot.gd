class_name WorldSnapshot
extends RefCounted
## Capture and restore of the CURRENT level's live state (the "world" section of a save).
## Run-wide progression (stats, effects, coins, collected ids, saved puzzle states, defeated
## enemies, campaign position) lives in RunState and is restored before the level is built.
##
## Captured, by stable id only (never NodePaths, instance ids or object references):
##   players    position, facing, last safe position
##   enemies    living slimes with a save_id (SlimeStagger progress/timer, poison, home);
##              defeated ones are recorded in the run and remove themselves on load
##   coins      dropped coins not yet collected (position, motion, pickup delay)
##   puzzles    temporary puzzle state (timed gates, momentary switches, timed plates, active
##              locks); completed/latched states are in the run's PuzzleRegistry
##   platforms  live state of platforms with a save_id (moving progress, timed/collapsing state)
## Restore order (CampaignGame): before_tree() on the instanced level, add it to the tree with
## processing disabled, after_ready(), then enable processing. Nothing runs in between, so no
## pickup, damage, puzzle or AI signal can act on a half-restored level.

const MAX_COORD := 100000.0
const COIN_SCENE := "res://scenes/objects/dropped_coin.tscn"
## dev_world_tileset source 0 = solid terrain (source 1 = one-way platforms).
const SOLID_TILE_SOURCE := 0


# --- Capture --------------------------------------------------------------------------------

static func capture(level: Node, knights: Array) -> Dictionary:
	var players := {}
	for knight: Knight in knights:
		var spot := knight.safe_spot
		players[str(knight.player_id())] = {
			"x": knight.global_position.x, "y": knight.global_position.y, "facing": knight.facing,
			"safe_x": spot.last_safe_position.x, "safe_y": spot.last_safe_position.y,
			"has_safe": spot.has_safe_position,
		}
	var enemies := {}
	var coins := []
	var puzzles := {}
	var platforms := {}
	var coin_ids := {}
	for node in level.find_children("*", "", true, false):
		if node.is_queued_for_deletion():
			continue
		if node is Slime:
			var slime := node as Slime
			if slime.save_id != "" and not slime.is_dead():
				enemies[slime.save_id] = slime.save_state()
		elif node is DroppedCoin:
			var coin := node as DroppedCoin
			if coin.is_collected():
				continue
			if coin.save_id == "" or coin_ids.has(coin.save_id):
				coin.save_id = _free_id("coin", coin_ids)
			coin_ids[coin.save_id] = true
			coins.append(coin.save_state())
		elif node is PuzzleSource and node.puzzle_id != "":
			var live: Dictionary = node.capture_live()
			if not live.is_empty():
				puzzles[node.puzzle_id] = live
		elif node is PlatformBody and node.save_id != "":
			platforms[node.save_id] = node.capture_live()
	return {"level_id": str(level.get_meta(&"level_id", "")), "players": players, "enemies": enemies,
		"coins": coins, "puzzles": puzzles, "platforms": platforms}


static func _free_id(prefix: String, used: Dictionary) -> String:
	var n := 0
	while used.has("%s_%d" % [prefix, n]):
		n += 1
	return "%s_%d" % [prefix, n]


# --- Validation -----------------------------------------------------------------------------

## "" when `world` is a valid world section for `level_id` (an empty Dictionary is valid: a
## fresh level), else the first problem found.
static func validate(world: Variant, level_id: String) -> String:
	if typeof(world) != TYPE_DICTIONARY:
		return "world is not a dictionary"
	if (world as Dictionary).is_empty():
		return ""
	for key in ["level_id", "players", "enemies", "coins", "puzzles", "platforms"]:
		if not world.has(key):
			return "world.%s missing" % key
	if str(world.level_id) != level_id:
		return "world level %s does not match %s" % [world.level_id, level_id]
	if typeof(world.players) != TYPE_DICTIONARY or typeof(world.enemies) != TYPE_DICTIONARY \
			or typeof(world.coins) != TYPE_ARRAY or typeof(world.puzzles) != TYPE_DICTIONARY \
			or typeof(world.platforms) != TYPE_DICTIONARY:
		return "world sections have the wrong types"
	for id in ["1", "2"]:
		if not world.players.has(id):
			return "world.players.%s missing" % id
		var p: Variant = world.players[id]
		if typeof(p) != TYPE_DICTIONARY:
			return "player %s malformed" % id
		for key in ["x", "y", "facing", "safe_x", "safe_y", "has_safe"]:
			if not p.has(key):
				return "player %s: %s missing" % [id, key]
		if not (_coord_ok(p.x) and _coord_ok(p.y) and _coord_ok(p.safe_x) and _coord_ok(p.safe_y)):
			return "player %s position out of range" % id
	for enemy_id: Variant in world.enemies:
		if not SaveIds.is_valid_id(str(enemy_id)) or typeof(world.enemies[enemy_id]) != TYPE_DICTIONARY:
			return "enemy entry %s malformed" % enemy_id
		var e: Dictionary = world.enemies[enemy_id]
		if not (e.has("x") and e.has("y") and _coord_ok(e.x) and _coord_ok(e.y)):
			return "enemy %s position invalid" % enemy_id
		if not LevelCatalog.ENTITY_SCENES.has(str(e.get("type", ""))):
			return "enemy %s has an unknown type" % enemy_id
	var seen := {}
	for c: Variant in world.coins:
		if typeof(c) != TYPE_DICTIONARY:
			return "coin entry malformed"
		for key in ["id", "x", "y", "vx", "vy", "resting", "delay"]:
			if not c.has(key):
				return "coin: %s missing" % key
		var cid := str(c.id)
		if not SaveIds.is_valid_id(cid) or seen.has(cid):
			return "coin id %s invalid or duplicated" % cid
		seen[cid] = true
		if not (_coord_ok(c.x) and _coord_ok(c.y)) or float(c.delay) < 0.0 or float(c.delay) > 60.0:
			return "coin %s values out of range" % cid
	for section in ["puzzles", "platforms"]:
		for entry_id: Variant in world[section]:
			if not SaveIds.is_valid_id(str(entry_id)) or typeof(world[section][entry_id]) != TYPE_DICTIONARY:
				return "%s entry %s malformed" % [section, entry_id]
	return ""


static func _coord_ok(value: Variant) -> bool:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return false
	var v := float(value)
	return is_finite(v) and absf(v) < MAX_COORD


# --- Restore --------------------------------------------------------------------------------

## Before the level enters the tree: knight positions and facing (so the first physics frame
## already has everyone in place and nothing overlaps a spawn point by accident).
static func before_tree(level: Node, world: Dictionary) -> void:
	if world.is_empty():
		return
	for knight: Knight in _knights(level):
		var p: Dictionary = world.players.get(str(knight.player_id()), {})
		if p.is_empty():
			continue
		knight.position = Vector2(float(p.x), float(p.y))
		knight.facing = 1 if int(p.facing) >= 0 else -1


## Right after the level's _ready() (still the same frame, processing disabled). Returns the
## list of problems (entities that could not be restored and the fallback used).
static func after_ready(level: Node, world: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var knights := _knights(level)
	for knight in knights:
		var spawn := level.get_node_or_null("SpawnP%d" % knight.player_id()) as Node2D
		if spawn != null:
			knight.safe_spot.spawn_position = spawn.global_position
		if world.is_empty():
			continue
		var p: Dictionary = world.players.get(str(knight.player_id()), {})
		knight.teleport_to(knight.global_position)  # clean movement state, nothing mid-attack
		if bool(p.get("has_safe", false)):
			knight.safe_spot.last_safe_position = Vector2(float(p.safe_x), float(p.safe_y))
			knight.safe_spot.has_safe_position = true
	if world.is_empty():
		return problems
	var slimes := {}
	var puzzles := {}
	var platforms := {}
	for node in level.find_children("*", "", true, false):
		if node.is_queued_for_deletion():
			continue
		if node is Slime and node.save_id != "":
			slimes[node.save_id] = node
		elif node is PuzzleSource and node.puzzle_id != "":
			puzzles[node.puzzle_id] = node
		elif node is PlatformBody and node.save_id != "":
			platforms[node.save_id] = node
	for id: String in slimes:
		var slime: Slime = slimes[id]
		if not world.enemies.has(id):
			# Not alive in the save: it was defeated (normally already removed via the run).
			slime.queue_free()
			continue
		if not slime.restore_state(world.enemies[id]):
			problems.append("enemy %s: bad saved state, kept at its level start" % id)
	for id: String in world.enemies:
		if not slimes.has(id):
			problems.append("enemy %s: not in this level, ignored" % id)
	var coin_scene: PackedScene = load(COIN_SCENE)
	for data: Dictionary in world.coins:
		var coin := coin_scene.instantiate() as DroppedCoin
		level.add_child(coin)
		coin.restore_state(data)
	for id: String in world.puzzles:
		if puzzles.has(id):
			(puzzles[id] as PuzzleSource).apply_live(world.puzzles[id])
		else:
			problems.append("puzzle %s: not in this level, ignored" % id)
	for id: String in world.platforms:
		if platforms.has(id):
			var platform := platforms[id] as PlatformBody
			platform.apply_live(world.platforms[id])
			for knight in knights:
				if platform.collision_enabled() and knight_rect(knight).intersects(platform.interior_rect()):
					platform.fade_in_safely()
					problems.append("platform %s: restored around P%d, fades in once clear" % [id, knight.player_id()])
		else:
			problems.append("platform %s: not in this level, ignored" % id)
	for knight in knights:
		if not knight_position_is_clear(knight):
			problems.append("P%d restored inside solid geometry: moved to a safe position" % knight.player_id())
			var safe := knight.safe_spot.last_safe_position if knight.safe_spot.has_safe_position else knight.safe_spot.spawn_position
			knight.teleport_to(safe)
	return problems


## The knight's body rectangle (global), 1 px inside its collision shape.
static func knight_rect(knight: Knight) -> Rect2:
	var body := knight.get_node("Body") as CollisionShape2D
	var box := (body.shape as RectangleShape2D).size - Vector2(2, 2)
	return Rect2(knight.global_position + body.position - box * 0.5, box)


## True when the knight's body overlaps no solid terrain tile, closed gate or solid platform.
## Geometric on purpose: physics queries do not see a level added in the same frame.
static func knight_position_is_clear(knight: Knight) -> bool:
	var level := knight.owner if knight.owner != null else knight.get_parent()
	return not solid_hit(level, knight_rect(knight))


static func solid_hit(level: Node, rect: Rect2) -> bool:
	var terrain := level.get_node_or_null("Terrain") as TileMapLayer
	if terrain != null:
		var first := terrain.local_to_map(terrain.to_local(rect.position))
		var last := terrain.local_to_map(terrain.to_local(rect.end))
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				if terrain.get_cell_source_id(Vector2i(x, y)) == SOLID_TILE_SOURCE:
					return true
	for node in level.find_children("*", "", true, false):
		if node is PuzzleGate and (node as PuzzleGate).state == PuzzleGate.State.CLOSED:
			var gate := node as PuzzleGate
			if Rect2(gate.global_position, Vector2(gate.width, gate.height_px())).intersects(rect):
				return true
		elif node is PlatformBody and not (node as PlatformBody).one_way and (node as PlatformBody).collision_enabled():
			if (node as PlatformBody).interior_rect().intersects(rect):
				return true
	return false


static func _knights(level: Node) -> Array[Knight]:
	var found: Array[Knight] = []
	for node in level.find_children("*", "", true, false):
		if node is Knight:
			found.append(node)
	found.sort_custom(func(a: Knight, b: Knight) -> bool: return a.player_id() < b.player_id())
	return found
