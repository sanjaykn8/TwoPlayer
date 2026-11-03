class_name Slime
extends CharacterBody2D
## Shared slime enemy. Green and purple slimes are the same scene and script; only `stats`
## (a SlimeStats resource) differs. The node origin is at the slime's feet.
##
## States: IDLE -> PATROL -> DETECT_PLAYER -> CHASE, plus STAGGERED and DEAD.
## - Detection: knights' hurtboxes inside the DetectionArea circle, confirmed by a
##   line-of-sight ray on the world layer (checked every stats.sense_interval).
## - Targets: nearest visible living knight, with a switch margin (TargetSelector).
## - Movement: ground only. Rays look for a wall or a missing floor ahead; the slime turns
##   (patrol) or stops (chase) instead of walking off or into them.
## - Contact: the ContactArea sends CONTACT DamageEvents to knights' hurtboxes; the knight's
##   HealthComponent applies its invulnerability. No contact damage while staggered or dead.
## - Hits: melee DamageEvents feed SlimeStagger (stagger progress, not health).

signal state_changed(previous: Slime.State, current: Slime.State)
signal target_changed(new_target: Node2D)
signal stagger_progress_changed(progress: int, threshold: int)
signal staggered
signal recovered
## Emitted exactly once, when the slime is killed.
signal defeated(slime: Slime, drop: CoinDropResult)

enum State { IDLE, PATROL, DETECT_PLAYER, CHASE, STAGGERED, DEAD }

const GROUP := &"slimes"
const WORLD_MASK := 1
const FLOOR_MASK := 1 | 2
## Eye height for line of sight, and the point aimed at on a knight (its body centre).
const EYE := Vector2(0, -6)
const TARGET_BODY := Vector2(0, -9)
const HALF_WIDTH := 6.0
## A target more than this far above or below is on another level (cannot be walked to).
const SAME_LEVEL_HEIGHT := 24.0
## Horizontal distance at which a chasing slime stops (it is on the target).
const ARRIVE_DISTANCE := 4.0
const DEATH_TIME := 0.5
const ALERT_TIME := 0.5
const FLASH_TIME := 0.12
## The stagger pulse speeds up during the last seconds as a recovery warning.
const RECOVER_WARNING := 2.0

## Development-only drawing of detection radius, patrol limits and line of sight.
static var debug_visible := false

@export var stats: SlimeStats
## Patrol limits relative to the spawn position (pixels). Equal values make it stand guard.
@export var patrol_left := -48.0
@export var patrol_right := 48.0
## Overrides stats.detection_radius when > 0.
@export var detection_radius_override := 0.0
@export var start_facing_right := false
## Free the node after the death animation. Tests can keep it for inspection.
@export var free_on_death := true
## Stable id within its level (Phase 8 saves). Empty: not saved (development rooms).
## A slime with an id that the run recorded as defeated removes itself when its level loads.
@export var save_id := ""

var state := State.IDLE
## -1 left, 1 right.
var facing := -1
var target: Node2D
## Whether the target was in sight at the last sense check.
var target_visible := false
var stagger: SlimeStagger
## Purple-fruit poison: earns stagger points over time (can stagger, never kills).
var poison := PoisonStatus.new()
## Set once, on death.
var drop_result: CoinDropResult
## Spawn x; patrol limits are relative to it.
var home_x := 0.0

var _state_time := 0.0
var _idle_duration := 0.0
var _recovering := false
var _lost_time := 0.0
var _blocked_time := 0.0
var _ignored: Node2D
var _ignore_time := 0.0
var _hit_pause := 0.0
var _sense_left := 0.0
var _flash_left := 0.0
var _alert_left := 0.0
var _death_left := 0.0
var _candidates: Array[Node2D] = []
var _contact_cooldowns := {}
var _ray := PhysicsRayQueryParameters2D.new()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var contact_area: Area2D = $ContactArea
@onready var detection_area: Area2D = $DetectionArea
@onready var coin_dropper: CoinDropper = $CoinDropper
@onready var alert_label: Label = $Alert
@onready var debug_label: Label = $DebugLabel


