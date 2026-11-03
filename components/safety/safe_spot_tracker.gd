class_name SafeSpotTracker
extends Node2D
## Per-knight safe position and fall handling (child "SafeSpot" of the knight).
##
## A position becomes the safe position only once the knight has stayed on safe ground for
## the CONFIG.safe_ground_frames frames AFTER it (the position from that many frames ago is
## committed). Hazard overlap signals arrive a frame late, so a position at the edge of a
## hazard is discarded before it can be committed. Safe means:
## alive, grounded (GROUNDED or CROUCHING, on the floor), not standing on the other knight,
## not inside any hazard, not on a platform in the "unsafe_ground" group (moving, timed,
## disappearing, collapsing), and above the level's fall line.
##
## resolve_fall() is the one fall consequence: 1 FALL damage (unblockable), then a teleport
## to the last safe position (or the spawn point), with short respawn protection if alive.
## It runs once per fall, whether triggered by a FallBoundary hazard or by the fall line.

signal fell(knight: Knight, survived: bool)

const CONFIG := preload("res://resources/config/hazard_config.tres")
const UNSAFE_GROUND := &"unsafe_ground"
## Development-only marker at each knight's last safe position.
static var debug_visible := false

var last_safe_position := Vector2.ZERO
var has_safe_position := false
var spawn_position := Vector2.ZERO
## Number of hazards the knight is currently inside (maintained by Hazard).
var hazard_contacts := 0
var fall_count := 0

var _knight: Knight
## Positions from consecutive safe frames, oldest first (at most CONFIG.safe_ground_frames).
var _candidates := PackedVector2Array()
var _resolving := false
var _fall_line := INF
var _fall_line_known := false


## Called by the knight at the end of its _ready().
func setup(knight: Knight) -> void:
	_knight = knight
	spawn_position = knight.global_position
	last_safe_position = spawn_position
	top_level = true  # draws its marker in world space


func _physics_process(_delta: float) -> void:
	if _knight == null:
		return
	if is_safe_now():
		_candidates.append(_knight.global_position)
		if _candidates.size() >= CONFIG.safe_ground_frames:
			last_safe_position = _candidates[0]
			has_safe_position = true
			_candidates.remove_at(0)
	else:
		_candidates.clear()
	if not _resolving and _knight.global_position.y > fall_line():
		resolve_fall(null)
	if debug_visible and OS.is_debug_build():
		queue_redraw()


## True when the knight's current position may become its respawn point.
func is_safe_now() -> bool:
	if _knight.is_dead() or hazard_contacts > 0:
		return false
	if _knight.state != Knight.State.GROUNDED and _knight.state != Knight.State.CROUCHING:
		return false
	if not _knight.is_on_floor() or _knight.floor_kind == Knight.FloorKind.KNIGHT:
		return false
	if _knight.global_position.y > fall_line():
		return false
	for i in _knight.get_slide_collision_count():
		var collision := _knight.get_slide_collision(i)
		if collision.get_normal().dot(_knight.up_direction) < 0.7:
			continue
		var collider := collision.get_collider() as Node
		if collider != null and collider.is_in_group(UNSAFE_GROUND):
			return false
	return true


## Y below which the knight has fallen out of the level: the level's CameraBounds bottom
## plus CONFIG.fall_margin. INF when the level has no CameraBounds.
func fall_line() -> float:
	if not _fall_line_known:
		_fall_line_known = true
		for node in get_tree().get_nodes_in_group(CameraBounds.GROUP):
			var level := _knight.get_parent()
			while level != null and not level.is_ancestor_of(node):
				level = level.get_parent()
			if level != null and level != get_tree().root:
				_fall_line = (node as CameraBounds).get_world_rect().end.y + CONFIG.fall_margin
				break
	return _fall_line


func enter_hazard() -> void:
	hazard_contacts += 1


func exit_hazard() -> void:
	hazard_contacts = maxi(hazard_contacts - 1, 0)


## The fall consequence. Safe to call more than once in a frame: only the first counts.
func resolve_fall(source: Node) -> void:
	if _resolving or _knight == null:
		return
	_resolving = true
	fall_count += 1
	var was_alive := _knight.health.is_alive()
	if was_alive:
		_knight.health.take_damage(DamageEvent.create(CONFIG.fall_damage, DamageEvent.Category.FALL, source))
	var survived := _knight.health.is_alive()
	_knight.teleport_to(last_safe_position if has_safe_position else spawn_position)
	_candidates.clear()
	if survived:
		_knight.health.start_invulnerability(CONFIG.respawn_protection)
		FloatingText.spawn(_knight, Vector2(0, -30), "-1 FALL", Color(1.0, 0.55, 0.45))
	Sfx.play(Sfx.HURT, _knight, -6.0, 0.8)
	_resolving = false
	fell.emit(_knight, survived)


func _draw() -> void:
	if not (debug_visible and OS.is_debug_build()) or _knight == null:
		return
	var p := last_safe_position
	var colour := _knight.profile.tunic_color.lightened(0.3) if _knight.profile else Color.WHITE
	draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), colour, 1.0)
	draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), colour, 1.0)
