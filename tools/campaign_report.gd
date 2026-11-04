extends SceneTree
## Writes docs/CAMPAIGN_PLAN.md and docs/CAMPAIGN_PLAYTEST.md from the real campaign: the
## registry, the built level scenes, the level specs' design notes and the level analyzer.
## Numbers in the plan are counted from the scenes, not typed by hand.
## Run after build_phase10_content.gd:
##   godot --headless --path . --script res://tools/campaign_report.gd

const Analyzer := preload("res://tools/level_analyzer.gd")
const WORLD_SCRIPTS := ["res://tools/campaign/world_1.gd", "res://tools/campaign/world_2.gd", "res://tools/campaign/world_3.gd",
	"res://tools/campaign/world_4.gd", "res://tools/campaign/world_5.gd", "res://tools/campaign/world_6.gd"]
const RUN_SPEED := 110.0
const FRUIT := ["green", "yellow", "red", "purple"]
const JAR := ["green", "red", "yellow", "blue"]


func _initialize() -> void:
	var notes := _design_notes()
	var plan := PackedStringArray()
	var test := PackedStringArray()
	plan.append(_plan_header())
	test.append(_test_header())
	var total_est := 0.0
	var total_min := 0.0
	for world_id in LevelCatalog.world_ids():
		var world := LevelCatalog.world(world_id)
		plan.append("\n## %s (`%s`)\n" % [world.title, world_id])
		test.append("\n## %s\n" % world.title)
		for def in world.levels:
			var info := _inspect(def)
			total_est += def.estimated_minutes
			total_min += info.min_seconds / 60.0
			plan.append(_plan_level(def, info, notes.get(def.id, "")))
			test.append(_test_level(def, info, notes.get(def.id, "")))
	plan.append(_plan_footer(total_est, total_min))
	_write("res://docs/CAMPAIGN_PLAN.md", "".join(plan))
	_write("res://docs/CAMPAIGN_PLAYTEST.md", "".join(test))
	quit()


## The "## ..." comment block above each `static func lNN()` in the world scripts.
func _design_notes() -> Dictionary:
	var notes := {}
	for path: String in WORLD_SCRIPTS:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var block := PackedStringArray()
		for line in lines:
			if line.begins_with("## "):
				block.append(line.substr(3))
			elif line.begins_with("static func l") and block.size() > 0:
				notes[line.substr(12, 3)] = " ".join(block)
				block.clear()
			elif not line.begins_with("##"):
				block.clear()
	return notes


func _inspect(def: LevelDefinition) -> Dictionary:
	var root := (load(def.scene_path) as PackedScene).instantiate()
	var info := {"green": [], "purple": [], "spikes": 0, "lava": 0, "hot": 0, "platforms": {}, "puzzles": {},
		"items": [], "ladders": 0, "saves": 0, "boss": "", "clues": [], "gates": 0}
	for node in root.find_children("*", "", true, false):
		var at := Vector2i((node as Node2D).position / 16.0) if node is Node2D else Vector2i.ZERO
		if node is Slime:
			info["green" if (node as Slime).stats.stagger_threshold <= 2 else "purple"].append(at.x)
		elif node is BossSlime:
			info.boss = (node as BossSlime).stats.display_name
		elif node is Hazard:
			var h := node as Hazard
			var tiles := int(h.size.x / 16.0)
			match h.kind:
				Hazard.Kind.SPIKES: info.spikes += tiles
				Hazard.Kind.LAVA: info.lava += tiles
				Hazard.Kind.HOT_GROUND: info.hot += tiles
		elif node is PlatformBody:
			var kind := String(node.get_script().get_global_name())
			info.platforms[kind] = int(info.platforms.get(kind, 0)) + 1
		elif node is PuzzleGate:
			info.gates += 1
		elif node is PuzzleLogic:
			var mode: String = ["ALL", "ANY", "SYNC", "SEQUENCE"][(node as PuzzleLogic).mode]
			info.puzzles[mode] = int(info.puzzles.get(mode, 0)) + 1
		elif node is PressurePlate or node is AttackSwitch:
			var kind := "plate" if node is PressurePlate else "switch/target"
			info.puzzles[kind] = int(info.puzzles.get(kind, 0)) + 1
		elif node is Fruit:
			info.items.append("%s fruit (tier %d) at x %d" % [FRUIT[(node as Fruit).fruit_type], (node as Fruit).tier, at.x])
		elif node is Jar:
			info.items.append("%s jar at x %d" % [JAR[(node as Jar).jar_type], at.x])
		elif node is CoinStash:
			info.items.append("%d coins at x %d" % [(node as CoinStash).amount, at.x])
		elif node is PowerTile:
			info.items.append("power tile at x %d" % at.x)
		elif node is Climbable:
			info.ladders += 1
		elif node is SavePoint:
			info.saves += 1
		elif node is PuzzleClue:
			info.clues.append(String((node as PuzzleClue).text).replace("\n", " "))
	var a = Analyzer.new(root)
	var area: Dictionary = a.analyze(false)
	info.exit_ok = a.exit_reachable(area)
	info.min_seconds = _route_seconds(a)
	var with_boss: Dictionary = a.analyze(true)
	info.all_ok = a.unreachable_things(with_boss).is_empty()
	info.size = Vector2i(def.camera_bounds.size / 16.0)
	root.free()
	return info