func _ready() -> void:
	add_to_group(GROUP)
	if save_id != "" and RunState.current().puzzles.has_state(SaveIds.level_key(self), SaveIds.ENEMY_PREFIX + save_id):
		set_physics_process(false)
		queue_free()  # defeated earlier in this run
		return
	if stats == null:
		push_error("%s: Slime needs a SlimeStats resource" % name)
		set_physics_process(false)
		return
	for problem in stats.validate():
		push_warning("%s (%s): %s" % [name, stats.display_name, problem])
	stagger = SlimeStagger.new(stats.stagger_threshold, stats.effective_stagger_duration())
	sprite.sprite_frames = stats.sprite_frames
	var circle := CircleShape2D.new()
	circle.radius = detection_radius()
	($DetectionArea/Shape as CollisionShape2D).shape = circle
	detection_area.area_entered.connect(_on_detection_entered)
	detection_area.area_exited.connect(_on_detection_exited)
	hurtbox.entity = self
	hurtbox.hit_received.connect(_on_hit_received)
	coin_dropper.min_coins = stats.coin_min
	coin_dropper.max_coins = stats.coin_max
	home_x = global_position.x
	facing = 1 if start_facing_right else -1
	_ray.exclude = [get_rid()]
	_ray.collide_with_areas = false
	_enter(State.IDLE, stats.idle_time)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_update_death(delta)
		return
	_tick_timers(delta)
	if state == State.STAGGERED:
		velocity.x = 0.0
		if stagger.tick(delta):
			_recover()
	else:
		_sense(delta)
		_think(delta)
		if _hit_pause > 0.0:
			velocity.x = 0.0
		var poison_points := poison.tick(delta)
		if poison_points > 0:
			add_stagger_progress(poison_points, poison.source)
	velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	move_and_slide()
	_process_contact(delta)
	_update_visuals()


# --- Public interface -------------------------------------------------------------

func detection_radius() -> float:
	return detection_radius_override if detection_radius_override > 0.0 else stats.detection_radius


func patrol_bounds() -> Vector2:
	return Vector2(home_x + patrol_left, home_x + patrol_right)


func state_name() -> String:
	return State.keys()[state]


func is_dead() -> bool:
	return state == State.DEAD


func is_staggered() -> bool:
	return state == State.STAGGERED


## True when touching this slime can hurt a knight right now.
func can_damage() -> bool:
	return state != State.STAGGERED and state != State.DEAD and stats.contact_damage > 0


## Adds non-melee stagger progress (Phase 5 poison). Can stagger; never kills.
func add_stagger_progress(points: int, source: Node = null) -> SlimeStagger.Outcome:
	if state == State.DEAD:
		return SlimeStagger.Outcome.IGNORED
	var outcome := stagger.add_stagger_progress(points)
	_apply_outcome(outcome, source)
	return outcome


func debug_text() -> String:
	var tgt := "-"
	if target != null and target.has_method(&"player_id"):
		tgt = "P%d%s" % [target.player_id(), "" if target_visible else "?"]
	var text := "%s %s %d/%d tgt %s" % [stats.debug_tag, state_name(), stagger.progress, stagger.threshold, tgt]
	if poison.is_active():
		text += " psn %.1f" % poison.remaining
	if state == State.STAGGERED:
		text += " %.1fs" % stagger.time_left
	return text


# --- Senses -----------------------------------------------------------------------

func _on_detection_entered(area: Area2D) -> void:
	var hurt := area as HurtboxComponent
	if hurt == null or not (hurt.entity is Node2D) or not hurt.entity.is_in_group(&"knights"):
		return
	var knight := hurt.entity as Node2D
	if not _candidates.has(knight):
		_candidates.append(knight)
		_candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.player_id() < b.player_id())


func _on_detection_exited(area: Area2D) -> void:
	var hurt := area as HurtboxComponent
	if hurt != null and hurt.entity is Node2D:
		_candidates.erase(hurt.entity)


func _sense(delta: float) -> void:
	if _ignore_time > 0.0:
		_ignore_time = maxf(_ignore_time - delta, 0.0)
		if _ignore_time == 0.0:
			_ignored = null
	# A dead or removed target is abandoned at once (no grace period).
	if target != null and not _is_valid(target):
		_set_target(null)
	_sense_left -= delta
	if _sense_left <= 0.0:
		_sense_left = stats.sense_interval
		var visible: Array = []
		var distances: Array = []
		for knight in _candidates:
			if _is_valid(knight) and knight != _ignored and _can_see(knight):
				visible.append(knight)
				distances.append(global_position.distance_to(knight.global_position))
		var picked := TargetSelector.pick(target, visible, distances, stats.target_switch_margin) as Node2D
		if picked != null:
			_set_target(picked)
			target_visible = true
			_lost_time = 0.0
		elif target != null:
			target_visible = false
	if target != null and not target_visible:
		_lost_time += delta
		if _lost_time >= stats.lose_target_time:
			_set_target(null)


