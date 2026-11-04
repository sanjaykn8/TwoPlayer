class_name LevelProbe
extends RefCounted
## Runs the 20 runtime checks of docs/LEVEL_VALIDATION_MATRIX.md on one campaign level that is
## loaded in a real CampaignGame. Knights act through real input (move, jump, climb, drop,
## attack) and the real physics; they are only teleported to the start of each check.
## Every result is "PASS", "FAIL: ..." or "N/A: ..." (the level has no such element).
##
## The probe never kills a knight on purpose (that would start a team wipe); lava is checked
## for presence and kind, and its instant death is covered by the Phase 6/8 tests.

const CHECKS := [
	"load", "spawn_p1", "spawn_p2", "move", "jump", "climb", "one_way", "collision", "camera",
	"enemies", "combat", "hazards", "collectibles", "upgrades", "effects", "puzzles", "optional",
	"exit", "progression", "save_resume",
]
const T := 16.0

var host: Node
var game: CampaignGame
## The last damage each knight took ("P1 SPIKE from Spikes2"), to explain an unexpected death.
var last_damage := {}
var level_id := ""
var results := {}
var dir := ""


func _init(test_host: Node, campaign: CampaignGame, id: String, save_dir: String) -> void:
	host = test_host
	game = campaign
	level_id = id
	dir = save_dir


func _frames(n: int) -> void:
	for i in n:
		await host.get_tree().physics_frame


func _k(i: int) -> Knight:
	return game.knights[i]


func _record(check: String, ok: bool, detail := "") -> void:
	results[check] = "PASS" if ok else "FAIL: " + detail


func _na(check: String, why: String) -> void:
	results[check] = "N/A: " + why


func _release_all() -> void:
	for k in game.knights:
		if not is_instance_valid(k):
			continue
		for action in k.profile.actions():
			Input.action_release(action)


