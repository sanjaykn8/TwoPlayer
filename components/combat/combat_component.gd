class_name CombatComponent
extends Node2D
## Melee attack state machine for one knight: IDLE -> ATTACKING (windup, then hit frames)
## -> ATTACK_RECOVERY -> IDLE. Both knights use their own instance, so their attacks never
## interact. All timings come from CombatConfig; power and range from CombatStats.
##
## Two attack strengths share the timeline:
##   light  a press of attack (the original slash)
##   heavy  keep attack held after a press for `charge_time`, then release: more power and
##          reach, breaks shields and cracked blocks, longer recovery
## Co-op strike: when the other knight hit the same target within `coop_window`, this hit
## gains `coop_bonus` power and is flagged `coop`.
##
## Place as a direct child of the attacker at its origin, with children:
##   Hitbox (HitboxComponent) and Weapon (Sprite2D, 4-frame knife slash facing right; only
##   shown for up and down attacks, the knight's own animation draws the side slashes).

signal attack_started(attack_id: int, direction: AttackDirection.Direction)
signal hit_window_opened(attack_id: int)
signal hit_window_closed(attack_id: int)
signal attack_finished(attack_id: int)
signal hit_landed(target: Node, event: DamageEvent)
## A heavy slash started (after attack_started).
signal heavy_started(attack_id: int, direction: AttackDirection.Direction)
## Holding attack has charged a heavy slash; releasing now strikes.
signal charge_ready
signal coop_strike(target: Node)
## The attack timeline advanced: the attacker should show visual_pose() now.
signal pose_updated

enum State { IDLE, ATTACKING, ATTACK_RECOVERY }

## Small tolerance so frame-based timing is stable against float rounding.
const EPSILON := 0.0001

@export var config: CombatConfig

var state := State.IDLE
## When false (attacker dead or disabled) no attack can start.
var enabled := true
var stats: CombatStats
## Id of the current or most recent attack (unique across all attackers).
var attack_id := 0
var direction := AttackDirection.Direction.RIGHT
var profile := HitboxGeometry.Profile.SIDE
## The current or most recent attack is a charged heavy slash.
var heavy := false
## Seconds attack has been held since the press that started charging.
var charge := 0.0
var charge_is_ready := false
## Entities damaged by the current attack, in hit order.
var targets_hit: Array[Node] = []
## Every hit this component has ever landed: {attack_id, target, amount} (for testing/logging).
var hit_log: Array[Dictionary] = []

var _attacker: Node2D
var _attacker_player_id := 0
var _body_height := func() -> float: return 18.0
var _side := 1
var _elapsed := 0.0
var _windup := 0.05
var _active := 0.1
var _cooldown := 0.3
## The tick an attack starts on counts as elapsed time 0, so the cooldown spans exactly
## `cooldown` seconds of ticks between two attack starts.
var _skip_next_tick := false
var _hit_ids := {}
var _buffered := false
var _buffered_direction := AttackDirection.Direction.RIGHT
var _buffered_grounded := false
var _charging := false
var _charge_direction := AttackDirection.Direction.RIGHT
var _charge_grounded := false

static var _next_attack_id := 1
## Recent hits per target for co-op strikes: target instance id -> [physics frame, player id].
static var _recent_hits := {}

@onready var hitbox: HitboxComponent = $Hitbox
@onready var weapon: Sprite2D = $Weapon


func _ready() -> void:
	if config == null:
		config = CombatConfig.new()
	for problem in config.validate():
		push_error("CombatConfig: " + problem)
	if stats == null:
		stats = CombatStats.from_config(config)
	hitbox.hit_mask = config.hit_mask
	hitbox.obstruction_mask = config.obstruction_mask
	weapon.visible = false
	_set_timeline(false)
	if _attacker == null:
		_attacker = get_parent() as Node2D


## `body_height` returns the attacker's current body height (it changes when crouching).
func setup(attacker: Node2D, player_id: int, body_height: Callable) -> void:
	_attacker = attacker
	_attacker_player_id = player_id
	_body_height = body_height


## Starts an attack now if possible, otherwise buffers it when the cooldown is nearly over.
## `grounded` selects the low forward slash for a DOWN attack on the ground (D-2).
## Every press also starts charging: keep the button held to prepare a heavy slash.
func request_attack(attack_direction: AttackDirection.Direction, grounded: bool) -> bool:
	if not enabled:
		return false
	_charging = true
	charge = 0.0
	charge_is_ready = false
	_charge_direction = attack_direction
	_charge_grounded = grounded
	if state == State.IDLE:
		_start(attack_direction, grounded, false, false)
		return true
	if cooldown_left() <= config.input_buffer_time + EPSILON:
		_buffered = true
		_buffered_direction = attack_direction
		_buffered_grounded = grounded
	return false


