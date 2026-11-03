@tool
class_name PuzzleGate
extends PuzzleSource
## A stone gate (door) driven by a `controller` PuzzleSource. Origin = top-left; `width`
## pixels by `height_tiles` x 16. Solid (world layer) ONLY while fully CLOSED.
##   FOLLOW  open while the controller is active; after it turns off, stays open for
##           `close_delay` s (shown as a warning), then closes
##   LATCH   opens the first time the controller is active and stays open (saved with the run)
##   TIMED   each activation (rising edge) opens it for `open_time` s; the last `warning_time`
##           s blink; a new activation restarts the time (controlled reopening)
## Safety: a gate never closes into a knight or an enemy. When it should close it waits
## (WAITING, still blinking) until its doorway plus a small margin is empty, and while it is
## sliding shut it re-checks every frame and bounces back open if anything enters. It never
## damages anyone. Its countdown bar shows the time left.

signal state_changed(state: PuzzleGate.State)

enum Mode { FOLLOW, LATCH, TIMED }
enum State { CLOSED, OPENING, OPEN, WARNING, WAITING, CLOSING }

## Drawn portcullis colours (the bundle has no gate art; walls use the grey stone brick).
const BACKING := Color(0.11, 0.1, 0.13, 0.85)
const BAR := Color("6f7480")
const BAR_LIGHT := Color("b9bcc6")
const FRAME := Color("2b2833")
const BAR_BACK := Color(0.1, 0.1, 0.12, 0.8)
const BAR_OK := Color(0.45, 0.9, 1.0)
const BAR_WARN := Color(1.0, 0.35, 0.25)

@export var controller: NodePath
@export var mode := Mode.FOLLOW
@export var width := 16.0:
	set(value):
		width = maxf(value, 4.0)
		_rebuild()
@export_range(1, 16) var height_tiles := 3:
	set(value):
		height_tiles = value
		_rebuild()
@export var open_time := 4.0
@export var warning_time := 1.5
@export var close_delay := 0.0
@export var start_open := false

var state := State.CLOSED
## 0 closed .. 1 open (visual).
var open_amount := 0.0
## TIMED / FOLLOW delay: seconds until the gate wants to close.
var time_left := 0.0
var opens := 0
var closes := 0
## Times a closing was postponed or reversed because the doorway was occupied.
var blocked_closings := 0

var _source: PuzzleSource
var _body: StaticBody2D
var _shape: CollisionShape2D
var _latched := false


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_source = resolve_source(controller)
	if _source != null:
		_source.changed.connect(_on_controller_changed)
		_source.pulsed.connect(_on_controller_pulsed.unbind(1))
	restore_saved_state()
	if start_open or (_source != null and _source.is_active() and mode != Mode.TIMED):
		_snap_open()


func height_px() -> float:
	return height_tiles * 16.0


func is_open() -> bool:
	return state != State.CLOSED


func is_solid() -> bool:
	return _shape != null and not _shape.disabled


func state_name() -> String:
	return State.keys()[state]


func debug_state() -> String:
	var text := "%s %s" % [Mode.keys()[mode], state_name()]
	if state == State.OPEN or state == State.WARNING:
		if mode == Mode.TIMED or (mode == Mode.FOLLOW and time_left > 0.0):
			text += " %.1fs" % time_left
	return text


## Doorway (plus margin) in global coordinates: must be empty before the gate may close.
func doorway_rect() -> Rect2:
	var margin := CONFIG.gate_clear_margin
	return Rect2(global_position + Vector2(-margin, 0), Vector2(width + margin * 2.0, height_px()))


func is_doorway_occupied() -> bool:
	return SpaceQuery.rect_occupied(get_world_2d(), doorway_rect(), SpaceQuery.OCCUPANT_MASK, [_body.get_rid()])


## Opens it now (also usable by scripts); TIMED gates restart their timer.
func open() -> void:
	if mode == Mode.TIMED:
		time_left = open_time
	if state == State.OPEN:
		return
	if state != State.OPENING:
		opens += 1
		_feedback(Sfx.TAP, 0.6)
	_enter(State.OPENING)
	_set_solid(false)


func reset_source() -> void:
	if mode == Mode.LATCH and _latched:
		return
	_request_close()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var step := delta / CONFIG.gate_move_time
	match state:
		State.OPENING:
			open_amount = minf(open_amount + step, 1.0)
			if open_amount >= 1.0:
				_enter(State.WARNING if _closing_countdown() and time_left <= warning_time else State.OPEN)
		State.OPEN, State.WARNING:
			if _closing_countdown():
				time_left = maxf(time_left - delta, 0.0)
				if state == State.OPEN and time_left <= warning_time:
					_enter(State.WARNING)
				if time_left == 0.0:
					_request_close()
		State.WAITING:
			if not is_doorway_occupied():
				_enter(State.CLOSING)
		State.CLOSING:
			if is_doorway_occupied():
				blocked_closings += 1
				_enter(State.OPENING)  # something stepped in: bounce back open
			else:
				open_amount = maxf(open_amount - step, 0.0)
				if open_amount <= 0.0:
					_enter(State.CLOSED)
					closes += 1
					_set_solid(true)
					_feedback(Sfx.TAP, 0.5)
	queue_redraw()


