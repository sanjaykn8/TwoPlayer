@tool
class_name PressurePlate
extends PuzzleSource
## A floor plate pressed by knights STANDING on it (on the floor, alive). Origin = left end of
## the plate's top surface (place it on the floor surface); `width` in pixels.
##   HOLD   active while enough knights stand on it (the default "hold the light" plate)
##   LATCH  active forever once pressed (saved with the run)
##   TIMED  pressing starts `active_time` seconds of activation; step off and on to restart
## `required_count` knights must stand on THIS plate together (2 = a heavy plate).
## `allowed_player` restricts it to one knight (its colour is shown on the plate).
## Knights are tracked by identity and re-validated every physics frame, so a knight that
## dies, is removed, teleports away or jumps off releases the plate immediately.

enum Mode { HOLD, LATCH, TIMED }

const P1_PROFILE := preload("res://resources/players/p1_profile.tres")
const P2_PROFILE := preload("res://resources/players/p2_profile.tres")
const BASE := Color("3b3a45")
const ANY_TOP := Color("d9a441")
const PRESSED_GLOW := Color(1.0, 0.95, 0.6)

@export var width := 32.0:
	set(value):
		width = maxf(value, 8.0)
		_rebuild()
@export var mode := Mode.HOLD
@export_range(1, 2) var required_count := 1
## 0 either knight, 1 Player One only, 2 Player Two only.
@export_range(0, 2) var allowed_player := 0
@export var active_time := 3.0
## Living, non-staggered slimes also press it (off by default: enemies never trigger puzzles).
@export var accept_slimes := false

## Player ids standing on the plate this frame (sorted).
var occupants: Array[int] = []
var pressed := false
var press_count := 0
## Seconds left for a TIMED plate.
var time_left := 0.0

var _tracked := {}  # instance id -> Node2D (Knight or Slime)
var _activators: Array[int] = []
var _sensor: Area2D
var _sensor_shape: CollisionShape2D
var _slime_weight := 0


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_sensor.area_entered.connect(_on_area_entered)
	_sensor.area_exited.connect(_on_area_exited)
	restore_saved_state()


func active_players() -> Array[int]:
	return occupants.duplicate() if mode == Mode.HOLD else _activators.duplicate()


func reset_source() -> void:
	if mode == Mode.TIMED:
		time_left = 0.0
		_set_active(false)


func debug_state() -> String:
	var text := "%s %s" % [Mode.keys()[mode], "ON" if _active else "off"]
	if mode == Mode.TIMED and _active:
		text += " %.1fs" % time_left
	return text + " %s" % str(occupants)


## Knights and slimes currently overlapping the sensor (not necessarily standing).
func tracked_count() -> int:
	return _tracked.size()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_evaluate()
	if mode == Mode.TIMED and _active:
		time_left = maxf(time_left - delta, 0.0)
		if time_left == 0.0:
			_set_active(false)
	queue_redraw()


func _evaluate() -> void:
	var players: Array[int] = []
	var weight := 0
	for key: int in _tracked.keys():
		var node: Node2D = _tracked[key]
		if not is_instance_valid(node) or not node.is_inside_tree():
			_tracked.erase(key)
			continue
		if node is Knight:
			var knight := node as Knight
			if not _knight_counts(knight):
				continue
			var id := knight.player_id()
			if allowed_player != 0 and id != allowed_player:
				continue
			players.append(id)
			weight += 1
		elif node is Slime:
			var slime := node as Slime
			if not slime.is_dead() and not slime.is_staggered() and slime.is_on_floor():
				weight += 1
	players.sort()
	var credit_moved := players != occupants
	occupants = players
	_slime_weight = weight - players.size()
	var now := weight >= required_count
	if now == pressed:
		if mode == Mode.HOLD:
			_set_active(now)
			if now and credit_moved:
				credit_changed.emit()
		return
	pressed = now
	if now:
		press_count += 1
		_activators = players.duplicate()
		_feedback(Sfx.TAP, 0.9)
		match mode:
			Mode.HOLD:
				_set_active(true)
			Mode.LATCH:
				if not _active:
					_set_active(true)
					save_state()
			Mode.TIMED:
				time_left = active_time
				_set_active(true)
		pulsed.emit(players[0] if not players.is_empty() else 0)
	elif mode == Mode.HOLD:
		_set_active(false)


## A plate needs a living knight standing on it (TriggerZone overrides this).
func _knight_counts(knight: Knight) -> bool:
	return not knight.is_dead() and knight.is_on_floor()


func _save_state() -> Dictionary:
	return {"latched": true} if mode == Mode.LATCH and _active else {}


func _apply_saved_state(state: Dictionary) -> void:
	if mode == Mode.LATCH and state.get("latched", false):
		_set_active(true)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	if hurtbox.entity is Knight or (accept_slimes and hurtbox.entity is Slime):
		_tracked[hurtbox.entity.get_instance_id()] = hurtbox.entity


func _on_area_exited(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox != null and hurtbox.entity != null:
		_tracked.erase(hurtbox.entity.get_instance_id())


func _sensor_rect() -> Rect2:
	return Rect2(0, -CONFIG.plate_sensor_height, width, CONFIG.plate_sensor_height)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _sensor == null:
		_sensor = Area2D.new()
		_sensor.monitorable = false
		_sensor_shape = CollisionShape2D.new()
		_sensor.add_child(_sensor_shape)
		add_child(_sensor, false, Node.INTERNAL_MODE_FRONT)
	_sensor.collision_layer = 0
	_sensor.collision_mask = (1 << 4) | ((1 << 6) if accept_slimes else 0)  # hurtboxes
	var rect := _sensor_rect()
	var box := RectangleShape2D.new()
	box.size = rect.size
	_sensor_shape.shape = box
	_sensor_shape.position = rect.get_center()
	queue_redraw()


func _top_colour() -> Color:
	match allowed_player:
		1:
			return P1_PROFILE.tunic_color.lightened(0.2)
		2:
			return P2_PROFILE.tunic_color.lightened(0.2)
	return ANY_TOP


func _draw() -> void:
	var down := pressed or (_active and mode != Mode.HOLD)
	var top := 2.0 if down else 4.0
	draw_rect(Rect2(-1, -top - 1, width + 2, top + 1), BASE)
	var colour := _top_colour()
	if _active:
		colour = colour.lerp(PRESSED_GLOW, 0.5)
	draw_rect(Rect2(1, -top - 1, width - 2, 2), colour)
	if required_count == 2:  # two notches: needs both knights on this plate
		for x in [width * 0.33, width * 0.66]:
			draw_rect(Rect2(roundf(x), -top, 1, top), colour.darkened(0.4))
	if mode == Mode.TIMED and _active:
		var frac := time_left / maxf(active_time, 0.01)
		draw_rect(Rect2(0, 1, roundf(width * frac), 1), PRESSED_GLOW)
	if Engine.is_editor_hint():
		draw_rect(_sensor_rect(), Color(1, 0.8, 0.2, 0.25))
	_draw_debug(Vector2(0, -12))
