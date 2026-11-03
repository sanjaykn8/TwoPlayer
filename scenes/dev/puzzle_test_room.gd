extends Node
## Phase 7 cooperative puzzle test room: ten sections (see tools/build_phase7_content.gd and
## docs/MANUAL_PUZZLE_TEST.md), shown through the SplitScreenRig. Development keys exist
## only in this room:
##   F1 / F2  hurt P1 / P2 (CONTACT)        F3  heal both / revive the dead at their spawn
##   F4       move both knights to the start of the next section (wraps around)
##   F5       start a NEW run and reload (all puzzle progress is forgotten)
##   F6       reload the room, keeping the run (completed locks and latched gates stay)
##   F7       overlay on/off   F8  pause / resume   F9  debug drawing (puzzle ids and states)

## Section starts (x) for F4, floor y = 512.
const SECTION_X := [40, 360, 760, 1200, 1640, 2300, 2660, 3300, 3640, 4040]
const FLOOR_Y := 512.0

var log_lines: PackedStringArray = []
var section := 0

@onready var rig: SplitScreenRig = $SplitScreenRig
@onready var hud: CanvasLayer = $PuzzleDebugHud
@onready var level: Node2D = $Level
@onready var knight_1: Knight = $Level/Knights/Knight1
@onready var knight_2: Knight = $Level/Knights/Knight2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	for node in find_puzzles():
		if node is PuzzleLogic:
			(node as PuzzleLogic).completed.connect(_log.bind("%s completed" % node.puzzle_id))
			(node as PuzzleLogic).failed.connect(_log.bind("%s failed - reset" % node.puzzle_id))
		elif node is PuzzleGate:
			(node as PuzzleGate).state_changed.connect(_on_gate_state.bind(node))
	for knight: Knight in [knight_1, knight_2]:
		knight.died.connect(_log.bind("P%d DIED" % knight.player_id()))
	rig.attach_world(level)
	hud.set(&"room", self)


func _exit_tree() -> void:
	PuzzleSource.debug_visible = false
	SafeSpotTracker.debug_visible = false
	get_tree().paused = false


func find_puzzles() -> Array[PuzzleSource]:
	var found: Array[PuzzleSource] = []
	for node in level.find_children("*", "Node2D", true, false):
		if node is PuzzleSource:
			found.append(node)
	return found


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			knight_1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
		KEY_F2:
			knight_2.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
		KEY_F3:
			for knight: Knight in [knight_1, knight_2]:
				if knight.is_dead():
					# Development-only revive; the campaign death reset is Phase 8.
					knight.revive()
					knight.teleport_to(knight.safe_spot.spawn_position)
				knight.health.heal(1)
		KEY_F4:
			section = (section + 1) % SECTION_X.size()
			knight_1.teleport_to(Vector2(SECTION_X[section], FLOOR_Y))
			knight_2.teleport_to(Vector2(SECTION_X[section] + 32, FLOOR_Y))
			rig.snap_to_targets()
		KEY_F5:
			RunState.reset()
			get_tree().reload_current_scene()
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F7:
			hud.visible = not hud.visible
		KEY_F8:
			get_tree().paused = not get_tree().paused
		KEY_F9:
			var on := not PuzzleSource.debug_visible and OS.is_debug_build()
			PuzzleSource.debug_visible = on
			SafeSpotTracker.debug_visible = on
			for node in find_puzzles():
				node.queue_redraw()
		_:
			return
	get_viewport().set_input_as_handled()


func _on_gate_state(state: PuzzleGate.State, gate: PuzzleGate) -> void:
	if state == PuzzleGate.State.OPENING or state == PuzzleGate.State.CLOSED or state == PuzzleGate.State.WAITING:
		_log("%s %s" % [gate.name, PuzzleGate.State.keys()[state]])


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 6:
		log_lines.remove_at(0)