func _press(k: Knight, action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _place(k: Knight, feet: Vector2) -> void:
	k.teleport_to(feet)
	k.velocity = Vector2.ZERO


func _heal(k: Knight) -> void:
	if k.health.is_alive():
		k.health.heal(99)
		k.health.clear_invulnerability()


## Every check in order. Returns the results dictionary. If a knight dies (a team wipe), the
## probe stops: the check that caused it fails with the cause, the rest are BLOCKED.
func run() -> Dictionary:
	_release_all()
	_watch_damage()
	var analyzer = preload("res://tools/level_analyzer.gd").new(game.level)
	results.load = "PASS" if game.level != null and str(game.level.get_meta(&"level_id")) == level_id else "FAIL: not loaded"
	var steps := [
		["spawn", _spawns], ["move", _move_and_jump], ["climb", _climb], ["one_way", _one_way.bind(analyzer)],
		["collision", _collision], ["camera", _camera], ["enemies", _enemies_and_combat], ["hazards", _hazards],
		["collectibles", _collectibles], ["effects", _effects], ["puzzles", _puzzles],
	]
	# Enemies only act during their own check: a knight left standing near a patrol for the
	# length of another check would otherwise be worn down (a harness artefact, not gameplay).
	_freeze_enemies(true)
	for step: Array in steps:
		await (step[1] as Callable).call()
		if _wiped(step[0]):
			return results
	_freeze_enemies(false)
	var optional: Dictionary = analyzer.analyze(true)
	var missing: PackedStringArray = analyzer.unreachable_things(optional)
	_record("optional", missing.is_empty(), str(missing))
	await _save_resume()
	_watch_damage()
	await _exit_and_progression()
	_release_all()
	return results


func _freeze_enemies(frozen: bool) -> void:
	for node in game.level.find_children("*", "", true, false):
		if (node is Slime or node is BossSlime) and not node.is_queued_for_deletion():
			node.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT


func _watch_damage() -> void:
	for k in game.knights:
		var id := k.player_id()
		k.health.damage_received.connect(func(event: DamageEvent, applied: int) -> void:
			last_damage[id] = "P%d %s x%d from %s" % [id, DamageEvent.Category.keys()[event.category], applied,
				event.source.name if event.source != null and is_instance_valid(event.source) else "?"])


func _wiped(step: String) -> bool:
	if game.wipes == 0 and game.phase == CampaignGame.Phase.PLAYING:
		return false
	_release_all()
	var check: String = step if results.has(step) or CHECKS.has(step) else step
	results[check] = "FAIL: team wipe during this check (%s)" % ", ".join(last_damage.values())
	for c in CHECKS:
		if not results.has(c):
			results[c] = "BLOCKED: probe stopped after a team wipe"
	return true


# --- Checks ---------------------------------------------------------------------------------

func _spawns() -> void:
	await _frames(30)
	var def := LevelCatalog.level(level_id)
	for i in 2:
		var k := _k(i)
		var spawn := def.spawn_p1 if i == 0 else def.spawn_p2
		var ok := k.is_on_floor() and k.global_position.distance_to(spawn) < 4.0 and WorldSnapshot.knight_position_is_clear(k) \
			and k.health.current_health == k.health.max_health
		_record("spawn_p%d" % (i + 1), ok, "at %s on_floor=%s spawn %s" % [k.global_position, k.is_on_floor(), spawn])


func _move_and_jump() -> void:
	# Both knights at once, as two players would: P1 right, P2 left, then both jump.
	var start := [_k(0).global_position, _k(1).global_position]
	Input.action_press(_k(0).profile.action_right)
	Input.action_press(_k(1).profile.action_left)
	await _frames(20)
	_release_all()
	var moved := absf(_k(0).global_position.x - start[0].x) > 8.0 and absf(_k(1).global_position.x - start[1].x) > 8.0
	_record("move", moved, "P1 %s -> %s, P2 %s -> %s" % [start[0], _k(0).global_position, start[1], _k(1).global_position])
	await _frames(20)
	var y := [_k(0).global_position.y, _k(1).global_position.y]
	Input.action_press(_k(0).profile.action_up)
	Input.action_press(_k(1).profile.action_up)
	var best := [0.0, 0.0]
	for f in 30:
		await _frames(1)
		for i in 2:
			best[i] = maxf(best[i], y[i] - _k(i).global_position.y)
	_release_all()
	_record("jump", best[0] >= 24.0 and best[1] >= 24.0, "rose %.0f / %.0f px" % [best[0], best[1]])
	await _frames(40)


func _climb() -> void:
	var ladders := game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Climbable)
	if ladders.is_empty():
		_na("climb", "no ladders")
		return
	var failures := PackedStringArray()
	for ladder: Climbable in ladders:
		var k := _k(0)
		_place(k, Vector2(ladder.global_position.x, ladder.bottom_y()))
		await _frames(3)
		Input.action_press(k.profile.action_up)
		var top := k.global_position.y
		var grabbed := false
		for f in 60:
			await _frames(1)
			top = minf(top, k.global_position.y)
			grabbed = grabbed or k.is_climbing()
		var climbed := grabbed and ladder.bottom_y() - top >= 24.0
		Input.action_release(k.profile.action_up)
		if not climbed:
			failures.append("%s (rose %.0f px)" % [ladder.name, ladder.bottom_y() - top])
	await _frames(5)
	_record("climb", failures.is_empty(), ", ".join(failures))


func _one_way(analyzer) -> void:
	var terrain := game.level.get_node("Terrain") as TileMapLayer
	var k := _k(0)
	for cell in terrain.get_used_cells():
		if terrain.get_cell_source_id(cell) != 1 or analyzer.ladders.has(cell):
			continue
		var below := cell + Vector2i(0, 1)
		if analyzer.solid.has(below) or analyzer.solid.has(below + Vector2i(0, 1)) or analyzer.hazard.has(below) or analyzer.hazard.has(below + Vector2i(0, 1)):
			continue
		if not analyzer.standable(cell):
			continue
		# Only where the drop lands on safe ground (never into lava, spikes or a pit).
		var landing: Vector2i = analyzer._land(cell.x, cell.y + 1)
		if landing.x < 0 or analyzer.platforms.has(landing):
			continue
		_place(k, Vector2(cell.x * T + 8, cell.y * T))
		await _frames(10)
		var y := k.global_position.y
		if not k.is_on_floor():
			continue
		Input.action_press(k.profile.action_down)
		await _frames(25)
		Input.action_release(k.profile.action_down)
		_record("one_way", k.global_position.y > y + 10.0, "stayed at %.0f (tile %s)" % [k.global_position.y, cell])
		await _frames(30)
		return
	_na("one_way", "no one-way platform with free space below")


