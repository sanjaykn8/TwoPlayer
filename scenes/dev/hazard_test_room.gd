extends Node
## Phase 6 hazard test room: spikes, hot ground, a lava pit, bottomless pits and every
## advanced platform (moving horizontal/vertical, timed, disappearing, collapsing), shown
## through the SplitScreenRig. Falling is handled by each knight's SafeSpotTracker (1 FALL
## damage, respawn at the last safe position). Development keys exist only in this room:
##   F1 / F2  hurt P1 / P2 (CONTACT)        F3  heal both / revive the dead at their spawn
##   F4       give P1 a 3-hit yellow fruit shield and the yellow jar (protection tests)
##   F5       start a NEW run and reload    F6  reload the room, keeping the run
##   F7       overlay on/off   F8  pause / resume   F9  debug drawing (safe-spot markers)

## Most recent hazard events, newest last, for the overlay.
var log_lines: PackedStringArray = []

@onready var rig: SplitScreenRig = $SplitScreenRig
@onready var hud: CanvasLayer = $HazardDebugHud
@onready var level: Node2D = $Level
@onready var knight_1: Knight = $Level/Knights/Knight1
@onready var knight_2: Knight = $Level/Knights/Knight2


func _ready() -> void:
	# The room keeps receiving dev keys while paused; the game itself pauses normally.
	process_mode = Node.PROCESS_MODE_ALWAYS
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	SafeSpotTracker.debug_visible = OS.is_debug_build()
	for hazard: Hazard in find_hazards():
		hazard.triggered.connect(_on_hazard_triggered.bind(hazard))
	for knight: Knight in [knight_1, knight_2]:
		knight.safe_spot.fell.connect(_on_fell)
		knight.died.connect(_on_died.bind(knight))
	rig.attach_world(level)
	hud.set(&"room", self)


func _exit_tree() -> void:
	SafeSpotTracker.debug_visible = false
	get_tree().paused = false


func find_hazards() -> Array[Hazard]:
	var found: Array[Hazard] = []
	for node in level.find_children("*", "Area2D", true, false):
		if node is Hazard:
			found.append(node)
	return found


func find_platforms() -> Array[PlatformBody]:
	var found: Array[PlatformBody] = []
	for node in level.find_children("*", "AnimatableBody2D", true, false):
		if node is PlatformBody:
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
			var stats := RunState.current().player(knight_1.profile.player_id)
			stats.collect_fruit(PlayerStats.FruitType.YELLOW, 3)
			stats.collect_jar(PlayerStats.JarType.YELLOW)
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
			SafeSpotTracker.debug_visible = not SafeSpotTracker.debug_visible and OS.is_debug_build()
		_:
			return
	get_viewport().set_input_as_handled()


func _on_hazard_triggered(knight: Knight, applied: int, hazard: Hazard) -> void:
	if hazard.kind == Hazard.Kind.FALL:
		return  # logged by _on_fell
	_log("P%d %s %s" % [knight.profile.player_id, Hazard.Kind.keys()[hazard.kind],
		"hit" if applied > 0 else "blocked"])


func _on_fell(knight: Knight, survived: bool) -> void:
	_log("P%d fell -> %s" % [knight.profile.player_id, "respawned" if survived else "DEAD"])


func _on_died(knight: Knight) -> void:
	_log("P%d DIED" % knight.profile.player_id)


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 6:
		log_lines.remove_at(0)
