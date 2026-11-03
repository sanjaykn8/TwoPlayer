class_name CombatComponent
extends Node2D
## Melee attack state machine for one knight: IDLE -> ATTACKING (windup, then hit frames)
## -> ATTACK_RECOVERY -> IDLE. Both knights use their own instance, so their attacks never
## interact. All timings come from CombatConfig; power and range from CombatStats.
##
## Place as a direct child of the attacker at its origin, with children:
##   Hitbox (HitboxComponent) and Weapon (Sprite2D, 4-frame knife slash facing right).

signal attack_started(attack_id: int, direction: AttackDirection.Direction)
signal hit_window_opened(attack_id: int)
signal hit_window_closed(attack_id: int)
signal attack_finished(attack_id: int)
signal hit_landed(target: Node, event: DamageEvent)

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
## Entities damaged by the current attack, in hit order.
var targets_hit: Array[Node] = []
## Every hit this component has ever landed: {attack_id, target, amount} (for testing/logging).
var hit_log: Array[Dictionary] = []

var _attacker: Node2D
var _attacker_player_id := 0
var _body_height := func() -> float: return 18.0
var _side := 1
var _elapsed := 0.0
## The tick an attack starts on counts as elapsed time 0, so the cooldown spans exactly
## `cooldown` seconds of ticks between two attack starts.
var _skip_next_tick := false
var _hit_ids := {}
var _buffered := false
var _buffered_direction := AttackDirection.Direction.RIGHT
var _buffered_grounded := false

static var _next_attack_id := 1

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
	if _attacker == null:
		_attacker = get_parent() as Node2D


## `body_height` returns the attacker's current body height (it changes when crouching).
func setup(attacker: Node2D, player_id: int, body_height: Callable) -> void:
	_attacker = attacker
	_attacker_player_id = player_id
	_body_height = body_height


## Starts an attack now if possible, otherwise buffers it when the cooldown is nearly over.
## `grounded` selects the low forward slash for a DOWN attack on the ground (D-2).
func request_attack(attack_direction: AttackDirection.Direction, grounded: bool) -> bool:
	if not enabled:
		return false
	if state == State.IDLE:
		_start(attack_direction, grounded, false)
		return true
	if cooldown_left() <= config.input_buffer_time + EPSILON:
		_buffered = true
		_buffered_direction = attack_direction
		_buffered_grounded = grounded
	return false


## Stops any attack immediately (death, disable, scene reset).
func cancel() -> void:
	var was_attacking := state != State.IDLE
	_set_hitbox_open(false)
	weapon.visible = false
	_buffered = false
	state = State.IDLE
	if was_attacking:
		attack_finished.emit(attack_id)


func is_attacking() -> bool:
	return state != State.IDLE


func is_hit_window_open() -> bool:
	return state == State.ATTACKING and _elapsed > config.windup_time + EPSILON \
		and _elapsed <= config.hit_window_end() + EPSILON


func cooldown_left() -> float:
	return 0.0 if state == State.IDLE else maxf(config.cooldown - _elapsed, 0.0)


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


func current_range_multiplier() -> float:
	return stats.range_multiplier


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	if _skip_next_tick:
		_skip_next_tick = false
	else:
		_elapsed += delta
	if state == State.ATTACKING and _elapsed > config.hit_window_end() + EPSILON:
		state = State.ATTACK_RECOVERY
	# Visual first, so the slash frame on screen always matches the hit frames below.
	_update_weapon()
	var open := is_hit_window_open()
	if open:
		_place_hitbox()
	_set_hitbox_open(open)
	if open:
		_apply_hits()
	if state == State.ATTACK_RECOVERY and _elapsed >= config.cooldown - EPSILON:
		state = State.IDLE
		weapon.visible = false
		attack_finished.emit(attack_id)
		if _buffered and enabled:
			_buffered = false
			_start(_buffered_direction, _buffered_grounded, true)


## `in_physics_step` is true when called from this component's own _physics_process (a
## buffered attack), whose tick has already been processed.
func _start(attack_direction: AttackDirection.Direction, grounded: bool, in_physics_step: bool) -> void:
	attack_id = _next_attack_id
	_next_attack_id += 1
	direction = attack_direction
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
	attack_started.emit(attack_id, direction)


func _place_hitbox() -> void:
	hitbox.configure(HitboxGeometry.local_rect(profile, _side, config, stats.range_multiplier, _body_height.call()))


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
		var event := DamageEvent.create(stats.attack_power, DamageEvent.Category.MELEE, _attacker)
		event.attack_id = attack_id
		event.direction = AttackDirection.to_vector(direction)
		event.attacker_player_id = _attacker_player_id
		targets_hit.append(hurtbox.entity)
		hit_log.append({"attack_id": attack_id, "target": hurtbox.entity, "amount": event.amount})
		hurtbox.receive_hit(event)
		hit_landed.emit(hurtbox.entity, event)


## Weapon frames follow the same timeline as the hitbox: 0 windup, 1-2 hit frames, 3 trail.
func _update_weapon() -> void:
	var window_end := config.hit_window_end()
	if _elapsed > window_end + config.trail_time + EPSILON:
		weapon.visible = false
		return
	weapon.visible = true
	if _elapsed <= config.windup_time + EPSILON:
		weapon.frame = 0
	elif _elapsed <= config.windup_time + config.active_time * 0.5 + EPSILON:
		weapon.frame = 1
	elif _elapsed <= window_end + EPSILON:
		weapon.frame = 2
	else:
		weapon.frame = 3
	var body_height: float = _body_height.call()
	weapon.flip_h = false
	weapon.rotation = 0.0
	match profile:
		HitboxGeometry.Profile.UP:
			weapon.rotation = -PI * 0.5
			weapon.position = Vector2(0, -body_height * 0.5)
		HitboxGeometry.Profile.DOWN:
			weapon.rotation = PI * 0.5
			weapon.position = Vector2(0, -body_height * 0.5)
		HitboxGeometry.Profile.LOW:
			weapon.flip_h = _side < 0
			weapon.position = Vector2(0, -config.low_thickness * 0.5)
		_:
			weapon.flip_h = _side < 0
			weapon.position = Vector2(0, -body_height * 0.5)
