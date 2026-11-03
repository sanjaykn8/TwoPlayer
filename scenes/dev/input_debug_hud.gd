class_name InputDebugHud
extends CanvasLayer
## Development overlay for Phase 1 keyboard testing.
## Shows every gameplay action per player, movement state, health, the resolved attack
## direction, and a raw key-event log (including the Left/Right location Windows reports).
## It only reads input; it never consumes events.

const LOG_LENGTH := 6

var _knights: Array[Knight] = []
var _panels: Array[Label] = []
var _log_label: Label
var _log: PackedStringArray = []
var _alt_counts := {"LEFT": 0, "RIGHT": 0, "UNSPECIFIED": 0}
var _attack_counts := {1: 0, 2: 0}


func _ready() -> void:
	layer = 10
	_panels.append(_make_panel(Vector2(4, 4), HORIZONTAL_ALIGNMENT_LEFT))
	_panels.append(_make_panel(Vector2(456, 4), HORIZONTAL_ALIGNMENT_LEFT))
	_log_label = _make_panel(Vector2(196, 4), HORIZONTAL_ALIGNMENT_LEFT, Vector2(256, 0))
	var help := Label.new()
	help.add_theme_font_size_override(&"font_size", 8)
	help.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.8))
	help.add_theme_color_override(&"font_outline_color", Color.BLACK)
	help.add_theme_constant_override(&"outline_size", 2)
	help.text = "DEV  F1/F2 hurt P1/P2  F3/F4 heal  F6 reset positions  F7 hide HUD"
	help.position = Vector2(150, 350)
	add_child(help)
	_find_knights.call_deferred()


func _find_knights() -> void:
	for node in get_tree().get_nodes_in_group(Knight.GROUP):
		_knights.append(node as Knight)
	_knights.sort_custom(func(a: Knight, b: Knight) -> bool: return a.player_id() < b.player_id())
	for k in _knights:
		k.attack_requested.connect(_on_attack.bind(k))


func _make_panel(at: Vector2, align: HorizontalAlignment, min_size := Vector2(180, 0)) -> Label:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.position = at
	panel.custom_minimum_size = min_size
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", 8)
	label.horizontal_alignment = align
	panel.add_child(label)
	add_child(panel)
	return label


func _process(_delta: float) -> void:
	for i in mini(_knights.size(), _panels.size()):
		_panels[i].text = _describe(_knights[i])
	var counts := "P1 V:%d   P2 Alt L:%d R:%d ?:%d" % [_attack_counts[1],
		_alt_counts["LEFT"], _alt_counts["RIGHT"], _alt_counts["UNSPECIFIED"]]
	_log_label.text = counts + "\n" + "\n".join(_log)


func _describe(k: Knight) -> String:
	var p := k.profile
	var held := "%s %s %s %s %s" % [
		_flag(p.action_left, "L"), _flag(p.action_right, "R"), _flag(p.action_up, "U"),
		_flag(p.action_down, "D"), _flag(p.action_attack, "ATK")]
	var hp := "HP %d/%d" % [k.health.current_health, k.health.max_health]
	var floor_name: String = Knight.FloorKind.keys()[k.floor_kind]
	return "%s  %s\n%s  floor %s\nkeys %s\nfacing %s  atk #%d %s" % [
		p.display_name.to_upper(), hp, k.state_name(), floor_name, held,
		"R" if k.facing > 0 else "L", k.attack_count, AttackDirection.to_name(k.last_attack_direction)]


func _flag(action: StringName, text: String) -> String:
	return text if Input.is_action_pressed(action) else ".".repeat(text.length())


func _on_attack(_direction: AttackDirection.Direction, knight: Knight) -> void:
	_attack_counts[knight.player_id()] += 1


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var location: String = ["UNSPECIFIED", "LEFT", "RIGHT"][key.location]
	if key.pressed and key.physical_keycode == KEY_ALT:
		_alt_counts[location] += 1
	var line := "%s %s phys=%s loc=%s%s" % [
		"down" if key.pressed else "up  ",
		OS.get_keycode_string(key.keycode),
		OS.get_keycode_string(key.physical_keycode),
		location,
		" +alt" if key.alt_pressed and key.physical_keycode != KEY_ALT else ""]
	_log.append(line)
	if _log.size() > LOG_LENGTH:
		_log.remove_at(0)
