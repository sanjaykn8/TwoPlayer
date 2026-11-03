extends CanvasLayer
## Development overlay for Phase 3: each knight's state, health, invulnerability and combat
## values, plus the camera mode. Only used by development rooms.

var rig: SplitScreenRig
var knights: Array = []

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
	var lines := PackedStringArray()
	for k: Knight in knights:
		if not is_instance_valid(k):
			continue
		var c := k.combat
		var h := k.health
		lines.append("P%d HP %d/%d %s  %s  inv %.2f" % [k.player_id(), h.current_health, h.max_health,
			"ALIVE" if h.is_alive() else "DEAD", k.state_name(), h.invulnerability_left()])
		lines.append("   atk %s %s  cd %.2f  pow %d  range x%.2f  hits %d" % [c.state_name(),
			AttackDirection.to_name(c.direction), c.cooldown_left(), c.stats.attack_power,
			c.stats.range_multiplier, c.hit_log.size()])
	if rig != null and is_instance_valid(rig):
		lines.append("camera %s" % SplitScreenRig.Mode.keys()[rig.mode])
	lines.append("DEV F1/F2 hurt  F3 heal  F4/F5 kill  F6 reset  F7 hide  F9 hitboxes")
	_label.text = "\n".join(lines)