## Shortest movement route spawn -> exit (all non-boss gates opened), in seconds at running
## speed: a lower bound with no combat, waiting or puzzle time.
func _route_seconds(a) -> float:
	var start: Vector2i = a.spawn[0]
	var parent := {start: start}
	var queue: Array[Vector2i] = [start]
	var goal := Vector2i(-1, -1)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if a.exit_cells.has(c):
			goal = c
			break
		for n: Vector2i in a.neighbours(c):
			if not parent.has(n):
				parent[n] = c
				queue.append(n)
	if goal.x < 0:
		return 0.0
	var tiles := 0.0
	var c := goal
	while c != start:
		var p: Vector2i = parent[c]
		tiles += maxf(absf(c.x - p.x), absf(c.y - p.y) * 0.6)
		c = p
	return tiles * 16.0 / RUN_SPEED


func _plan_header() -> String:
	return """# Campaign Plan

Generated by `tools/campaign_report.gd` from the built campaign (registry
`resources/campaign/production_campaign.tres`, scenes `scenes/worlds/`, design notes in
`tools/campaign/world_*.gd`). Counts and positions are read from the scenes. **Estimated
minutes are design estimates for a successful two-player first play; they are not measured.**
"Minimum movement" is the analyzer's shortest walk/jump route from spawn to exit at running
speed, with no combat, puzzles or waiting, so real times are always longer.

Positions are tile columns (16 px). Rules every level follows: either living knight completes
it at the exit (`completion: exit`); both knights move on together with their health, upgrades
and the shared coins; optional content (collectibles, bosses) is never needed for the exit.

"""


func _plan_level(def: LevelDefinition, info: Dictionary, note: String) -> String:
	var platforms := PackedStringArray()
	for k: String in info.platforms:
		platforms.append("%d %s" % [info.platforms[k], k])
	var puzzles := PackedStringArray()
	for k: String in info.puzzles:
		puzzles.append("%d %s" % [info.puzzles[k], k])
	var lines := PackedStringArray([
		"### %d. %s — %s (`%s`)\n" % [def.order, LevelCatalog.world_title(def.world_id), def.title, def.id],
		"| Field | Value |", "|---|---|",
		"| World / theme | %s / %s |" % [def.world_id, def.theme],
		"| Difficulty | %d / 10 |" % def.difficulty,
		"| Estimated first play | %.1f min (estimate) |" % def.estimated_minutes,
		"| Minimum movement | %.0f s (analyzer lower bound) |" % info.min_seconds,
		"| Size | %d x %d tiles |" % [info.size.x, info.size.y],
		"| Spawns | P1 %s, P2 %s (px) |" % [def.spawn_p1, def.spawn_p2],
		"| Main route and puzzles | %s |" % note,
		"| Enemies | %d green at x %s; %d purple at x %s%s |" % [info.green.size(), info.green, info.purple.size(), info.purple,
			("; optional boss: " + info.boss) if info.boss != "" else ""],
		"| Hazards | spikes %d tiles, lava %d tiles, hot ground %d tiles |" % [info.spikes, info.lava, info.hot],
		"| Platforms | %s; %d ladders |" % [", ".join(platforms) if not platforms.is_empty() else "none", info.ladders],
		"| Cooperative mechanisms | %s; %d gates |" % [", ".join(puzzles) if not puzzles.is_empty() else "none", info.gates],
		"| Collectibles and secrets | %s |" % ("; ".join(info.items) if not info.items.is_empty() else "none"),
		"| Clues | %s |" % (" / ".join(info.clues.map(func(t: String) -> String: return "\"%s\"" % t))),
		"| Save points | %d |" % info.saves,
		"| Exit | either living knight reaches the exit portal; next: %s |" % (LevelCatalog.next_level(def.id) if LevelCatalog.next_level(def.id) != "" else "campaign victory"),
		"| Assets | world_tileset (%s terrain), platforms.png, knight, slimes%s, fruit, coin, created spikes / ladder / UI icons |" % [def.theme, ", boss (scaled slime)" if info.boss != "" else ""],
		"| Static validation | exit reachable: %s; everything reachable (optional bosses allowed): %s |\n" % ["yes" if info.exit_ok else "NO", "yes" if info.all_ok else "NO"],
	])
	return "\n".join(lines) + "\n"