func _collision() -> void:
	var def := LevelCatalog.level(level_id)
	_place(_k(0), def.spawn_p1)
	_place(_k(1), def.spawn_p1 + Vector2(14, 0))
	await _frames(5)
	Input.action_press(_k(0).profile.action_right)
	Input.action_press(_k(1).profile.action_left)
	await _frames(20)
	_release_all()
	var gap := absf(_k(1).global_position.x - _k(0).global_position.x)
	_record("collision", gap >= 8.0, "bodies overlap (gap %.1f px)" % gap)
	_place(_k(0), def.spawn_p1)
	_place(_k(1), def.spawn_p2)
	await _frames(20)


func _camera() -> void:
	var rig := game.rig
	var def := LevelCatalog.level(level_id)
	var ok := rig.bounds == def.camera_bounds
	var detail := "bounds %s" % rig.bounds
	# Separate the knights by half a screen and more: the view must split.
	var far := def.spawn_p1 + Vector2(560, 0)
	var analyzer = preload("res://tools/level_analyzer.gd").new(game.level)
	var cell := Vector2i(int(far.x / T), int(far.y / T))
	var found := false
	for dy in range(-12, 13):
		for dx in range(0, 30):
			var c := cell + Vector2i(dx, dy)
			if analyzer.standable(c) and not analyzer.platforms.has(c):
				far = Vector2(c.x * T + 8, c.y * T)
				found = true
				break
		if found:
			break
	if found:
		_k(1).set_physics_process(false)
		_k(1).global_position = far
		await _frames(45)
		var split := rig.is_split()
		_k(1).set_physics_process(true)
		_place(_k(1), def.spawn_p2)
		var merged := false
		for f in 180:
			await _frames(1)
			if rig.mode == SplitScreenRig.Mode.SHARED:
				merged = true
				break
		ok = ok and split and merged
		detail += " split=%s merged=%s" % [split, merged]
	_record("camera", ok, detail)


func _enemies_and_combat() -> void:
	var slimes: Array = game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Slime and not n.is_queued_for_deletion())
	if slimes.is_empty():
		_na("enemies", "no slimes")
		_na("combat", "no slimes")
		return
	var start := {}
	for s: Slime in slimes:
		start[s] = s.global_position
	_freeze_enemies(false)
	for k in game.knights:
		k.health.start_invulnerability(5.0)  # watching the patrols must not wear the knights down
	await _frames(240)
	var moved := 0
	var bad := PackedStringArray()
	for s: Slime in slimes:
		if not is_instance_valid(s):
			continue
		if s.global_position.distance_to(start[s]) > 4.0:
			moved += 1
		if s.global_position.y > LevelCatalog.level(level_id).camera_bounds.end.y:
			bad.append("%s fell out" % s.name)
		if not s.is_on_floor() and s.state != Slime.State.DEAD:
			bad.append("%s not on the ground" % s.name)
	_record("enemies", moved > 0 and bad.is_empty(), "moved %d/%d %s" % [moved, slimes.size(), bad])
	# Combat: P1 strikes the first slime with a real attack.
	var target: Slime = slimes[0]
	var k := _k(0)
	_heal(k)
	_place(k, target.global_position + Vector2(-14, 0))
	target.set_physics_process(false)
	await _frames(2)
	await _press(k, k.profile.action_right, 1)
	await _press(k, k.profile.action_attack, 2)
	await _frames(15)
	target.set_physics_process(true)
	var hit := target.stagger.progress > 0 or target.state == Slime.State.STAGGERED or target.is_dead()
	_record("combat", hit, "stagger progress %d" % target.stagger.progress)
	_freeze_enemies(true)
	_place(k, LevelCatalog.level(level_id).spawn_p1)
	await _frames(70)
	_heal(_k(0))
	_heal(_k(1))


