extends RefCounted
## Static playability check of a level scene (no physics): where two knights can stand and
## move, which puzzle inputs they can reach, which gates that opens, and whether the exit,
## every collectible and every mechanism is reachable. Used by tests/gameplay/test_campaign_*.
##
## Movement model (tiles; conservative against the knight's physics: jump 3.5 tiles high,
## about 4.5 tiles across; the limits are checked against real jumps in test_campaign_physics):
##   walk to a neighbouring standing cell; fall off an edge; drop through a one-way tile;
##   climb ladders; ride moving platforms anywhere along their path;
##   jump: up 3 rows within 2 columns, up 2 within 3, up 1 or level within 4,
##         down within 4 + half the drop (max 6) columns.
## A standing cell (x, r): the knight's feet on row line r over column x. It needs support
## at (x, r) (terrain, one-way tile, platform, power tile) and two free body cells above,
## and no lava, spikes or hot ground in its body cells.
##
## Puzzles: staged. Gates start closed (unless start_open); a gate opens when its controller
## can be activated from the reachable area; repeat until nothing changes. Boss seals count
## as activatable only in the `with_bosses` pass (optional content must never be required).

const T := 16.0
const FELL_OUT := Vector2i(-2, -2)
const MAX_DX := {3: 2, 2: 3, 1: 4, 0: 4}

var level: Node
var width := 0
var height := 0
var solid := {}
var one_way := {}
var hazard := {}
var ladders := {}        # cell -> true (climbable cells)
var platforms := {}      # cell -> platform name (support), rebuilt as controllers activate
var _platform_paths := {} # name -> {"start": cells, "path": cells}
var _platform_control := {} # platform name -> controller node (PlatformController)
var gates := {}          # gate node -> {"cells": [...]}
var gate_cells := {}     # cell -> gate node
var sources := {}        # name -> node
var spawn: Array[Vector2i] = []
var exit_cells: Array[Vector2i] = []
var reach := {}
var open_gates := {}
var problems := PackedStringArray()
var warnings := PackedStringArray()


func _init(scene_root: Node) -> void:
	level = scene_root
	_read()
	_rebuild_platforms({}, false)


# --- Reading the scene -----------------------------------------------------------------------

func _read() -> void:
	var terrain := level.get_node("Terrain") as TileMapLayer
	for cell in terrain.get_used_cells():
		if terrain.get_cell_source_id(cell) == 0:
			solid[cell] = true
		else:
			one_way[cell] = true
		width = maxi(width, cell.x + 1)
		height = maxi(height, cell.y + 1)
	var bounds := level.get_node_or_null("CameraBounds")
	if bounds != null:
		var size: Vector2 = bounds.get(&"size")
		width = maxi(width, int(size.x / T))
		height = maxi(height, int(size.y / T))
	for i in 2:
		var marker := level.get_node_or_null("SpawnP%d" % (i + 1)) as Node2D
		if marker != null:
			spawn.append(_cell_of(marker.position))
	for node in level.find_children("*", "", true, false):
		if node is Hazard:
			var h := node as Hazard
			if h.kind == Hazard.Kind.FALL:
				continue
			_mark_rect(hazard, Rect2(h.position, h.size), true)
			if h.kind == Hazard.Kind.HOT_GROUND:
				_mark_rect(solid, Rect2(h.position, h.size), true)
		elif node is Climbable:
			var c := node as Climbable
			var col := int(floor(c.position.x / T))
			for r in range(int(c.position.y / T), int((c.position.y + c.size.y) / T) + 1):
				ladders[Vector2i(col, r)] = true
		elif node is PowerTile:
			solid[_cell_of((node as Node2D).position - Vector2(0, 8))] = true
		elif node is PlatformBody:
			_read_platform(node as PlatformBody)
		elif node is PlatformController:
			var pc := node as PlatformController
			var platform := pc.get_node_or_null(pc.platform)
			var controller := pc.get_node_or_null(pc.controller)
			if platform != null and controller != null:
				_platform_control[String(platform.name)] = controller
		elif node is PuzzleGate:
			var g := node as PuzzleGate
			var cells: Array[Vector2i] = []
			var x0 := int(g.position.x / T)
			for dx in range(int(ceil(g.width / T))):
				for r in range(g.height_tiles):
					cells.append(Vector2i(x0 + dx, int(g.position.y / T) + r))
			gates[g] = {"cells": cells}
			for gc in cells:
				gate_cells[gc] = g
			sources[String(g.name)] = g
		elif node is PuzzleSource:
			sources[String(node.name)] = node
		elif node is LevelExit:
			var e := node as LevelExit
			for dx in range(int(ceil(e.size.x / T)) + 1):
				exit_cells.append(Vector2i(int(e.position.x / T) + dx, int(e.position.y / T)))


