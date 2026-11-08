class_name RouteValidator
extends RefCounted
## Replays every jump of a level's main route (the level analyzer's shortest route from the
## spawn to the exit, with all non-boss gates open) with the real knight, real input and real
## physics, to prove each one can actually be made with the base movement values.
##
## The route prefers walking and short hops (a player would not leap four tiles along flat
## ground). For each jump the knight is placed on the take-off cell and tries what a player
## would: a run-up jump, a standing jump, a jump that goes up first and then sideways, and
## walking off the edge, always steering in the air toward the landing like a player does.
## A jump passes when the knight lands on the target's row within one column. A jump the
## knight cannot make is banned and the route is planned again around it: the level fails
## only when no route to the exit is left that the knight can actually make. The banned jumps
## are reported (they are places where the static analyzer is too optimistic).
## Walking steps, ladders and drops through one-way tiles are not replayed (they are checked
## by LevelProbe). Moving platforms are skipped (their position depends on time); blinking
## and timed platforms are waited for until freshly solid; crumbling ones are replayed.
## Enemies, gates, lava and the fall boundary are removed from the copy of the level, and the
## knight is invulnerable, so a failed attempt never ends the run of the check.

const Analyzer := preload("res://tools/level_analyzer.gd")
const T := 16.0

var host: Node
var level: Node2D
var analyzer
var knight: Knight
var report := {"jumps": 0, "passed": 0, "skipped_moving": 0, "failed": [], "banned": [], "route_ok": false}
var _verified := {}
var _banned := {}


func _init(test_host: Node) -> void:
	host = test_host


func _frames(n: int) -> void:
	for i in n:
		await host.get_tree().physics_frame


func validate(level_id: String) -> Dictionary:
	level = (load(LevelCatalog.scene_for(level_id)) as PackedScene).instantiate()
	level.set_meta(&"level_id", level_id)
	var remove: Array[Node] = []
	for node in level.find_children("*", "", true, false):
		if node is Slime or node is BossSlime or node is PuzzleGate or node is Enemy:
			remove.append(node)
		elif node is SawBlade or node is FireJet or node is FallingRock or node is BreakableBlock:
			remove.append(node)  # damage and cracked blocks are not routing questions
		elif node is Hazard and ((node as Hazard).kind == Hazard.Kind.LAVA or (node as Hazard).kind == Hazard.Kind.FALL):
			remove.append(node)
	for node in remove:
		node.get_parent().remove_child(node)
		node.free()
	host.add_child(level)
	await _frames(3)
	knight = level.get_node("Knights/Knight1") as Knight
	var other := level.get_node("Knights/Knight2") as Knight
	other.set_physics_process(false)
	other.global_position = Vector2(-2000, -2000)
	analyzer = Analyzer.new(_analysis_copy(level_id))
	for gate in analyzer.gates:
		analyzer.open_gates[gate] = true
	analyzer._platform_control.clear()
	analyzer._rebuild_platforms({}, false)
	analyzer.lanterns.clear()  # pogo bounces are a skill route, never the main route
	for attempt in 40:
		var path := _route()
		if path.is_empty():
			report.failed.append("no route from spawn to exit made only of jumps the knight can make")
			break
		var blocked := false
		for i in range(1, path.size()):
			if not await _edge(path[i - 1], path[i]):
				_banned[[path[i - 1], path[i]]] = true
				report.banned.append("%s -> %s" % [path[i - 1], path[i]])
				blocked = true
				break
		if not blocked:
			report.route_ok = true
			break
	knight.health.clear_invulnerability()
	_release()
	level.queue_free()
	# The analysis copy never enters the tree, so nothing else frees it.
	analyzer.level.free()
	await _frames(2)
	return report


## The analyzer reads a fresh, untouched copy (it needs the gates and platforms as built).
func _analysis_copy(level_id: String) -> Node:
	return (load(LevelCatalog.scene_for(level_id)) as PackedScene).instantiate()


## Cheapest route (Dijkstra): a walking step costs 1, a jump 2 + half its squared length, so
## walking and short hops are preferred, as a player would. Banned jumps are left out.
func _route() -> Array[Vector2i]:
	var start: Vector2i = analyzer.spawn[0]
	var parent := {start: start}
	var cost := {start: 0.0}
	var open: Array[Vector2i] = [start]
	var goal := Vector2i(-1, -1)
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if cost[open[i]] < cost[open[best]]:
				best = i
		var c: Vector2i = open[best]
		open.remove_at(best)
		if analyzer.exit_cells.has(c):
			goal = c
			break
		for n: Vector2i in analyzer.neighbours(c):
			if _banned.has([c, n]):
				continue
			var d := n - c
			var step := 1.0 if absi(d.x) <= 1 and d.y == 0 else 2.0 + 0.5 * float(d.x * d.x + maxi(-d.y, 0) * maxi(-d.y, 0))
			var total: float = cost[c] + step
			if not cost.has(n) or total < cost[n]:
				cost[n] = total
				parent[n] = c
				if not open.has(n):
					open.append(n)
	var path: Array[Vector2i] = []
	if goal.x < 0:
		return path
	var c := goal
	while c != start:
		path.push_front(c)
		c = parent[c]
	path.push_front(start)
	return path