func _is_valid(node: Node2D) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() \
		and not (node.has_method(&"is_dead") and node.is_dead())


func _can_see(knight: Node2D) -> bool:
	return _ray_clear(global_position + EYE, knight.global_position + TARGET_BODY, WORLD_MASK)


func _set_target(next: Node2D) -> void:
	if next == target:
		return
	var had_target := target != null
	target = next
	target_visible = next != null
	_lost_time = 0.0
	_blocked_time = 0.0
	if next != null and not had_target:
		_alert_left = ALERT_TIME
	target_changed.emit(next)


# --- Behaviour --------------------------------------------------------------------

func _think(delta: float) -> void:
	match state:
		State.IDLE:
			_slow_down(delta)
			if target != null:
				_enter(State.DETECT_PLAYER)
			elif _state_time >= _idle_duration:
				_enter(State.PATROL)
		State.PATROL:
			if target != null:
				_enter(State.DETECT_PLAYER)
			else:
				_patrol(delta)
		State.DETECT_PLAYER:
			_slow_down(delta)
			if target == null:
				_enter(State.PATROL)
			else:
				_face(target.global_position.x - global_position.x)
				if _state_time >= stats.detect_reaction_time:
					_enter(State.CHASE)
		State.CHASE:
			if target == null:
				_enter(State.PATROL)
			else:
				_chase(delta)


func _patrol(delta: float) -> void:
	var bounds := patrol_bounds()
	var x := global_position.x
	var dir := facing
	if x < bounds.x - 1.0:
		dir = 1  # outside the patrol area (after a chase): walk back
	elif x > bounds.y + 1.0:
		dir = -1
	elif x <= bounds.x and facing < 0:
		_turn(1)
		return
	elif x >= bounds.y and facing > 0:
		_turn(-1)
		return
	if _blocked(dir):
		_turn(-dir)
		return
	facing = dir
	velocity.x = move_toward(velocity.x, dir * stats.patrol_speed, stats.acceleration * delta)


func _chase(delta: float) -> void:
	var dx := target.global_position.x - global_position.x
	var unreachable := absf(target.global_position.y - global_position.y) > SAME_LEVEL_HEIGHT
	var dir := 0 if absf(dx) < ARRIVE_DISTANCE else int(signf(dx))
	if dir != 0:
		facing = dir
	var stuck := dir != 0 and _blocked(dir)
	if dir == 0 or stuck:
		_slow_down(delta)
	else:
		velocity.x = move_toward(velocity.x, dir * stats.chase_speed(), stats.acceleration * delta)
	# Waiting at an edge/wall, or under/over a target on another level: give up eventually.
	if stuck or (dir == 0 and unreachable):
		_blocked_time += delta
		if _blocked_time >= stats.give_up_time:
			_ignored = target
			_ignore_time = stats.reacquire_delay
			_set_target(null)
			_enter(State.PATROL)
	else:
		_blocked_time = 0.0


func _turn(dir: int) -> void:
	facing = dir
	velocity.x = 0.0
	_enter(State.IDLE, stats.turn_pause)


func _face(dx: float) -> void:
	if absf(dx) >= 2.0:
		facing = int(signf(dx))


func _slow_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.acceleration * delta)


## A wall or a missing floor directly ahead. Only checked on the ground.
func _blocked(dir: int) -> bool:
	if not is_on_floor():
		return false
	var front := global_position.x + dir * (HALF_WIDTH + 2.0)
	var no_floor := _ray_clear(Vector2(front, global_position.y - 4.0), Vector2(front, global_position.y + 6.0), FLOOR_MASK)
	var wall := not _ray_clear(global_position + Vector2(0, -5), global_position + Vector2(dir * (HALF_WIDTH + 3.0), -5), WORLD_MASK)
	return no_floor or wall


func _ray_clear(from: Vector2, to: Vector2, mask: int) -> bool:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = mask
	return get_world_2d().direct_space_state.intersect_ray(_ray).is_empty()


# --- Hits, stagger, death -----------------------------------------------------------

