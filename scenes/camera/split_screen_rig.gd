class_name SplitScreenRig
extends Control
## Dynamic shared / split-screen camera for the two knights.
##
## The level is attached under ViewA/Viewport/World and is simulated exactly once.
## ViewB/Viewport borrows ViewA's World2D, so it renders the same world through its own
## camera and contains nothing except that camera. In shared mode view B is hidden and its
## render target is disabled, so it costs nothing.
##
## Player One always uses view A (left or top). Player Two always uses view B (right or bottom).
## Decisions come from CameraMath; tunable values from `config` (CameraConfig).

signal mode_changed(mode: Mode)
signal orientation_changed(orientation: CameraMath.Orientation)

enum Mode {
	## One full-screen view following the midpoint.
	SHARED,
	## Two views, each following one knight.
	SPLIT,
	## Still split, while both cameras line up with the upcoming shared view.
	MERGING,
}

const VIEW_A := 0
const VIEW_B := 1

@export var config: CameraConfig

var mode := Mode.SHARED
var orientation := CameraMath.Orientation.SIDE_BY_SIDE
## Latest separation ratio (x, y). See CameraMath.separation_ratio.
var separation := Vector2.ZERO
var bounds := Rect2()
var has_bounds := false
## Number of times the visible layout changed (shared <-> split, or orientation).
var layout_change_count := 0

var _targets: Array[Node2D] = []
var _centers: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _cut: Array[bool] = [true, true]
var _merge_start: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _merge_timer := 0.0
var _merge_elapsed := 0.0
var _orientation_timer := 0.0
var _layout := {}
var _layout_key := []

@onready var world_root: Node2D = $ViewA/Viewport/World
@onready var _views: Array[SubViewportContainer] = [$ViewA, $ViewB]
@onready var _viewports: Array[SubViewport] = [$ViewA/Viewport, $ViewB/Viewport]
@onready var _cameras: Array[Camera2D] = [$ViewA/Viewport/Camera, $ViewB/Viewport/Camera]
@onready var _divider: ColorRect = $Divider


func _ready() -> void:
	# Run after the knights have moved this tick.
	process_physics_priority = 100
	if config == null:
		config = CameraConfig.new()
	for problem in config.validate():
		push_error("CameraConfig: " + problem)
	_viewports[VIEW_B].world_2d = _viewports[VIEW_A].world_2d
	for viewport in _viewports:
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		viewport.snap_2d_transforms_to_pixel = true
		viewport.snap_2d_vertices_to_pixel = true
		viewport.physics_object_picking = false
	for camera in _cameras:
		# Physics interpolation requires physics-process cameras; the rig moves them in _physics_process.
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		camera.zoom = Vector2.ONE * config.zoom
		camera.position_smoothing_enabled = false
		camera.ignore_rotation = true
	_divider.color = config.divider_color
	resized.connect(_apply_layout)
	_apply_layout()


func _physics_process(delta: float) -> void:
	if _has_valid_targets():
		update_cameras(delta)


# --- Public interface -------------------------------------------------------------

## Moves `world` (a level) into the rendered world and starts following its knights.
func attach_world(world: Node) -> void:
	if world.get_parent() == null:
		world_root.add_child(world)
	else:
		world.reparent(world_root, false)
	refresh_world()


## Finds the knights and CameraBounds inside the attached world, then snaps the cameras.
func refresh_world() -> void:
	var knights: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(&"knights"):
		if world_root.is_ancestor_of(node) and node.has_method(&"player_id"):
			knights.append(node)
	knights.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.player_id() < b.player_id())
	if knights.size() >= 2:
		set_targets(knights[0], knights[1])
	clear_bounds()
	for node in get_tree().get_nodes_in_group(CameraBounds.GROUP):
		if world_root.is_ancestor_of(node):
			set_bounds((node as CameraBounds).get_world_rect())
			break
	snap_to_targets()


## Player One's knight first, Player Two's second.
func set_targets(player_one: Node2D, player_two: Node2D) -> void:
	_targets = [player_one, player_two]


func get_targets() -> Array[Node2D]:
	return _targets


func set_bounds(rect: Rect2) -> void:
	bounds = rect
	has_bounds = true


func clear_bounds() -> void:
	has_bounds = false


func is_split() -> bool:
	return mode != Mode.SHARED


func camera(view: int) -> Camera2D:
	return _cameras[view]


func viewport(view: int) -> SubViewport:
	return _viewports[view]


