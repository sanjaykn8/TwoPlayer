extends CanvasLayer
## Development overlay for Phase 7: both knights' health and state, every lock and gate with
## its state and timer, the number of saved puzzle states in the run, and recent events.

var room: Node

var _label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.position = Vector2(4, 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 8)
	panel.add_child(_label)
	add_child(panel)


func _process(_delta: float) -> void:
	if room == null or not is_instance_valid(room):
		return
	var lines := PackedStringArray()
	for knight: Variant in [room.knight_1, room.knight_2]:
		if not is_instance_valid(knight):
			continue
		lines.append("P%d HP %d/%d %s  x %d" % [knight.player_id(), knight.health.current_health,
			knight.health.max_health, knight.state_name(), knight.global_position.x])
	var locks := PackedStringArray()
	var gates := PackedStringArray()
	for node: PuzzleSource in room.find_puzzles():
		if node is PuzzleLogic:
			locks.append("%s:%s" % [node.puzzle_id.trim_suffix("_lock"), node.debug_state().get_slice(" ", 1)])
		elif node is PuzzleGate:
			var gate := node as PuzzleGate
			var timer := " %.1f" % gate.time_left if gate.time_left > 0.0 else ""
			gates.append("%s:%s%s" % [gate.name.trim_prefix("Gate"), gate.state_name(), timer])
	lines.append("LOCKS " + " ".join(locks))
	lines.append("GATES " + " ".join(gates))
	var run := RunState.current()
	var saved := 0
	for key: String in run.puzzles.scope_keys():
		saved += run.puzzles.snapshot().states[key].size()
	lines.append("saved puzzle states %d%s" % [saved, "   PAUSED" if room.get_tree().paused else ""])
	for line in room.log_lines:
		lines.append("  " + line)
	lines.append("DEV F1/F2 hurt F3 heal/revive F4 next section F5 new run F6 reload F7 hide F8 pause F9 debug")
	_label.text = "\n".join(lines)
