@tool
class_name EncounterZone
extends PuzzleSource
## An arena lock. While it waits, it is ACTIVE (gates that FOLLOW it stay open). When every
## living knight is inside its rectangle and any of its enemies is alive, the fight starts: it
## turns inactive, so its gates close behind the knights (gates never close on an occupant).
## When all its enemies are dead it turns active again for good (saved), so its gates reopen.
##
## Enemies: the nodes listed in `enemies`, or, when that list is empty, every slime and enemy
## standing inside the rectangle when the level starts. Enemies summoned later (boss minions)
## are not needed to finish. After a load, a fight that was not finished starts again when the
## knights are inside (its defeated enemies stay defeated).
## Origin = top-left of `size`.

signal fight_started
signal fight_completed

enum Phase { WAITING, FIGHTING, DONE }

@export var size := Vector2(160, 96):
	set(value):
		size = value.max(Vector2(16, 16))
		queue_redraw()
@export var enemies: Array[NodePath] = []

var phase := Phase.WAITING
var _tracked: Array[Node] = []
var _collected := false


func _init() -> void:
	_active = true  # gates are open before the fight, from their very first frame


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	restore_saved_state()
	if phase != Phase.DONE:
		_collect.call_deferred()


func rect() -> Rect2:
	return Rect2(global_position, size)


func living_enemies() -> int:
	var n := 0
	for node in _tracked:
		if is_instance_valid(node) and node.is_inside_tree() and not node.is_dead():
			n += 1
	return n


func debug_state() -> String:
	return "%s %d" % [Phase.keys()[phase], living_enemies()]


func _collect() -> void:
	_tracked.clear()
	if enemies.is_empty():
		var level := get_parent()
		while level.get_parent() != null and not level.has_meta(&"level_id"):
			level = level.get_parent()
		for node in level.find_children("*", "", true, false):
			# Grown a little: enemies stand exactly on the floor, the rectangle's bottom edge.
			if (node is Enemy or node is Slime) and not node.is_queued_for_deletion() and rect().grow(4.0).has_point(node.global_position):
				_tracked.append(node)
	else:
		for path in enemies:
			var node := get_node_or_null(path)
			if node != null and not node.is_queued_for_deletion():
				_tracked.append(node)
	_collected = true


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _collected:
		return
	match phase:
		Phase.WAITING:
			if living_enemies() == 0:
				_complete()
			elif _knights_inside():
				phase = Phase.FIGHTING
				_set_active(false)
				Sfx.cue(&"orc_alert", self)
				fight_started.emit()
		Phase.FIGHTING:
			if living_enemies() == 0:
				_complete()


func _knights_inside() -> bool:
	var inner := rect().grow(-2.0)
	var any := false
	for node in get_tree().get_nodes_in_group(Knight.GROUP):
		var k := node as Knight
		if k.is_dead():
			continue
		if not inner.has_point(k.global_position + Vector2(0, -9)):  # body centre
			return false
		any = true
	return any


func _complete() -> void:
	var was_fighting := phase == Phase.FIGHTING
	phase = Phase.DONE
	_set_active(true)
	save_state()
	if was_fighting:
		Sfx.cue(&"coop", self)
		fight_completed.emit()


func _save_state() -> Dictionary:
	return {"done": true} if phase == Phase.DONE else {}


func _apply_saved_state(state: Dictionary) -> void:
	if bool(state.get("done", false)):
		phase = Phase.DONE
		_set_active(true)


func _draw() -> void:
	if Engine.is_editor_hint() or (debug_visible and OS.is_debug_build()):
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.3, 0.3, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.3, 0.3, 0.7), false, 1.0)
	_draw_debug(Vector2(0, -4))