func _platform_at(cell: Vector2i) -> PlatformBody:
	var name: String = analyzer.platforms.get(cell, "")
	if name == "":
		return null
	for node in level.find_children(name, "", true, false):
		if node is PlatformBody:
			return node
	return null


## True when the move can be made (or is not a jump to replay).
func _edge(a: Vector2i, b: Vector2i) -> bool:
	var dx := b.x - a.x
	var up := a.y - b.y
	var on_ladder: bool = analyzer.ladders.has(a) or analyzer.ladders.has(b) or analyzer.ladders.has(a + Vector2i(0, -1))
	if (absi(dx) <= 1 and up == 0) or (dx == 0 and up < 0) or on_ladder:
		return true  # a step, a drop or a ladder
	if _verified.has([a, b]):
		return true
	var from_platform := _platform_at(a)
	var to_platform := _platform_at(b)
	if from_platform is MovingPlatform or to_platform is MovingPlatform:
		report.skipped_moving += 1
		_verified[[a, b]] = true
		return true
	report.jumps += 1
	var techniques := ["run_up", "standing", "short_hop", "up_first", "walk_off"]
	if _in_updraft(a):
		techniques.push_front("float")
	for technique in techniques:
		if technique == "walk_off" and up > 0:
			continue
		if await _attempt(a, b, technique, to_platform):
			report.passed += 1
			_verified[[a, b]] = true
			return true
	return false


func _attempt(a: Vector2i, b: Vector2i, technique: String, target: PlatformBody) -> bool:
	_release()
	var dir := 1 if b.x > a.x else (-1 if b.x < a.x else 0)
	var dir_action: StringName = knight.profile.action_right if dir >= 0 else knight.profile.action_left
	var start := Vector2(a.x * T + 8, a.y * T)
	if technique == "run_up" and dir != 0:
		# Up to two cells of run-up behind the take-off cell, if the floor allows.
		for back in [2, 1]:
			var c: Vector2i = a - Vector2i(dir * back, 0)
			if analyzer.standable(c) and analyzer.standable(a - Vector2i(dir, 0)):
				start = Vector2(c.x * T + 8, c.y * T)
				break
	if target is TimedPlatform:
		await _wait_fresh(target as TimedPlatform)
	knight.teleport_to(start)
	knight.health.start_invulnerability(9999.0)
	await _frames(4)
	var take_off_x := a.x * T + 8 + dir * 5.0
	var jumped := false
	var left_ground := false
	match technique:
		"standing":
			Input.action_press(knight.profile.action_up)
			if dir != 0:
				Input.action_press(dir_action)
			jumped = true
		"up_first", "float":
			Input.action_press(knight.profile.action_up)
			jumped = true
		"short_hop":
			# A low jump: the jump key is released early (jump cut), staying under ledges.
			Input.action_press(knight.profile.action_up)
			if dir != 0:
				Input.action_press(dir_action)
			jumped = true
		_:
			if dir != 0:
				Input.action_press(dir_action)
	var target_x := b.x * T + 8
	for f in 150:
		await _frames(1)
		if technique == "up_first" and f == 7 and dir != 0:
			Input.action_press(dir_action)
		if technique == "short_hop" and f == 4:
			Input.action_release(knight.profile.action_up)
		if technique == "run_up" and not jumped and (knight.global_position.x - take_off_x) * dir >= 0.0:
			Input.action_press(knight.profile.action_up)
			jumped = true
		if not knight.is_on_floor():
			left_ground = true
		# In the air a player steers toward the landing: keep going, ease off, or turn back.
		# Floating in an updraft: rise past the landing first, then steer off the column.
		var floating := technique == "float" and knight.global_position.y > b.y * T - 10.0
		if left_ground and not knight.is_on_floor() and not (technique == "up_first" and f < 7) and not floating:
			var off := target_x - knight.global_position.x
			Input.action_release(knight.profile.action_left)
			Input.action_release(knight.profile.action_right)
			if absf(off) > 3.0:
				Input.action_press(knight.profile.action_right if off > 0.0 else knight.profile.action_left)
		if left_ground and knight.is_on_floor():
			break
		if knight.global_position.y > (analyzer.height + 2) * T:
			break
	_release()
	await _frames(2)
	var cell := Vector2i(int(floor(knight.global_position.x / T)), int(round(knight.global_position.y / T)))
	return knight.is_on_floor() and cell.y == b.y and absi(cell.x - b.x) <= 1


func _in_updraft(c: Vector2i) -> bool:
	for zone: Rect2i in analyzer.updrafts:
		if c.x >= zone.position.x and c.x < zone.end.x and c.y >= zone.position.y and c.y <= zone.end.y + 3:
			return true
	return false


## Waits until a timed or blinking platform has just become solid.
func _wait_fresh(platform: TimedPlatform) -> void:
	for f in 600:
		if platform.state == TimedPlatform.State.ACTIVE and platform.time_in_state < 0.1:
			return
		if platform.mode == TimedPlatform.Mode.TRIGGERED and platform.state == TimedPlatform.State.INACTIVE:
			platform.activate()
		await _frames(1)


func _release() -> void:
	for action in knight.profile.actions():
		Input.action_release(action)