func _hazards() -> void:
	var hazards: Array = game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Hazard and (n as Hazard).kind != Hazard.Kind.FALL)
	var hurtful := hazards.filter(func(h: Hazard) -> bool: return h.kind == Hazard.Kind.SPIKES or h.kind == Hazard.Kind.HOT_GROUND)
	var lava := hazards.filter(func(h: Hazard) -> bool: return h.kind == Hazard.Kind.LAVA)
	if hazards.is_empty():
		_na("hazards", "no hazards")
		return
	var failures := PackedStringArray()
	for h: Hazard in hurtful:
		var k := _k(1)
		_heal(k)
		var before := k.health.current_health
		var at := h.global_position + Vector2(h.size.x * 0.5, 0.0)
		if h.kind == Hazard.Kind.SPIKES:
			at.y = h.global_position.y - 4.0
		else:
			at.y = h.global_position.y - 2.0
		_place(k, at)
		await _frames(20)
		if k.health.current_health != before - 1:
			failures.append("%s: health %d -> %d" % [h.name, before, k.health.current_health])
		_place(k, LevelCatalog.level(level_id).spawn_p2)
		await _frames(5)
		_heal(k)
	for h: Hazard in lava:
		if h.size.y < 16.0:
			failures.append("%s is too thin to read" % h.name)
	_record("hazards", failures.is_empty(), "; ".join(failures))
	await _frames(70)
	_heal(_k(0))
	_heal(_k(1))


func _collectibles() -> void:
	var items: Array = game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Collectible and not (n is DroppedCoin) and not n.is_queued_for_deletion())
	if items.is_empty():
		_na("collectibles", "none placed")
		_na("upgrades", "none placed")
		return
	var run := RunState.current()
	var failures := PackedStringArray()
	var upgrades := PackedStringArray()
	var jars := 0
	for item: Collectible in items:
		var k := _k(0)
		_heal(k)
		var stats := run.player(1)
		var snapshot := [stats.max_health_bonus, stats.attack_power_bonus, stats.speed_bonus, stats.effects.has(PlayerEffects.JAR_LUCK)]
		var coins := run.coins
		_place(k, item.global_position)
		await _frames(6)
		if item.collectible_id != "" and not run.is_collected(item.collectible_id):
			failures.append("%s not collected" % item.name)
			continue
		if item is CoinStash and run.coins < coins + (item as CoinStash).amount:
			failures.append("%s gave %d coins" % [item.name, run.coins - coins])
		if item is Jar:
			jars += 1
			var after := [stats.max_health_bonus, stats.attack_power_bonus, stats.speed_bonus, stats.effects.has(PlayerEffects.JAR_LUCK)]
			if after == snapshot:
				upgrades.append("%s changed nothing" % item.name)
			if run.player(2).max_health_bonus != 0 and (item as Jar).jar_type == PlayerStats.JarType.GREEN:
				upgrades.append("%s upgraded the other knight" % item.name)
	_record("collectibles", failures.is_empty(), "; ".join(failures))
	if jars == 0:
		_na("upgrades", "no jars in this level (fruit upgrades checked under collectibles)")
	else:
		_record("upgrades", upgrades.is_empty(), "; ".join(upgrades))
	_place(_k(0), LevelCatalog.level(level_id).spawn_p1)
	await _frames(10)


func _effects() -> void:
	var tiles: Array = game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is PowerTile)
	if tiles.is_empty():
		_na("effects", "no power tiles")
		return
	var failures := PackedStringArray()
	for tile: PowerTile in tiles:
		var k := _k(1)
		var effects := RunState.current().player(2).effects
		effects.clear()
		_place(k, tile.global_position + Vector2(0, -10))
		await _frames(15)
		if effects.active_ids().is_empty():
			failures.append("%s gave no effect" % tile.name)
		_place(k, LevelCatalog.level(level_id).spawn_p2)
		await _frames(5)
	_record("effects", failures.is_empty(), "; ".join(failures))


