extends GameTestCase
## Fairness of timed and blinking platform chains (Phase 11, Part E3/E6). Each level's
## schedule-driven platforms are run by their real code for 30 s; the recorded timelines then
## answer: can a knight starting from safe ground cross the whole chain, landing only on a
## solid platform, with a realistic hop time and a reaction margin? A chain with no safe
## timing at all would force a death (over lava, a run-ending one): an unfair design.

const HOP := 0.55            # seconds a hop of up to four tiles takes
const LAND_MARGIN := 0.3     # the landing platform must stay solid this long after landing
const REACTION := 0.25       # a player needs at least this long on a platform before hopping
const STEP := 1.0 / 60.0
const SECONDS := 30.0

static var report := {}


func _timelines(level: Node) -> Dictionary:
	var platforms: Array = level.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n is TimedPlatform and (n as TimedPlatform).mode == TimedPlatform.Mode.SCHEDULE)
	var lines := {}
	# Plain Arrays: a PackedByteArray taken out of a Dictionary is a copy, so appending to it
	# would never reach the stored timeline.
	for p: TimedPlatform in platforms:
		lines[p] = []
	for f in int(SECONDS / STEP):
		await get_tree().physics_frame
		for p: TimedPlatform in platforms:
			(lines[p] as Array).append(1 if p.collision_enabled() else 0)
	return lines


## Platforms closer than seven tiles form a chain, ordered the way the knights travel: by
## their distance along the level from the spawn (the analyzer's route, gates open).
func _chains(lines: Dictionary, depth: Dictionary) -> Array:
	var sorted: Array = lines.keys()
	sorted.sort_custom(func(a: Node2D, b: Node2D) -> bool: return depth.get(a, 0) < depth.get(b, 0))
	var chains: Array = []
	var current: Array = []
	for p: TimedPlatform in sorted:
		if current.is_empty() or p.global_position.distance_to((current.back() as TimedPlatform).global_position) <= 7 * 16:
			current.append(p)
		else:
			chains.append(current)
			current = [p]
	if not current.is_empty():
		chains.append(current)
	return chains


func _solid(line: Array, from: float, to: float) -> bool:
	for i in range(int(from / STEP), mini(int(to / STEP) + 1, line.size())):
		if line[i] == 0:
			return false
	return to / STEP < line.size()


## Earliest-arrival search over the timeline: from safe ground, hop onto each platform in turn.
## Returns the largest waiting time the knight ever has before it must leave (slack), or -1
## when the chain cannot be crossed at all.
func _crossable(chain: Array, lines: Dictionary) -> float:
	var best := -1.0
	for start_frame in range(0, int(12.0 / STEP), 6):
		var t := start_frame * STEP
		var ok := true
		var min_slack := INF
		for i in chain.size():
			var line: Array = lines[chain[i]]
			# Leave the previous place (ground or platform) at the first moment the landing is safe.
			var depart := t
			var found := false
			while depart < SECONDS - 3.0:
				if _solid(line, depart + HOP, depart + HOP + LAND_MARGIN):
					found = true
					break
				if i > 0 and not _solid(lines[chain[i - 1]], depart, depart + STEP):
					break  # the platform under the knight vanished while it waited
				depart += STEP
			if not found:
				ok = false
				break
			t = depart + HOP
			# How long it may stay on this platform before it vanishes.
			var stay := 0.0
			while _solid(line, t + stay, t + stay + STEP) and stay < 10.0:
				stay += STEP
			min_slack = minf(min_slack, stay)
			if stay < REACTION:
				ok = false
				break
		if ok:
			best = maxf(best, min_slack)
	return best


## Steps from the spawn to each platform along the level (BFS over the analyzer's moves).
func _route_depth(id: String, lines: Dictionary) -> Dictionary:
	var a = preload("res://tools/level_analyzer.gd").new((load(LevelCatalog.scene_for(id)) as PackedScene).instantiate())
	for g in a.gates:
		a.open_gates[g] = true
	a._platform_control.clear()
	a._rebuild_platforms({}, false)
	var dist := {a.spawn[0]: 0}
	var queue: Array[Vector2i] = [a.spawn[0]]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n: Vector2i in a.neighbours(c):
			if not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	var depth := {}
	for p: TimedPlatform in lines:
		var cell := Vector2i(int(p.global_position.x / 16.0), int(p.global_position.y / 16.0))
		var best := 1 << 30
		for dx in p.width_tiles:
			best = mini(best, dist.get(cell + Vector2i(dx, 0), 1 << 30))
		depth[p] = best
	a.level.free()
	return depth


func test_every_timed_chain_can_be_crossed() -> void:
	for id in LevelCatalog.all_levels():
		var level := (load(LevelCatalog.scene_for(id)) as PackedScene).instantiate()
		for k in level.find_children("*", "", true, false):
			if k is Knight or k is Slime or k is BossSlime:
				k.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(level)
		var lines: Dictionary = await _timelines(level)
		var chains := _chains(lines, _route_depth(id, lines))
		var results := []
		for chain: Array in chains:
			var slack := _crossable(chain, lines)
			var names := chain.map(func(p: Node) -> String: return String(p.name))
			results.append({"platforms": names, "slack": snappedf(slack, 0.01)})
			assert_true(slack >= REACTION, "%s: chain %s can be crossed with a reaction time (slack %.2f s)" % [id, names, slack])
		if not results.is_empty():
			report[id] = results
		level.queue_free()
		await get_tree().physics_frame
	var f := FileAccess.open("user://platform_timing_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