func _on_hit_received(event: DamageEvent) -> void:
	if state == State.DEAD or event.category != DamageEvent.Category.MELEE:
		return
	var outcome := stagger.register_melee_hit(event.amount, event.attack_id)
	_apply_outcome(outcome, event.source)
	# A poisoned blade poisons on hits that neither stagger nor kill.
	if outcome == SlimeStagger.Outcome.PROGRESS and event.poison_seconds > 0.0:
		poison.apply(event.poison_seconds, event.source)


func _apply_outcome(outcome: SlimeStagger.Outcome, source: Node) -> void:
	match outcome:
		SlimeStagger.Outcome.PROGRESS:
			_flash_left = FLASH_TIME
			_hit_pause = stats.hit_pause
			stagger_progress_changed.emit(stagger.progress, stagger.threshold)
			# Being hit reveals the attacker.
			if target == null and source is Node2D and source.is_in_group(&"knights") and _is_valid(source):
				_set_target(source)
		SlimeStagger.Outcome.STAGGERED:
			_flash_left = FLASH_TIME
			stagger_progress_changed.emit(stagger.progress, stagger.threshold)
			_enter(State.STAGGERED)
			staggered.emit()
		SlimeStagger.Outcome.KILLED:
			_die()


func _recover() -> void:
	_contact_cooldowns.clear()
	_recovering = true
	_enter(State.IDLE, stats.recover_time)
	stagger_progress_changed.emit(0, stagger.threshold)
	recovered.emit()


func _die() -> void:
	if state == State.DEAD:
		return
	var previous := state
	state = State.DEAD
	stagger.dead = true
	poison.clear()
	velocity = Vector2.ZERO
	hurtbox.enabled = false
	contact_area.set_deferred(&"monitoring", false)
	detection_area.set_deferred(&"monitoring", false)
	_candidates.clear()
	target = null
	collision_layer = 0
	_death_left = DEATH_TIME
	alert_label.visible = false
	sprite.play(&"hurt")
	if save_id != "":
		RunState.current().puzzles.set_state(SaveIds.level_key(self), SaveIds.ENEMY_PREFIX + save_id, {"defeated": true})
	drop_result = coin_dropper.drop(global_position + Vector2(0, -6), self, get_parent())
	state_changed.emit(previous, State.DEAD)
	defeated.emit(self, drop_result)


func _update_death(delta: float) -> void:
	if _death_left <= 0.0:
		return
	_death_left = maxf(_death_left - delta, 0.0)
	var t := 1.0 - _death_left / DEATH_TIME
	sprite.scale = Vector2(1.0 + t * 0.5, maxf(1.0 - t, 0.1))
	sprite.modulate = Color(1.6, 1.6, 1.6, 1.0 - t)
	queue_redraw()
	if _death_left == 0.0:
		visible = false
		if free_on_death:
			queue_free()
		else:
			set_physics_process(false)


# --- Save state (Phase 8) ----------------------------------------------------------

## Live state of a living slime. Targets are never saved: they are re-sensed after loading.
func save_state() -> Dictionary:
	return {
		"type": scene_file_path.get_file().get_basename(),
		"x": global_position.x, "y": global_position.y,
		"facing": facing, "home_x": home_x,
		"stagger_progress": stagger.progress,
		"staggered": stagger.staggered,
		"stagger_left": stagger.time_left,
		"poison_left": poison.remaining,
	}


## Validates, then applies a saved live state. Returns false (and changes nothing) on bad data.
func restore_state(data: Dictionary) -> bool:
	for key in ["x", "y", "facing", "home_x", "stagger_progress", "staggered", "stagger_left", "poison_left"]:
		if not data.has(key):
			return false
	var left := float(data.stagger_left)
	var progress := int(data.stagger_progress)
	var poison_left := float(data.poison_left)
	if left < 0.0 or left > stagger.duration + 0.01 or progress < 0 or progress > 99 or poison_left < 0.0 or poison_left > 60.0:
		return false
	global_position = Vector2(float(data.x), float(data.y))
	velocity = Vector2.ZERO
	facing = 1 if int(data.facing) >= 0 else -1
	home_x = float(data.home_x)
	_set_target(null)
	_candidates.clear()
	stagger.progress = progress
	poison.clear()
	if bool(data.staggered) and left > 0.0:
		_enter(State.STAGGERED)  # clears poison, as a fresh stagger does
		stagger.staggered = true
		stagger.time_left = left
	else:
		stagger.staggered = false
		stagger.time_left = 0.0
		poison.apply(poison_left)
		_enter(State.IDLE, stats.idle_time)
	reset_physics_interpolation()
	return true