# --- Puzzles: every non-boss gate opened through its real inputs ------------------------------

func _puzzles() -> void:
	var gates: Array = game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is PuzzleGate)
	var controls: Array = game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is PlatformController)
	if gates.is_empty() and controls.is_empty():
		_na("puzzles", "no mechanisms")
		return
	var failures := PackedStringArray()
	for gate: PuzzleGate in gates:
		var controller := gate.get_node_or_null(gate.controller)
		if controller is BossSeal:
			continue
		if gate.is_open():
			continue
		await _activate(controller, [0, 1])
		var opened := false
		for f in 90:
			await _frames(1)
			if gate.is_open():
				opened = true
				break
		if not opened:
			failures.append("%s stayed %s" % [gate.name, PuzzleGate.State.keys()[gate.state]])
		_release_all()
		await _frames(10)
	for pc: PlatformController in controls:
		var platform := pc.get_node_or_null(pc.platform) as PlatformBody
		var controller := pc.get_node_or_null(pc.controller)
		var before := platform.global_position
		var was := platform.collision_enabled()
		await _activate(controller, [0, 1])
		var reacted := false
		for f in 120:
			await _frames(1)
			# A TRIGGER controller may find its platform already active (another controller
			# on the same switch triggered it): being active then counts.
			var moved := platform.global_position.distance_to(before) > 4.0 or platform.collision_enabled() != was
			if moved or (pc.mode == PlatformController.Mode.TRIGGER and platform.collision_enabled()):
				reacted = true
				break
		if not reacted:
			failures.append("%s did not react to %s" % [platform.name, controller.name])
	_record("puzzles", failures.is_empty(), "; ".join(failures))
	var def := LevelCatalog.level(level_id)
	_place(_k(0), def.spawn_p1)
	_place(_k(1), def.spawn_p2)
	await _frames(10)


## Activates a puzzle source the way knights would: plates by standing on them, switches and
## targets by real attacks. `knights` are the knight indices free to use.
func _activate(source: Node, knights: Array) -> void:
	if source is PuzzleLogic:
		var logic := source as PuzzleLogic
		var inputs: Array = []
		for path in logic.inputs:
			inputs.append(logic.get_node(path))
		match logic.mode:
			PuzzleLogic.Mode.ANY:
				var pick: Node = inputs[0]
				for input in inputs:
					if input is AttackSwitch:
						pick = input
						break
				await _activate(pick, knights)
			PuzzleLogic.Mode.SYNC:
				await _strike_together(inputs[0], inputs[1])
			PuzzleLogic.Mode.SEQUENCE:
				for input in inputs:
					await _strike(input, knights[0])
					await _frames(12)
			_:
				# ALL: latches and switches first, then timed plates, held plates last.
				inputs.sort_custom(func(a: Node, b: Node) -> bool: return _order(a) < _order(b))
				var plates := inputs.filter(func(n: Node) -> bool: return n is PressurePlate)
				var others := inputs.filter(func(n: Node) -> bool: return not (n is PressurePlate))
				for input in others:
					await _activate(input, knights)
					await _frames(5)
				if plates.size() == 1:
					await _stand(plates[0], knights[knights.size() - 1])
				elif plates.size() >= 2:
					_place(_k(knights[0]), _plate_spot(plates[0]))
					_place(_k(knights[1]), _plate_spot(plates[1]))
					await _frames(8)
	elif source is PressurePlate:
		await _stand(source, knights[0])
	elif source is AttackSwitch:
		await _strike(source, knights[0])


func _order(n: Node) -> int:
	if n is PuzzleLogic or n is AttackSwitch:
		return 0
	if n is PressurePlate and (n as PressurePlate).mode != PressurePlate.Mode.HOLD:
		return 1
	return 2


func _plate_spot(plate: PressurePlate) -> Vector2:
	return plate.global_position + Vector2(plate.width * 0.5, 0)


func _stand(plate: PressurePlate, index: int) -> void:
	_place(_k(index), _plate_spot(plate))
	if plate.required_count == 2:
		_place(_k(1 - index), _plate_spot(plate) + Vector2(6, 0))
	await _frames(8)