func _plan_footer(est: float, minimum: float) -> String:
	return """
## Campaign length

| Measure | Value |
|---|---|
| Sum of design estimates | %.0f min |
| Sum of minimum movement (analyzer) | %.1f min |
| Measured two-player first play | **not measured yet** (record in `docs/CAMPAIGN_PLAYTEST.md`) |

The design estimates are guesses, not measurements, and they disagree strongly with the hard
floor: pure movement is under 10 minutes, so everything else (combat, puzzles, waiting for
timed platforms, exploration, coordination) must supply the rest. Real first-play time is
therefore uncertain; it could fall below the 90-minute target. It must be measured in the
playtest (Phase 11 balancing), and if it is short the first candidates are more optional rooms
and longer cooperative sections, not slower movement.
""" % [est, minimum]


## What the user has actually reported (docs/PLAYTEST_FEEDBACK.md). Only the user's words go here;
## every other level stays "pending".
const USER_REPORTS := {
	"l01": "user-reported: reached and passed on the first attempt (Phase 11 baseline)",
	"l02": "user-reported: reached and passed on the first attempt (Phase 11 baseline)",
	"l03": "user-reported: reached and passed on the first attempt (Phase 11 baseline)",
	"l04": "user-reported: reached and passed on the first attempt (Phase 11 baseline)",
}


func _test_header() -> String:
	return """# Campaign Playtest Checklist

Status: **levels 1–4 user-reported passed on the first attempt (no per-check results or times
recorded); levels 5–24 pending manual playtest.** Play with two people on one keyboard.
Generated by `tools/campaign_report.gd`; the puzzle notes come from the level designs. The
automated per-level results are in `docs/LEVEL_VALIDATION_MATRIX.md`; the user's own words are
in `docs/PLAYTEST_FEEDBACK.md`.

## Suggested full-campaign procedure

1. Start the real game, New Game in an empty slot. Note the clock time.
2. Play every level in order. For each one, tick its checklist below and write the completion
   time (the victory screen also lists the fastest level; per-level times are stored in the
   save as `level_times`).
3. Once per world: close the window in the middle of a level and Continue (save and resume).
4. In one later world, let a knight die on purpose (spikes until zero health, or lava): the run
   must restart at level 1 with nothing; then Continue from the menu shows only the new run.
5. Try each optional boss once (levels 7, 15, 23) and the reward behind it; also finish one boss
   level without fighting.
6. Finish level 24: the victory screen must show 24 of 24 and your real coins and time.
7. Record for each level: completion time, unclear mechanics, frustrating sections, sudden
   difficulty spikes, softlocks, camera problems, save problems, collectible mistakes.

"""


func _test_level(def: LevelDefinition, info: Dictionary, note: String) -> String:
	var lines := PackedStringArray([
		"### %d. %s (`%s`) — %s\n" % [def.order, def.title, def.id, USER_REPORTS.get(def.id, "pending")],
		"Design: %s\n" % note,
		"| Check | Result |", "|---|---|",
		"| Player One spawn (stands, can move at once) | |",
		"| Player Two spawn | |",
		"| Movement and jumps feel fair | |",
		"| Enemies (%d green, %d purple%s) | |" % [info.green.size(), info.purple.size(), (", optional boss " + info.boss) if info.boss != "" else ""],
		"| Hazards (spikes %d, lava %d, hot ground %d tiles) readable and fair | |" % [info.spikes, info.lava, info.hot],
		"| Main route clear from the scenery and clues | |",
		"| Optional route(s) and secrets found / reachable | |",
		"| Cooperative puzzles solvable and recoverable | |",
		"| Collectibles (%d placed) collected once, not respawning | |" % info.items.size(),
		"| Exit works for either knight; both arrive in the next level | |",
		"| Death: a knight dying restarts the whole run | |",
		"| Save and resume mid-level | |",
		"| Camera (shared / split) readable | |",
		"| Completion time (design estimate %.1f min) | |" % def.estimated_minutes,
		"| Notes (unclear, frustrating, spikes in difficulty, softlocks) | |\n",
	])
	return "\n".join(lines) + "\n"


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wrote ", path)