## Called every physics tick by the attacker with the attack button state and the direction
## a heavy slash would take now. Releasing a charged button strikes the heavy slash.
func update_charge(held: bool, attack_direction: AttackDirection.Direction, grounded: bool, delta: float) -> void:
	if not _charging:
		return
	_charge_direction = attack_direction
	_charge_grounded = grounded
	if held:
		charge += delta
		if not charge_is_ready and charge >= config.charge_time - EPSILON and enabled:
			charge_is_ready = true
			charge_ready.emit()
		return
	var strike := charge_is_ready and enabled and state != State.ATTACKING
	_reset_charge()
	if strike:
		_buffered = false
		if state != State.IDLE:
			weapon.visible = false
			attack_finished.emit(attack_id)  # the heavy slash cuts the recovery short
		_start(_charge_direction, _charge_grounded, false, true)


## Stops any attack immediately (death, disable, scene reset).
func cancel() -> void:
	var was_attacking := state != State.IDLE
	_set_hitbox_open(false)
	weapon.visible = false
	_buffered = false
	_reset_charge()
	state = State.IDLE
	if was_attacking:
		attack_finished.emit(attack_id)


func is_attacking() -> bool:
	return state != State.IDLE


func is_charging() -> bool:
	return _charging and charge > 0.12


func is_hit_window_open() -> bool:
	return state == State.ATTACKING and _elapsed > _windup + EPSILON \
		and _elapsed <= _windup + _active + EPSILON


func cooldown_left() -> float:
	return 0.0 if state == State.IDLE else maxf(effective_cooldown() - _elapsed, 0.0)


## The current attack's cooldown scaled by the knight's current stats (attack-speed boost).
func effective_cooldown() -> float:
	return maxf(_cooldown * stats.cooldown_multiplier, _windup + _active)


func elapsed() -> float:
	return _elapsed


func state_name() -> String:
	return State.keys()[state]


## Name of the attack animation being shown, e.g. "attack_up" or "attack_low_left".
func animation_name() -> String:
	match profile:
		HitboxGeometry.Profile.UP:
			return "attack_up"
		HitboxGeometry.Profile.DOWN:
			return "attack_down"
		HitboxGeometry.Profile.LOW:
			return "attack_low_left" if _side < 0 else "attack_low_right"
	return "attack_left" if _side < 0 else "attack_right"


## The attacker's body pose for the current attack: [animation, frame] in the knight's sprite
## frames. The frame follows the same timeline as the hitbox (windup, two hit frames,
## recovery), so the arc on screen is always the one that can hit.
func visual_pose() -> Array:
	var phase := 3
	if _elapsed <= _windup + EPSILON:
		phase = 0
	elif _elapsed <= _windup + _active * 0.5 + EPSILON:
		phase = 1
	elif _elapsed <= _windup + _active + EPSILON:
		phase = 2
	match profile:
		HitboxGeometry.Profile.UP:
			return [&"attack_chop", [1, 2, 2, 1][phase]]
		HitboxGeometry.Profile.DOWN:
			return [&"attack_chop", [2, 3, 4, 5][phase]]
	return [&"attack_side", ([2, 3, 4, 5] if heavy else [1, 3, 4, 5])[phase]]


func current_range_multiplier() -> float:
	return stats.range_multiplier * (config.heavy_range_multiplier if heavy else 1.0)


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	if _skip_next_tick:
		_skip_next_tick = false
	else:
		_elapsed += delta
	if state == State.ATTACKING and _elapsed > _windup + _active + EPSILON:
		state = State.ATTACK_RECOVERY
	# Visual first, so the slash frame on screen always matches the hit frames below.
	_update_weapon()
	pose_updated.emit()
	var open := is_hit_window_open()
	if open:
		_place_hitbox()
	_set_hitbox_open(open)
	if open:
		_apply_hits()
	if state == State.ATTACK_RECOVERY and _elapsed >= effective_cooldown() - EPSILON:
		state = State.IDLE
		weapon.visible = false
		attack_finished.emit(attack_id)
		if _buffered and enabled:
			_buffered = false
			_start(_buffered_direction, _buffered_grounded, true, false)