func _read_platform(p: PlatformBody) -> void:
	var start := p.position
	var travel := Vector2.ZERO
	if p is MovingPlatform:
		travel = (p as MovingPlatform).travel
	var steps := int(maxf(absf(travel.x), absf(travel.y)) / T)
	var start_cells: Array[Vector2i] = []
	var path_cells: Array[Vector2i] = []
	for i in range(steps + 1):
		var at := start + travel * (float(i) / maxf(steps, 1))
		for dx in p.width_tiles:
			path_cells.append(_cell_of(at) + Vector2i(dx, 0))
			if i == 0:
				start_cells.append(_cell_of(at) + Vector2i(dx, 0))
	_platform_paths[String(p.name)] = {"start": start_cells, "path": path_cells}


## A platform moves (and can carry knights along its path) only if it runs on its own or its
## PlatformController's input can be activated; otherwise only its start position holds.
func _rebuild_platforms(area: Dictionary, with_bosses: bool) -> void:
	platforms.clear()
	for name: String in _platform_paths:
		var key := "path"
		if _platform_control.has(name) and not source_reachable(_platform_control[name], area, with_bosses):
			key = "start"
		for cell: Vector2i in _platform_paths[name][key]:
			platforms[cell] = name


static func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / T)), int(floor(pos.y / T)))


func _mark_rect(cells: Dictionary, rect: Rect2, on: bool) -> void:
	for y in range(int(floor(rect.position.y / T)), int(ceil(rect.end.y / T))):
		for x in range(int(floor(rect.position.x / T)), int(ceil(rect.end.x / T))):
			cells[Vector2i(x, y)] = on


# --- Movement --------------------------------------------------------------------------------

func _blocked(cell: Vector2i) -> bool:
	return solid.has(cell) or (gate_cells.has(cell) and not open_gates.has(gate_cells[cell]))


func _support(cell: Vector2i) -> bool:
	return solid.has(cell) or one_way.has(cell) or platforms.has(cell) or _blocked(cell)


func standable(c: Vector2i) -> bool:
	if c.x < 0 or c.x >= width or c.y < 1 or c.y > height:
		return false
	for body in [c + Vector2i(0, -1), c + Vector2i(0, -2)]:
		if _blocked(body) or hazard.has(body):
			return false
	if ladders.has(c) or ladders.has(c + Vector2i(0, -1)):
		return true
	return _support(c) and not hazard.has(c + Vector2i(0, -1))


func _air(c: Vector2i) -> bool:
	return not _blocked(c)


## Where a knight leaving column x at row r (feet) lands, falling straight down.
func _land(x: int, r: int) -> Vector2i:
	for rr in range(r, height + 1):
		var c := Vector2i(x, rr)
		if not _air(c + Vector2i(0, -1)):
			return Vector2i(-1, -1)
		if hazard.has(c + Vector2i(0, -1)):
			return Vector2i(-1, -1)
		if ladders.has(c):
			return c
		if _support(c) and standable(c):
			return c
	return FELL_OUT  # falls out of the level (a fall respawns the knight at a safe place)


## Whether a knight standing at `c` can fall out of the level (walking off an edge or
## dropping through a one-way tile): the fall rule then puts it back on safe ground, so a
## place like that can never trap it.
func can_fall_out(c: Vector2i) -> bool:
	for dx in [-1, 1]:
		var side := c + Vector2i(dx, 0)
		if not standable(side) and _air(side + Vector2i(0, -1)) and _air(side + Vector2i(0, -2)) and _land(side.x, c.y) == FELL_OUT:
			return true
	if (one_way.has(c) or platforms.has(c)) and not solid.has(c) and _land(c.x, c.y + 1) == FELL_OUT:
		return true
	return false


