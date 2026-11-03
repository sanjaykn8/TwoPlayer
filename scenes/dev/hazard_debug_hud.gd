extends CanvasLayer
## Development overlay for Phase 6: each knight's health, state, last safe position, hazard
## contacts, falls and protective effects; the state of every timed/collapsing platform; and
## the latest hazard events.

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
	for knight: Knight in [room.knight_1, room.knight_2]:
		var spot := knight.safe_spot
		var safe := "(%d,%d)" % [spot.last_safe_position.x, spot.last_safe_position.y] if spot.has_safe_position else "spawn"
		var effects := PackedStringArray()
		var stats := RunState.current().player(knight.profile.player_id)
		for effect in stats.effects.active_ids():
			var charges := stats.effects.charges(effect)
			effects.append("%s%s" % [effect, (" x%d" % charges) if charges > 0 else ""])
		lines.append("P%d HP %d/%d %s%s safe %s hazards %d falls %d %s" % [
			knight.profile.player_id, knight.health.current_health, knight.health.max_health,
			knight.state_name(), " INV" if knight.health.is_invulnerable() else "", safe,
			spot.hazard_contacts, spot.fall_count, ", ".join(effects)])
	var platforms := PackedStringArray()
	for platform: PlatformBody in room.find_platforms():
		if platform.has_method(&"state_name"):
			platforms.append("%s:%s" % [platform.name, platform.call(&"state_name")])
	lines.append("PLATFORMS " + " ".join(platforms) + ("   PAUSED" if room.get_tree().paused else ""))
	for line in room.log_lines:
		lines.append("  " + line)
	lines.append("DEV F1/F2 hurt F3 heal/revive F4 shields F5 new run F6 reload F7 hide F8 pause F9 debug")
	_label.text = "\n".join(lines)