## True while a timer is counting toward closing (TIMED, or FOLLOW after release).
func _closing_countdown() -> bool:
	if mode == Mode.TIMED:
		return true
	if mode == Mode.FOLLOW:
		return _source == null or not _source.is_active()
	return false


func _request_close() -> void:
	if state == State.CLOSED or state == State.CLOSING:
		return
	if is_doorway_occupied():
		if state != State.WAITING:
			blocked_closings += 1
		_enter(State.WAITING)
	else:
		_enter(State.CLOSING)


func _on_controller_changed(active: bool) -> void:
	match mode:
		Mode.FOLLOW:
			if active:
				time_left = 0.0
				open()
			elif state != State.CLOSED:
				time_left = close_delay
				if close_delay <= 0.0:
					_request_close()
				elif state == State.OPEN:
					_enter(State.WARNING)
		Mode.LATCH:
			if active and not _latched:
				_latched = true
				open()
				save_state()


func _on_controller_pulsed() -> void:
	if mode == Mode.TIMED:
		open()


func _snap_open() -> void:
	open_amount = 1.0
	_set_solid(false)
	_enter(State.OPEN)
	if mode == Mode.TIMED:
		time_left = open_time


func _enter(next: State) -> void:
	if next == state:
		return
	state = next
	_set_active(next != State.CLOSED)
	state_changed.emit(next)


func _set_solid(on: bool) -> void:
	if _shape != null:
		_shape.set_deferred(&"disabled", not on)


func capture_live() -> Dictionary:
	if mode == Mode.LATCH or state == State.CLOSED:
		return {}
	return {"open": true, "time_left": time_left}


## Restores an open FOLLOW/TIMED gate with its remaining time; it then closes through the
## normal safe path (waiting for a clear doorway).
func apply_live(data: Dictionary) -> void:
	if mode == Mode.LATCH or not data.get("open", false):
		return
	_snap_open()
	time_left = clampf(float(data.get("time_left", 0.0)), 0.0, maxf(open_time, close_delay))
	if mode == Mode.TIMED and time_left <= warning_time:
		_enter(State.WARNING)


func _save_state() -> Dictionary:
	return {"open": true} if mode == Mode.LATCH and _latched else {}


func _apply_saved_state(saved: Dictionary) -> void:
	if mode == Mode.LATCH and saved.get("open", false):
		_latched = true
		_snap_open()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _body == null:
		_body = StaticBody2D.new()
		_body.collision_layer = 1  # world: blocks knights, slimes and attacks (line of sight)
		_body.collision_mask = 0
		_shape = CollisionShape2D.new()
		_body.add_child(_shape)
		add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	var box := RectangleShape2D.new()
	box.size = Vector2(width, height_px())
	_shape.shape = box
	_shape.position = box.size * 0.5
	_shape.disabled = state != State.CLOSED and not Engine.is_editor_hint()
	queue_redraw()


func _draw() -> void:
	var h := height_px()
	var shift := roundf(open_amount * h)
	# An iron portcullis that slides up into the wall; only the part below its top is drawn.
	var body_top := -shift
	var visible_h := h - shift
	if visible_h > 0.0:
		draw_rect(Rect2(0, 0, width, visible_h), BACKING)
		var x := 2.0
		while x < width - 1.0:
			draw_rect(Rect2(x, 0, 2, visible_h), BAR)
			draw_rect(Rect2(x, 0, 1, visible_h), BAR_LIGHT)
			x += 5.0
		var y := body_top + 6.0
		while y < visible_h - 3.0:
			if y >= 0.0:
				draw_rect(Rect2(0, y, width, 2), BAR)
				draw_rect(Rect2(0, y, width, 1), BAR_LIGHT)
			y += 12.0
		draw_rect(Rect2(0, maxf(visible_h - 2.0, 0.0), width, 2), BAR_LIGHT.darkened(0.3))
		draw_rect(Rect2(0, 0, 1, visible_h), FRAME)
		draw_rect(Rect2(width - 1, 0, 1, visible_h), FRAME)
	# Countdown bar above the doorway (TIMED, or a FOLLOW gate's close delay).
	var counting := (state == State.OPEN or state == State.WARNING or state == State.WAITING) and _closing_countdown()
	var total := open_time if mode == Mode.TIMED else close_delay
	if counting and total > 0.0:
		var frac := clampf(time_left / total, 0.0, 1.0)
		var warn := state == State.WARNING or state == State.WAITING
		var blink := warn and int(Time.get_ticks_msec() / 120) % 2 == 0
		draw_rect(Rect2(-2, -5, width + 4, 3), BAR_BACK)
		draw_rect(Rect2(-1, -4, roundf((width + 2) * frac), 1), BAR_WARN if warn else BAR_OK)
		if blink:
			draw_rect(Rect2(-2, -5, width + 4, 3), Color(1, 0.3, 0.2, 0.5))
	elif state == State.WAITING:
		if int(Time.get_ticks_msec() / 120) % 2 == 0:
			draw_rect(Rect2(-2, -5, width + 4, 3), BAR_WARN)
	_draw_debug(Vector2(0, -8))
