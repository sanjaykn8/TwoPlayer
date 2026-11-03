extends CanvasLayer
## Development overlay for Phase 4: one line per slime plus knight health and the coin-drop
## preview total. Only used by the enemy test room.

var room: Node

var _label: Label


func _ready() -> void:
	layer = 10
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
	for k: Knight in [room.knight_1, room.knight_2]:
		lines.append("P%d HP %d/%d %s inv %.1f" % [k.player_id(), k.health.current_health, k.health.max_health,
			k.state_name(), k.health.invulnerability_left()])
	for slime: Slime in room.slimes():
		var s := slime.stats
		var target := "-"
		if slime.target != null and is_instance_valid(slime.target):
			target = "P%d" % slime.target.player_id()
		lines.append("%-17s %-7s v%d/%d r%d tgt %s los %s stg %d/%d %s dmg %s coins %s" % [
			slime.name, slime.state_name().left(7), int(s.patrol_speed), int(s.chase_speed()),
			int(slime.detection_radius()), target, "Y" if slime.target_visible else "N",
			slime.stagger.progress, slime.stagger.threshold,
			("%.1fs" % slime.stagger.time_left) if slime.is_staggered() else "-",
			"ON" if slime.can_damage() else "off",
			str(slime.drop_result.count) if slime.drop_result != null else "-"])
	lines.append("drops %d  coins dropped %d (collection is Phase 5)%s" % [room.drops_announced,
		room.coins_announced, "  PROTECTED" if room.protected else ""])
	lines.append("DEV F1/F2 hurt F3 heal F4 protect F6 reload F7 hide F9 debug draw")
	_label.text = "\n".join(lines)
