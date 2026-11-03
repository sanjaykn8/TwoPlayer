extends CanvasLayer
## Development overlay for Phase 2 camera testing. Shows the rig's mode, orientation,
## separation ratios against the thresholds, view sizes and resource counters.

var rig: SplitScreenRig

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
	if rig == null or not is_instance_valid(rig):
		return
	var c := rig.config
	var targets := rig.get_targets()
	var p1 := targets[0].global_position if targets.size() == 2 else Vector2.ZERO
	var p2 := targets[1].global_position if targets.size() == 2 else Vector2.ZERO
	var b_rect := rig.view_screen_rect(SplitScreenRig.VIEW_B)
	var lines := PackedStringArray([
		"CAMERA %s  %s" % [SplitScreenRig.Mode.keys()[rig.mode],
			CameraMath.Orientation.keys()[rig.orientation] if rig.is_split() else ""],
		"sep x %.2f  y %.2f   split > %.2f  merge < %.2f" % [rig.separation.x, rig.separation.y,
			c.split_enter_ratio, c.split_exit_ratio],
		"view A %s  view B %s  B render %s" % [_size_text(rig.view_screen_rect(SplitScreenRig.VIEW_A)),
			_size_text(b_rect), "on" if rig.viewport(SplitScreenRig.VIEW_B).render_target_update_mode == SubViewport.UPDATE_ALWAYS else "off"],
		"P1 %d,%d  P2 %d,%d  layout changes %d" % [p1.x, p1.y, p2.x, p2.y, rig.layout_change_count],
		"fps %d  objects %d  nodes %d" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)],
		"DEV F1 P2>tower  F2 P2>far right  F3 P2>P1  F6 reset  F7 hide",
	])
	_label.text = "\n".join(lines)


func _size_text(rect: Rect2i) -> String:
	return "%dx%d" % [rect.size.x, rect.size.y] if rect.size != Vector2i.ZERO else "-"
