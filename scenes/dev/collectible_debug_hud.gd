extends CanvasLayer
## Development overlay for Phase 5: each player's effective stats and active timed effects,
## the shared coin total and the latest collection events (who collected what).

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
	var run := RunState.current()
	var lines := PackedStringArray()
	for id in RunState.PLAYER_IDS:
		var s := run.player(id)
		var hp := "%d/%d" % [s.health.current_health if s.health != null else s.current_health, s.max_health()]
		lines.append("P%d HP %s pow %d range x%.2f speed x%.2f cd x%.2f poison %.0fs" % [
			id, hp, s.attack_power(), s.range_multiplier(), s.speed_multiplier(), s.cooldown_multiplier(), s.poison_seconds])
		var effects := PackedStringArray()
		for effect in s.effects.active_ids():
			var charges := s.effects.charges(effect)
			effects.append("%s %.1fs%s" % [effect, s.effects.remaining(effect), (" x%d" % charges) if charges > 0 else ""])
		lines.append("   effects: %s" % (", ".join(effects) if not effects.is_empty() else "-"))
	lines.append("SHARED COINS %d   items collected %d%s" % [run.coins, run.collected.size(),
		"   PAUSED" if room.get_tree().paused else ""])
	for line in room.log_lines:
		lines.append("  " + line)
	lines.append("DEV F1/F2 hurt F3 heal F4 coins F5 new run F6 reload F7 hide F8 pause F9 debug")
	_label.text = "\n".join(lines)