func camera_center(view: int) -> Vector2:
	return _centers[view]


## The whole screen in world pixels.
func full_view_size() -> Vector2:
	return size / float(config.zoom)


## The screen rectangle of a view, in screen pixels.
func view_screen_rect(view: int) -> Rect2i:
	return _layout.get("a" if view == VIEW_A else "b", Rect2i())


## The world rectangle a view currently shows.
func view_world_rect(view: int) -> Rect2:
	return CameraMath.view_rect(_centers[view].round(), _view_size(view))


## Re-centres all cameras on their targets immediately and picks the right mode.
## Use at level start and after teleports.
func snap_to_targets() -> void:
	if not _has_valid_targets():
		return
	separation = _ratio()
	_merge_timer = 0.0
	_orientation_timer = 0.0
	if CameraMath.should_split(separation, config.split_enter_ratio):
		_set_orientation(CameraMath.preferred_orientation(separation))
		_set_mode(Mode.SPLIT)
		_apply_layout()
		for i in 2:
			_centers[i] = _split_target(i)
	else:
		_set_mode(Mode.SHARED)
		_apply_layout()
		_centers[VIEW_A] = _shared_target()
		_centers[VIEW_B] = _centers[VIEW_A]
	_cut = [true, true]
	_apply_cameras()


## One camera step. Called every physics tick; public so tests can drive it.
func update_cameras(delta: float) -> void:
	separation = _ratio()
	match mode:
		Mode.SHARED:
			_update_shared(delta)
		Mode.SPLIT:
			_update_split(delta)
		Mode.MERGING:
			_update_merging(delta)
	_apply_cameras()


# --- Modes ------------------------------------------------------------------------

func _update_shared(delta: float) -> void:
	if CameraMath.should_split(separation, config.split_enter_ratio) or not _targets_visible_in_shared():
		_begin_split(CameraMath.preferred_orientation(separation))
		return
	var desired := CameraMath.apply_deadzone(_centers[VIEW_A], _shared_target(), config.shared_deadzone)
	desired = _clamp(desired, full_view_size())
	_centers[VIEW_A] = _follow(VIEW_A, desired, config.shared_follow_speed, delta)


func _update_split(delta: float) -> void:
	var desired := CameraMath.next_orientation(orientation, separation, config.orientation_hysteresis)
	if desired != orientation:
		_orientation_timer += delta
		if _orientation_timer >= config.orientation_hold_time:
			_orientation_timer = 0.0
			_set_orientation(desired)
			_apply_layout()
	else:
		_orientation_timer = 0.0
	if CameraMath.should_merge(separation, config.split_exit_ratio):
		_merge_timer += delta
		if _merge_timer >= config.merge_hold_time:
			_begin_merge()
			return
	else:
		_merge_timer = 0.0
	for i in 2:
		_centers[i] = _follow(i, _split_target(i), config.split_follow_speed, delta)


func _update_merging(delta: float) -> void:
	if CameraMath.should_split(separation, config.split_enter_ratio):
		_set_mode(Mode.SPLIT)
		_merge_timer = 0.0
		return
	_merge_elapsed += delta
	var t := clampf(_merge_elapsed / maxf(config.transition_duration, 0.001), 0.0, 1.0)
	var weight := smoothstep(0.0, 1.0, t)
	var shared := _shared_target()
	for i in 2:
		var aligned := CameraMath.sub_view_center(shared, full_view_size(), _view_world_rect_on_screen(i))
		_centers[i] = _merge_start[i].lerp(aligned, weight)
	if t >= 1.0:
		_finish_merge()


## Starts a split. When P1 is on P1's side of the screen (left or top), each camera starts
## on its half of the old shared view, so the first split frame shows the same pixels as the
## last shared frame. When the knights have crossed, the cameras cut to their knights instead.
func _begin_split(next_orientation: CameraMath.Orientation) -> void:
	var shared_center := _centers[VIEW_A]
	_set_orientation(next_orientation)
	_set_mode(Mode.SPLIT)
	_apply_layout()
	var crossed := _assignment_crossed()
	for i in 2:
		if crossed:
			_centers[i] = _split_target(i)
		else:
			_centers[i] = CameraMath.sub_view_center(shared_center, full_view_size(), _view_world_rect_on_screen(i))
		_cut[i] = true
	_merge_timer = 0.0
	_orientation_timer = 0.0


