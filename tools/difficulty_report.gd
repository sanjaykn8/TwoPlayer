extends SceneTree
## Evidence for the difficulty review (Phase 11): per level, what the main route actually asks
## of the knights, counted from the built scenes with the level analyzer. Writes
## user://difficulty_report.md (the release report quotes it).
##   godot --headless --path . --script res://tools/difficulty_report.gd

const Analyzer := preload("res://tools/level_analyzer.gd")


func _initialize() -> void:
	var lines := PackedStringArray([
		"| Level | Diff. | Route jumps | At the limit | Over lava | Over spikes | Platform hops | Lava-crossing stones | Enemies near route (green/purple/other) | Arena fights | Two-knight locks | Gates without a clue nearby |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for id in LevelCatalog.all_levels():
		var root := (load(LevelCatalog.scene_for(id)) as PackedScene).instantiate()
		var a = Analyzer.new(root)
		for g: Node in a.gates:
			a.open_gates[g] = true
		a._platform_control.clear()
		a._rebuild_platforms({}, false)
		var path := _route(a)
		var jumps := 0
		var limit := 0
		var over_lava := 0
		var over_spikes := 0
		var platform_hops := 0
		var lava_cells := {}
		var spike_cells := {}
		var route_cells := {}
		for node in root.find_children("*", "", true, false):
			if node is Hazard:
				var h := node as Hazard
				var target: Dictionary = lava_cells if h.kind == Hazard.Kind.LAVA else (spike_cells if h.kind == Hazard.Kind.SPIKES else {})
				for y in range(int(h.position.y / 16), int(ceil((h.position.y + h.size.y) / 16))):
					for x in range(int(h.position.x / 16), int(ceil((h.position.x + h.size.x) / 16))):
						target[Vector2i(x, y)] = true
		for i in range(1, path.size()):
			var p: Vector2i = path[i - 1]
			var c: Vector2i = path[i]
			route_cells[c] = true
			var dx := absi(c.x - p.x)
			var up := p.y - c.y
			if (dx <= 1 and up == 0) or (dx == 0 and up < 0) or a.ladders.has(c) or a.ladders.has(p):
				continue
			jumps += 1
			if (up == 3 and dx == 2) or (up == 2 and dx == 3) or (up <= 1 and up >= 0 and dx == 4):
				limit += 1
			if a.platforms.has(c) or a.platforms.has(p):
				platform_hops += 1
			var lo := mini(p.x, c.x)
			var hi := maxi(p.x, c.x)
			var below_lava := false
			var below_spikes := false
			# What a knight missing this jump would fall into: scan each column under the arc
			# down to the first solid ground or platform.
			for x in range(lo, hi + 1):
				for y in range(mini(p.y, c.y), a.height + 1):
					var cell := Vector2i(x, y)
					if lava_cells.has(cell):
						below_lava = true
						break
					if spike_cells.has(cell):
						below_spikes = true
						break
					if a.solid.has(cell) or (a.platforms.has(cell) and x != c.x and x != p.x):
						break
			over_lava += 1 if below_lava else 0
			over_spikes += 1 if below_spikes else 0
		var stones := 0
		var g_near := 0
		var p_near := 0
		var o_near := 0
		var fights := 0
		var two_knight := 0
		var unclued := 0
		var clues: Array = []
		for node in root.find_children("*", "", true, false):
			if node is PuzzleClue:
				clues.append((node as Node2D).position)
		for node in root.find_children("*", "", true, false):
			if (node is CollapsingPlatform or node is TimedPlatform) and _over(node as PlatformBody, lava_cells):
				stones += 1
			elif node is EncounterZone:
				fights += 1
			elif node is Enemy:
				var ec := Vector2i(int(node.position.x / 16), int(node.position.y / 16))
				var close := false
				for dx in range(-4, 5):
					for dy in range(-6, 3):
						close = close or route_cells.has(ec + Vector2i(dx, dy))
				o_near += 1 if close else 0
			elif node is Slime:
				var sc := Vector2i(int(node.position.x / 16), int(node.position.y / 16))
				var near := false
				for dx in range(-4, 5):
					for dy in range(-2, 3):
						near = near or route_cells.has(sc + Vector2i(dx, dy))
				if near:
					if (node as Slime).stats.stagger_threshold <= 2:
						g_near += 1
					else:
						p_near += 1
			elif node is PuzzleLogic:
				var logic := node as PuzzleLogic
				if logic.distinct_players or logic.mode == PuzzleLogic.Mode.SYNC:
					two_knight += 1
			elif node is PressurePlate and (node as PressurePlate).required_count == 2:
				two_knight += 1
			elif node is PuzzleGate:
				var gp := (node as Node2D).position
				var clued := false
				for cp: Vector2 in clues:
					clued = clued or cp.distance_to(gp) <= 24 * 16
				if not clued and not (node.get_node_or_null((node as PuzzleGate).controller) is BossSeal):
					unclued += 1
		lines.append("| %s %s | %d | %d | %d | %d | %d | %d | %d | %d/%d/%d | %d | %d | %d |" % [id, LevelCatalog.level_title(id),
			LevelCatalog.level(id).difficulty, jumps, limit, over_lava, over_spikes, platform_hops, stones, g_near, p_near, o_near, fights, two_knight, unclued])
		root.free()
	var f := FileAccess.open("user://difficulty_report.md", FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	quit()


func _over(p: PlatformBody, lava: Dictionary) -> bool:
	var c := Vector2i(int(p.position.x / 16), int(p.position.y / 16))
	for dx in p.width_tiles:
		for dy in range(1, 30):
			if lava.has(c + Vector2i(dx, dy)):
				return true
	return false


## Cheapest route (walking and short hops preferred), as in RouteValidator.
func _route(a) -> Array[Vector2i]:
	var start: Vector2i = a.spawn[0]
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
		if a.exit_cells.has(c):
			goal = c
			break
		for n: Vector2i in a.neighbours(c):
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