## A real attack on a switch or target from a standing place beside it.
func _strike(target: Node2D, index: int) -> void:
	var k := _k(index)
	var side := _strike_side(target)
	_place(k, target.global_position + Vector2(-side * 15.0, 22.0))
	await _frames(3)
	await _press(k, k.profile.action_right if side > 0 else k.profile.action_left, 1)
	await _press(k, k.profile.action_attack, 2)
	await _frames(8)


func _strike_together(a: Node2D, b: Node2D) -> void:
	var sides := [_strike_side(a), _strike_side(b)]
	_place(_k(0), a.global_position + Vector2(-sides[0] * 15.0, 22.0))
	_place(_k(1), b.global_position + Vector2(-sides[1] * 15.0, 22.0))
	await _frames(3)
	Input.action_press(_k(0).profile.action_right if sides[0] > 0 else _k(0).profile.action_left)
	Input.action_press(_k(1).profile.action_right if sides[1] > 0 else _k(1).profile.action_left)
	await _frames(1)
	_release_all()
	Input.action_press(_k(0).profile.action_attack)
	Input.action_press(_k(1).profile.action_attack)
	await _frames(2)
	_release_all()
	await _frames(8)


## +1: stand left of the target and face right; -1: stand right and face left (wall check).
func _strike_side(target: Node2D) -> int:
	var analyzer = preload("res://tools/level_analyzer.gd").new(game.level)
	var cell := Vector2i(int(floor((target.global_position.x - 15.0) / T)), int(round((target.global_position.y + 22.0) / T)))
	return 1 if analyzer.standable(cell) else -1


# --- Save, exit, progression ------------------------------------------------------------------

func _save_resume() -> void:
	var run := RunState.current()
	var k := _k(0)
	var spot := k.global_position
	var coins := run.coins
	var collected := run.collected.size()
	if game.save_now("probe") != OK:
		_record("save_resume", false, "save failed: " + game.saves.last_error)
		return
	var old := game
	var parent := old.get_parent()
	var slot := old.slot
	old.queue_free()
	await _frames(2)
	RunState.reset()
	game = SaveTestUtil.make_game(parent, slot, CampaignGame.StartMode.LOAD, dir)
	if game.begin() != OK:
		_record("save_resume", false, "load failed: " + game.last_notice)
		return
	await _frames(3)
	var r := RunState.current()
	var ok := r.campaign.level_id == level_id and r.coins == coins and r.collected.size() == collected \
		and _k(0).global_position.distance_to(spot) < 20.0
	_record("save_resume", ok, "level %s coins %d/%d items %d/%d P1 %s vs %s" % [r.campaign.level_id, r.coins, coins, r.collected.size(), collected, _k(0).global_position, spot])


func _exit_and_progression() -> void:
	var run := RunState.current()
	var exit := game.level.get_node("Campaign/Exit") as LevelExit
	var final := LevelCatalog.is_final_level(level_id)
	var done := [false]
	game.campaign_completed.connect(func() -> void: done[0] = true)
	# Only Player One walks in; Player Two stays where it is.
	_place(_k(0), exit.global_position + Vector2(-20, 0))
	Input.action_press(_k(0).profile.action_right)
	for f in 120:
		await _frames(1)
		if run.campaign.level_id != level_id or done[0]:
			break
	_release_all()
	await _frames(3)
	var next := LevelCatalog.next_level(level_id)
	if final:
		_record("exit", done[0], "campaign_completed not emitted")
	else:
		_record("exit", run.campaign.level_id == next and game.level.get_meta(&"level_id") == next, "now in %s" % run.campaign.level_id)
	var recorded := run.campaign.completed_levels.has(level_id) and run.campaign.level_times.has(level_id)
	var saved := game.saves.get_slot_metadata(game.slot)
	var saved_ok: bool = saved.finished if final else str(saved.level_id) == next
	_record("progression", recorded and saved_ok, "completed=%s time=%s saved=%s" % [run.campaign.completed_levels.has(level_id), run.campaign.level_times.has(level_id), saved.level_id])