func _begin_merge() -> void:
	_merge_timer = 0.0
	if _assignment_crossed():
		_finish_merge()  # lining up would sweep each camera across the other knight: cut instead
		return
	_set_mode(Mode.MERGING)
	_merge_elapsed = 0.0
	_merge_start = _centers.duplicate()


func _finish_merge() -> void:
	_set_mode(Mode.SHARED)
	_apply_layout()
	_centers[VIEW_A] = _shared_target()
	_cut[VIEW_A] = true


# --- Targets and framing ----------------------------------------------------------

func _has_valid_targets() -> bool:
	return _targets.size() == 2 and is_instance_valid(_targets[0]) and is_instance_valid(_targets[1]) \
		and _targets[0].is_inside_tree() and _targets[1].is_inside_tree()


func _focus(i: int) -> Vector2:
	return _targets[i].global_position + config.follow_offset


func _ratio() -> Vector2:
	return CameraMath.separation_ratio(_focus(0), _focus(1), full_view_size(), config.safe_margin)


func _shared_target() -> Vector2:
	return _clamp(CameraMath.midpoint(_focus(0), _focus(1)), full_view_size())


func _split_target(i: int) -> Vector2:
	return _clamp(_focus(i), _view_size(i))


func _clamp(center: Vector2, view: Vector2) -> Vector2:
	return CameraMath.clamp_center(center, view, bounds) if has_bounds else center


## True when Player One is not on Player One's side of the split (left / top).
func _assignment_crossed() -> bool:
	var p1 := _targets[0].global_position
	var p2 := _targets[1].global_position
	if orientation == CameraMath.Orientation.SIDE_BY_SIDE:
		return p1.x > p2.x
	return p1.y > p2.y


## Both knights' bodies (plus a margin) are inside the current shared view.
func _targets_visible_in_shared() -> bool:
	var m := config.visibility_margin
	var view := CameraMath.view_rect(_centers[VIEW_A], full_view_size()).grow_individual(-m.x, -m.y, -m.x, -m.y)
	var body := config.target_body_size
	for target in _targets:
		var rect := Rect2(target.global_position - Vector2(body.x * 0.5, body.y), body)
		if not view.encloses(rect):
			return false
	return true


func _follow(view: int, target: Vector2, speed: float, delta: float) -> Vector2:
	if _centers[view].distance_to(target) > config.snap_distance:
		_cut[view] = true
		return target
	return CameraMath.smooth(_centers[view], target, speed, delta)


func _view_size(view: int) -> Vector2:
	return Vector2(view_screen_rect(view).size) / float(config.zoom)


## A view's screen rectangle expressed in world pixels (screen / zoom).
func _view_world_rect_on_screen(view: int) -> Rect2:
	var r := view_screen_rect(view)
	return Rect2(Vector2(r.position) / float(config.zoom), Vector2(r.size) / float(config.zoom))


# --- Applying state ---------------------------------------------------------------

func _set_mode(next: Mode) -> void:
	if next == mode:
		return
	mode = next
	mode_changed.emit(mode)


func _set_orientation(next: CameraMath.Orientation) -> void:
	if next == orientation:
		return
	orientation = next
	orientation_changed.emit(orientation)


func _apply_cameras() -> void:
	for i in 2:
		_cameras[i].global_position = _centers[i].round()
		if _cut[i]:
			_cameras[i].reset_physics_interpolation()
			_cut[i] = false


func _apply_layout() -> void:
	var full := Vector2i(size.round())
	if full.x < 2 or full.y < 2:
		return
	var split := mode != Mode.SHARED
	_layout = CameraMath.layout(split, orientation, full, config.divider_width)
	var key := [split, orientation if split else -1, full]
	if key != _layout_key:
		if not _layout_key.is_empty():
			layout_change_count += 1
		_layout_key = key
	_place(VIEW_A, _layout["a"])
	if split:
		_place(VIEW_B, _layout["b"])
	_views[VIEW_B].visible = split
	_viewports[VIEW_B].render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS if split else SubViewport.UPDATE_DISABLED
	var divider: Rect2i = _layout["divider"]
	_divider.visible = split and divider.size.x > 0 and divider.size.y > 0
	_divider.position = Vector2(divider.position)
	_divider.size = Vector2(divider.size)


func _place(view: int, rect: Rect2i) -> void:
	_viewports[view].size = rect.size
	_views[view].position = Vector2(rect.position)
	_views[view].size = Vector2(rect.size)