# --- Contact damage -----------------------------------------------------------------

func _process_contact(delta: float) -> void:
	for key in _contact_cooldowns.keys():
		_contact_cooldowns[key] -= delta
		if _contact_cooldowns[key] <= 0.0:
			_contact_cooldowns.erase(key)
	if not can_damage():
		return
	for area in contact_area.get_overlapping_areas():
		var hurt := area as HurtboxComponent
		if hurt == null or not hurt.enabled:
			continue
		var key := hurt.get_instance_id()
		if _contact_cooldowns.has(key):
			continue
		_contact_cooldowns[key] = stats.contact_interval
		hurt.receive_hit(DamageEvent.create(stats.contact_damage, DamageEvent.Category.CONTACT, self))


# --- State and presentation ---------------------------------------------------------

func _enter(next: State, idle_duration := 0.0) -> void:
	var previous := state
	state = next
	_state_time = 0.0
	_blocked_time = 0.0
	if next == State.IDLE:
		_idle_duration = idle_duration
	else:
		_recovering = false
	if next == State.STAGGERED:
		poison.clear()
		velocity.x = 0.0
		_hit_pause = 0.0
		_alert_left = 0.0
		_set_target(null)
	if previous != next:
		state_changed.emit(previous, next)


func _tick_timers(delta: float) -> void:
	_state_time += delta
	_hit_pause = maxf(_hit_pause - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_alert_left = maxf(_alert_left - delta, 0.0)


func _update_visuals() -> void:
	sprite.flip_h = facing > 0
	var anim := &"idle"
	match state:
		State.STAGGERED:
			anim = &"stagger"
		State.IDLE:
			anim = &"recover" if _recovering else &"idle"
		State.PATROL:
			anim = &"move"
		State.CHASE:
			anim = &"chase"
	if _flash_left > 0.0:
		anim = &"hurt"
	if sprite.animation != anim:
		sprite.play(anim)
	var tint := Color.WHITE
	if _flash_left > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	elif state == State.STAGGERED:
		var speed := 14.0 if stagger.time_left < RECOVER_WARNING else 5.0
		tint = Color.WHITE.lerp(Color(1.7, 1.7, 1.9), 0.5 + 0.5 * sin(_state_time * speed))
	elif poison.is_active():
		tint = Color.WHITE.lerp(Color(0.75, 1.35, 0.6), 0.5 + 0.5 * sin(_state_time * 8.0))
	sprite.modulate = tint
	alert_label.visible = _alert_left > 0.0 and (state == State.DETECT_PLAYER or state == State.CHASE)
	var show_debug := debug_visible and OS.is_debug_build()
	debug_label.visible = show_debug
	if show_debug:
		debug_label.text = debug_text()
	if state == State.STAGGERED or poison.is_active() or show_debug:
		queue_redraw()


func _draw() -> void:
	if state == State.STAGGERED:
		# Two small "dizzy" stars circling above a staggered slime.
		for i in 2:
			var a := _state_time * 4.0 + PI * i
			var p := Vector2(cos(a) * 7.0, -17.0 + sin(a) * 2.0).round()
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.95, 0.4))
	if poison.is_active():
		# Small rising poison bubbles.
		for i in 2:
			var y := -14.0 - fmod(_state_time * 10.0 + i * 5.0, 10.0)
			draw_rect(Rect2(Vector2(-3 + i * 5, y).round(), Vector2(2, 2)), Color(0.6, 1.0, 0.45, 0.9))
	if not (debug_visible and OS.is_debug_build()) or state == State.DEAD:
		return
	draw_arc(EYE, detection_radius(), 0.0, TAU, 48, Color(1, 1, 0, 0.35), 1.0)
	var bounds := patrol_bounds() - Vector2(global_position.x, global_position.x)
	draw_line(Vector2(bounds.x, 1), Vector2(bounds.y, 1), Color(0.2, 0.6, 1.0, 0.9), 1.0)
	if target != null and is_instance_valid(target):
		draw_line(EYE, to_local(target.global_position + TARGET_BODY), Color(0, 1, 0, 0.8) if target_visible else Color(1, 0, 0, 0.8), 1.0)
	var probe_x := facing * (HALF_WIDTH + 2.0)
	draw_line(Vector2(probe_x, -4), Vector2(probe_x, 6), Color(1, 0.5, 0, 0.9), 1.0)
