@tool
class_name BossSeal
extends PuzzleSource
## Remembers that a level's optional boss was defeated in this run. It turns on (for good)
## when its boss dies; gates wired to it (LATCH) open the reward room. Saved like any other
## persistent puzzle state, so the reward stays reachable after loading, and it resets with
## the run on a team wipe. Invisible.


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	restore_saved_state()


func mark_defeated() -> void:
	if _active:
		return
	_set_active(true)
	pulsed.emit(0)
	save_state()


func _save_state() -> Dictionary:
	return {"defeated": true} if _active else {}


func _apply_saved_state(state: Dictionary) -> void:
	if bool(state.get("defeated", false)):
		_set_active(true)


func debug_state() -> String:
	return "boss defeated" if _active else "boss alive"