## `in_physics_step` is true when called from this component's own _physics_process (a
## buffered attack), whose tick has already been processed.
func _start(attack_direction: AttackDirection.Direction, grounded: bool, in_physics_step: bool, is_heavy: bool) -> void:
	attack_id = _next_attack_id
	_next_attack_id += 1
	direction = attack_direction
	heavy = is_heavy
	_set_timeline(is_heavy)
	profile = HitboxGeometry.profile_for(attack_direction, grounded)
	var facing: int = _attacker.get(&"facing") if _attacker and &"facing" in _attacker else 1
	_side = HitboxGeometry.side_for(attack_direction, facing)
	_elapsed = 0.0
	_skip_next_tick = not in_physics_step
	_hit_ids.clear()
	targets_hit.clear()
	state = State.ATTACKING
	_place_hitbox()
	_update_weapon()
	Sfx.cue(&"attack_heavy" if is_heavy else &"attack", self)
	attack_started.emit(attack_id, direction)
	if is_heavy:
		heavy_started.emit(attack_id, direction)


func _set_timeline(is_heavy: bool) -> void:
	_windup = config.heavy_windup_time if is_heavy else config.windup_time
	_active = config.heavy_active_time if is_heavy else config.active_time
	_cooldown = config.heavy_cooldown if is_heavy else config.cooldown


func _reset_charge() -> void:
	_charging = false
	charge = 0.0
	charge_is_ready = false


func _place_hitbox() -> void:
	hitbox.configure(HitboxGeometry.local_rect(profile, _side, config, current_range_multiplier(), _body_height.call()))


func _set_hitbox_open(open: bool) -> void:
	if hitbox.active == open:
		return
	hitbox.active = open
	if open:
		hit_window_opened.emit(attack_id)
	else:
		hit_window_closed.emit(attack_id)


func _apply_hits() -> void:
	var origin := to_global(HitboxGeometry.origin(profile, config, _body_height.call()))
	for hurtbox in hitbox.find_targets(_attacker, origin, config.max_targets):
		var key := hurtbox.entity.get_instance_id()
		if _hit_ids.has(key):
			continue  # one hit per target per attack
		_hit_ids[key] = true
		var power := stats.attack_power + (config.heavy_power_bonus if heavy else 0)
		var event := DamageEvent.create(power, DamageEvent.Category.MELEE, _attacker)
		event.attack_id = attack_id
		event.direction = AttackDirection.to_vector(direction)
		event.attacker_player_id = _attacker_player_id
		event.poison_seconds = stats.poison_seconds
		event.heavy = heavy
		if _register_coop(key):
			event.coop = true
			event.amount += config.coop_bonus
		targets_hit.append(hurtbox.entity)
		hit_log.append({"attack_id": attack_id, "target": hurtbox.entity, "amount": event.amount})
		hurtbox.receive_hit(event)
		hit_landed.emit(hurtbox.entity, event)
		if event.coop:
			coop_strike.emit(hurtbox.entity)


## Records this knight's hit on `target_key`; true when it completes a co-op strike (the other
## knight hit the same target within the window). A completed strike is consumed.
func _register_coop(target_key: int) -> bool:
	if _attacker_player_id == 0:
		return false
	var frame := Engine.get_physics_frames()
	var window := int(ceil(config.coop_window * Engine.physics_ticks_per_second))
	for key: int in _recent_hits.keys():
		if frame - int(_recent_hits[key][0]) > window:
			_recent_hits.erase(key)
	if _recent_hits.has(target_key) and int(_recent_hits[target_key][1]) != _attacker_player_id:
		_recent_hits.erase(target_key)
		return true
	_recent_hits[target_key] = [frame, _attacker_player_id]
	return false


## Weapon frames follow the same timeline as the hitbox: 0 windup, 1-2 hit frames, 3 trail.
## Side and low slashes are drawn by the knight's own attack animation.
func _update_weapon() -> void:
	var window_end := _windup + _active
	var vertical := profile == HitboxGeometry.Profile.UP or profile == HitboxGeometry.Profile.DOWN
	if not vertical or _elapsed > window_end + config.trail_time + EPSILON:
		weapon.visible = false
		return
	weapon.visible = true
	if _elapsed <= _windup + EPSILON:
		weapon.frame = 0
	elif _elapsed <= _windup + _active * 0.5 + EPSILON:
		weapon.frame = 1
	elif _elapsed <= window_end + EPSILON:
		weapon.frame = 2
	else:
		weapon.frame = 3
	var body_height: float = _body_height.call()
	weapon.flip_h = false
	weapon.position = Vector2(0, -body_height * 0.5)
	weapon.rotation = -PI * 0.5 if profile == HitboxGeometry.Profile.UP else PI * 0.5
	weapon.scale = Vector2.ONE * (1.25 if heavy else 1.0)