## Places reachable from the spawn from which the exit can never be reached again and that
## a knight cannot leave by falling out of the level (traps). Gates count as open.
func trap_cells(area: Dictionary) -> Array[Vector2i]:
	var exits := {}
	var queue: Array[Vector2i] = []
	# Reverse search: every place from which the exit (or a fall-out escape) is reachable.
	var good := {}
	for c: Vector2i in area:
		if exit_cells.has(c) or can_fall_out(c):
			good[c] = true
			queue.append(c)
	var reverse := {}
	for c: Vector2i in area:
		for n: Vector2i in neighbours(c):
			if not reverse.has(n):
				reverse[n] = []
			(reverse[n] as Array).append(c)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for p: Vector2i in reverse.get(c, []):
			if not good.has(p):
				good[p] = true
				queue.append(p)
	var traps: Array[Vector2i] = []
	for c: Vector2i in area:
		if not good.has(c):
			traps.append(c)
	return traps


func neighbours(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in [-1, 1]:
		var side := c + Vector2i(dx, 0)
		if standable(side):
			out.append(side)
		elif _air(side + Vector2i(0, -1)) and _air(side + Vector2i(0, -2)):
			var landing := _land(side.x, c.y)
			if landing.x >= 0:
				out.append(landing)
	# Ladders.
	for dy in [-1, 1]:
		var v := c + Vector2i(0, dy)
		if (ladders.has(c) or ladders.has(c + Vector2i(0, -1))) and (ladders.has(v) or ladders.has(v + Vector2i(0, -1))) and standable(v):
			out.append(v)
	# Drop through a one-way tile (or a platform).
	if (one_way.has(c) or platforms.has(c)) and not solid.has(c):
		var below := _land(c.x, c.y + 1)
		if below.x >= 0:
			out.append(below)
	# Jumps.
	for up in range(-8, 4):
		var max_dx: int = MAX_DX.get(up, 0) if up >= 0 else mini(4 + (-up) / 2, 6)
		for dx in range(-max_dx, max_dx + 1):
			if dx == 0 and up <= 0:
				continue
			var to := Vector2i(c.x + dx, c.y - up)
			if to == c or not standable(to):
				continue
			if _jump_clear(c, to, up):
				out.append(to)
	return out


## Headroom above the take-off (body plus the rise), then the whole arc: for every column
## crossed, the knight's two body cells at the arc's height there must be free. The arc is the
## LOWEST one a player can choose (a short hop reaching the landing): the straight line from
## take-off to landing lifted by about one row in the middle. So a jump can never pass
## through a solid ceiling or slab on its way down, and a low ceiling only rules out jumps
## that really hit it. Hazards under the arc do not matter (jumping over spikes is fine).
func _jump_clear(from: Vector2i, to: Vector2i, up: int) -> bool:
	for k in range(1, maxi(up, 0) + 3):
		if _blocked(from + Vector2i(0, -k)):
			return false
	var hump := 1.0 if up >= 0 else 0.75
	var span := absi(to.x - from.x)
	var step := 1 if to.x > from.x else -1
	for i in range(1, span):
		var s := float(i) / float(span)
		var feet := lerpf(float(from.y), float(to.y), s) - hump * 4.0 * s * (1.0 - s)
		var x := from.x + i * step
		var lowest := int(ceil(feet)) - 1
		var highest := int(floor(feet)) - 2
		for r in range(highest, lowest + 1):
			if _blocked(Vector2i(x, r)):
				return false
	return true


func reachable_from(starts: Array[Vector2i]) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = []
	for s in starts:
		if standable(s) and not seen.has(s):
			seen[s] = true
			queue.append(s)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for n in neighbours(c):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


# --- Puzzles ---------------------------------------------------------------------------------

func source_reachable(node: Node, area: Dictionary, with_bosses: bool) -> bool:
	if node is BossSeal:
		return with_bosses and _boss_reachable(node, area)
	if node is PuzzleGate:
		return open_gates.has(node)
	if node is PuzzleLogic:
		var logic := node as PuzzleLogic
		var results: Array[bool] = []
		for path in logic.inputs:
			var input := logic.get_node_or_null(path)
			results.append(input != null and source_reachable(input, area, with_bosses))
		if results.is_empty():
			return false
		return results.has(true) if logic.mode == PuzzleLogic.Mode.ANY else not results.has(false)
	if node is TriggerZone:
		var z := node as TriggerZone
		for c: Vector2i in area:
			if Rect2(z.position, z.size).has_point(Vector2(c.x * T + 8, c.y * T - 8)):
				return true
		return false
	if node is PressurePlate:
		var p := node as PressurePlate
		var r := int(p.position.y / T)
		for dx in range(int(ceil(p.width / T))):
			if area.has(Vector2i(int(p.position.x / T) + dx, r)):
				return true
		return false
	if node is AttackSwitch:
		var s := node as AttackSwitch
		var sc := _cell_of(s.position + Vector2(0, 22))
		for dx in range(-2, 3):
			for dr in range(-1, 3):
				if area.has(sc + Vector2i(dx, dr)):
					return true
		return false
	return false


func _boss_reachable(seal: Node, area: Dictionary) -> bool:
	for node in level.find_children("*", "", true, false):
		if node is BossSlime and node.get_node_or_null((node as BossSlime).seal) == seal:
			var c := _cell_of((node as Node2D).position)
			for dx in range(-3, 4):
				if area.has(c + Vector2i(dx, 0)):
					return true
	return false


## Staged analysis. Returns the final reachable area.
func analyze(with_bosses := false) -> Dictionary:
	open_gates.clear()
	for g: Node in gates:
		if (g as PuzzleGate).start_open:
			open_gates[g] = true
	reach = {}
	while true:
		# Platforms whose controllers become reachable extend the area, which can reach more
		# controllers (lift relays): repeat until the area stops growing.
		var size := -1
		while reach.size() != size:
			size = reach.size()
			_rebuild_platforms(reach, with_bosses)
			reach = reachable_from(spawn)
		var changed := false
		for g: Node in gates:
			if open_gates.has(g):
				continue
			var controller := g.get_node_or_null((g as PuzzleGate).controller)
			if controller != null and source_reachable(controller, reach, with_bosses):
				open_gates[g] = true
				changed = true
		if not changed:
			break
	return reach


func exit_reachable(area: Dictionary) -> bool:
	for c in exit_cells:
		if area.has(c):
			return true
	return false


## Collectibles, switches, plates and save points the knights cannot reach.
func unreachable_things(area: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for node in level.find_children("*", "", true, false):
		var c := Vector2i(-1, -1)
		if node is Collectible:
			c = _cell_of((node as Node2D).position)
		elif node is SavePoint:
			c = _cell_of((node as Node2D).position)
		else:
			continue
		var ok := false
		for dx in range(-1, 2):
			for dr in range(0, 2):
				if area.has(c + Vector2i(dx, dr)):
					ok = true
		if not ok:
			out.append("%s at tile %s" % [node.name, c])
	for name: String in sources:
		var s: Node = sources[name]
		if (s is PressurePlate or s is AttackSwitch) and not source_reachable(s, area, false):
			out.append("%s (puzzle input) unreachable" % name)
	return out


## Logic locks that need more simultaneous HOLD inputs than there are knights.
func impossible_locks() -> PackedStringArray:
	var out := PackedStringArray()
	for name: String in sources:
		var logic := sources[name] as PuzzleLogic
		if logic == null or logic.mode == PuzzleLogic.Mode.ANY:
			continue
		var held := 0
		for path in logic.inputs:
			var input := logic.get_node_or_null(path)
			if input is PressurePlate and (input as PressurePlate).mode == PressurePlate.Mode.HOLD:
				held += (input as PressurePlate).required_count
		if held > 2:
			out.append("%s needs %d knights holding at once" % [name, held])
	return out
