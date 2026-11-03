class_name Knight
extends CharacterBody2D
## Reusable knight controller shared by both players.
## Identity, controls and colours come from `profile`; every movement value comes from `config`.
## The node origin is at the knight's feet (bottom centre of the collision box).

signal state_changed(previous: State, current: State)
## The attack input was pressed (whether or not the cooldown allows a new attack to start).
signal attack_requested(direction: AttackDirection.Direction)
## Health reached zero. Emitted exactly once until revive().
signal died
signal jumped
signal landed

enum State { GROUNDED, AIRBORNE, CROUCHING, CLIMBING, DISABLED, DEAD }
enum FloorKind { NONE, SOLID, ONE_WAY, KNIGHT }

const GROUP := &"knights"
const WORLD_BIT := 1 << 0
const ONE_WAY_BIT := 1 << 1
const PLAYERS_BIT := 1 << 2
const CLIMB_BIT := 1 << 9
## How far below the feet to look for a climbable that continues downward.
const FEET_PROBE := 4.0
## Pixels climbed between flips of the placeholder climb pose.
const CLIMB_FLIP_STEP := 6.0
const HURT_ANIMATION_TIME := 0.4
## Invulnerability blink: the sprite alternates between full and this opacity.
const BLINK_ALPHA := 0.35
const BLINK_PERIOD := 0.08

@export var profile: KnightProfile
@export var config: KnightConfig
## Shows a small "P1"/"P2" label above the knight (development rooms only).
@export var show_debug_tag := false

var state := State.AIRBORNE
## Last horizontal facing: 1 right, -1 left. Only horizontal input changes it (D-1).
var facing := 1
var input := KnightInputFrame.new()
## When false the knight ignores its keys. Gravity still applies.
var input_enabled := true
var floor_kind := FloorKind.NONE
## The knight this one is standing on, if any.
var floor_knight: Knight
var last_attack_direction := AttackDirection.Direction.RIGHT
var attack_count := 0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_cut_available := false
var _regrab_timer := 0.0
var _hurt_timer := 0.0
var _climbable: Climbable
var _climb_travel := 0.0
var _climb_flip := false
var _drop_active := false
var _drop_surface_y := 0.0
var _drop_timer := 0.0
var _restore_one_way := false
var _restore_players := false
var _point_query := PhysicsPointQueryParameters2D.new()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $Body
@onready var health: HealthComponent = $Health
@onready var combat: CombatComponent = $Combat
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var debug_tag: Label = $Tag


func _ready() -> void:
	add_to_group(GROUP)
	if profile == null or config == null:
		push_error("%s needs both a KnightProfile and a KnightConfig" % name)
		set_physics_process(false)
		return
	var missing := profile.missing_actions()
	if not missing.is_empty():
		push_error("%s: InputMap is missing actions %s" % [name, missing])
	# Each instance gets its own shape and material so crouching or recolouring one
	# knight never affects the other.
	body_shape.shape = body_shape.shape.duplicate()
	sprite.material = sprite.material.duplicate()
	_apply_palette()
	hurtbox.entity = self
	hurtbox.hit_received.connect(_on_hit_received)
	_set_body_size(config.standing_size)
	health.invulnerability_time = config.invulnerability_time
	health.initialize(config.base_max_health)
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)
	combat.setup(self, profile.player_id, _body_height)
	debug_tag.visible = show_debug_tag
	debug_tag.text = "P%d" % profile.player_id
	_point_query.collision_mask = CLIMB_BIT
	_point_query.collide_with_areas = true
	_point_query.collide_with_bodies = false


func _physics_process(delta: float) -> void:
	_read_input()
	_tick_timers(delta)
	if input.attack_pressed and state != State.DISABLED and state != State.DEAD:
		_request_attack()
	match state:
		State.DISABLED, State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, config.ground_deceleration * delta)
			_apply_gravity(delta)
		State.CLIMBING:
			_process_climbing(delta)
		_:
			_process_platforming(delta)
	if state != State.CLIMBING and state != State.DISABLED and state != State.DEAD:
		_push_other_knights(delta)
	var start_x := global_position.x
	move_and_slide()
	_classify_floor()
	_carry_riders(global_position.x - start_x)
	_update_state_after_move()
	_update_collision_restores(delta)
	_update_animation(delta)


# --- Public interface -------------------------------------------------------------

func player_id() -> int:
	return profile.player_id if profile else 0


func state_name() -> String:
	return State.keys()[state]


func is_climbing() -> bool:
	return state == State.CLIMBING


func is_dead() -> bool:
	return state == State.DEAD


## Explicitly brings a dead knight back (development reset; later the campaign reset).
## Restores full health and normal control.
func revive() -> void:
	health.revive()
	combat.enabled = true
	if state == State.DEAD:
		_set_state(State.AIRBORNE)
	sprite.self_modulate.a = 1.0


## Moves the knight instantly (spawns, respawns). Collision with the other knight is
## suspended until they no longer overlap, so a spawn on top of them cannot fling anyone.
func teleport_to(target: Vector2) -> void:
	if state == State.CLIMBING:
		_leave_climb()
	_end_drop()
	global_position = target
	velocity = Vector2.ZERO
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_suppress_players_collision()
	if state != State.DEAD:
		_set_state(State.AIRBORNE)
	reset_physics_interpolation()


func set_disabled(disabled: bool) -> void:
	if state == State.DEAD:
		return
	if disabled:
		combat.cancel()
		if state == State.CLIMBING:
			_leave_climb()
		_set_state(State.DISABLED)
	elif state == State.DISABLED:
		_set_state(State.AIRBORNE)


## Called by the other knight when it walks into this one. Returns the distance moved.
func receive_push(dx: float) -> float:
	if state == State.CLIMBING or state == State.DISABLED:
		return 0.0
	var before := global_position.x
	move_and_collide(Vector2(dx, 0.0))
	var moved := global_position.x - before
	_carry_riders(moved)
	return moved


# --- Input -------------------------------------------------------------------------

func _read_input() -> void:
	if not input_enabled or profile == null:
		input = KnightInputFrame.new()
		return
	var just := {
		&"up": Input.is_action_just_pressed(profile.action_up),
		&"down": Input.is_action_just_pressed(profile.action_down),
		&"attack": Input.is_action_just_pressed(profile.action_attack),
	}
	input = KnightInputFrame.capture(
		Input.is_action_pressed(profile.action_left),
		Input.is_action_pressed(profile.action_right),
		Input.is_action_pressed(profile.action_up),
		Input.is_action_pressed(profile.action_down),
		Input.is_action_pressed(profile.action_attack),
		input, just)


func _request_attack() -> void:
	last_attack_direction = AttackDirection.resolve(input.up_held, input.down_held, facing)
	attack_count += 1
	attack_requested.emit(last_attack_direction)
	var grounded := is_on_floor() and (state == State.GROUNDED or state == State.CROUCHING)
	combat.request_attack(last_attack_direction, grounded)


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_regrab_timer = maxf(_regrab_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)


# --- Platforming -------------------------------------------------------------------

func _process_platforming(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote_timer = config.coyote_time
	if input.up_pressed:
		_jump_buffer_timer = config.jump_buffer_time

	var centre_climbable := _climbable_at(_body_centre())
	var below_climbable := _climbable_at(global_position + Vector2(0.0, FEET_PROBE))
	var ctx := VerticalIntent.Context.new()
	ctx.up_held = input.up_held
	ctx.down_held = input.down_held
	ctx.down_pressed = input.down_pressed
	ctx.jump_requested = _jump_buffer_timer > 0.0
	ctx.can_jump = on_floor or _coyote_timer > 0.0
	ctx.on_floor = on_floor
	ctx.on_one_way_only = floor_kind == FloorKind.ONE_WAY
	ctx.overlapping_climbable = centre_climbable != null
	ctx.climbable_below_feet = below_climbable != null
	ctx.can_grab = _regrab_timer <= 0.0

	match VerticalIntent.resolve(ctx):
		VerticalIntent.Intent.GRAB_CLIMB:
			var target := centre_climbable if (input.up_held and centre_climbable) else below_climbable
			if state != State.CROUCHING or _can_stand():
				_enter_climb(target)
				_process_climbing(delta)
				return
		VerticalIntent.Intent.DROP_THROUGH:
			_start_drop()
		VerticalIntent.Intent.CROUCH:
			_set_state(State.CROUCHING)
		VerticalIntent.Intent.JUMP:
			if state != State.CROUCHING or _can_stand():
				_jump()

	if state == State.CROUCHING:
		var wants_crouch := input.down_held and on_floor and floor_kind != FloorKind.ONE_WAY
		if not wants_crouch and _can_stand():
			_set_state(State.GROUNDED if on_floor else State.AIRBORNE)

	var top_speed := config.crouch_speed if state == State.CROUCHING else config.run_speed
	var target_speed := input.move_x * top_speed
	var rate: float
	if on_floor:
		var reversing := input.move_x != 0 and signf(velocity.x) == -input.move_x
		rate = config.ground_deceleration if (input.move_x == 0 or reversing) else config.ground_acceleration
	else:
		rate = config.air_deceleration if input.move_x == 0 else config.air_acceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if input.move_x != 0:
		facing = input.move_x

	_apply_gravity(delta)
	if velocity.y < 0.0:
		if _jump_cut_available and not input.up_held:
			velocity.y *= config.jump_cut_multiplier
			_jump_cut_available = false
	else:
		_jump_cut_available = false


func _apply_gravity(delta: float) -> void:
	var gravity := config.rise_gravity if velocity.y < 0.0 else config.fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, config.max_fall_speed)


func _jump() -> void:
	velocity.y = -config.jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_jump_cut_available = true
	_set_state(State.AIRBORNE)
	for rider in _riders():
		rider._lift(velocity.y)
	jumped.emit()


## Starts a drop through the one-way platform underfoot. Only the one-way layer is
## ignored, and only by this knight; solid terrain is never affected.
func _start_drop() -> void:
	_drop_active = true
	_drop_surface_y = global_position.y
	_drop_timer = 0.0
	_restore_one_way = false
	set_collision_mask_value(2, false)
	velocity.y = maxf(velocity.y, 20.0)
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_set_state(State.AIRBORNE)


func _end_drop() -> void:
	_drop_active = false
	_restore_one_way = true


# --- Climbing ----------------------------------------------------------------------

func _enter_climb(climbable: Climbable) -> void:
	_climbable = climbable
	_set_state(State.CLIMBING)
	velocity = Vector2.ZERO
	_jump_buffer_timer = 0.0
	_jump_cut_available = false
	_drop_active = false
	if climbable.kind == Climbable.Kind.LADDER:
		global_position.x = climbable.center_x()
	# While climbing, pass through one-way platforms (ladder tops) and the other knight.
	_restore_one_way = false
	set_collision_mask_value(2, false)
	_suppress_players_collision()


func _process_climbing(delta: float) -> void:
	if not is_instance_valid(_climbable):
		_leave_climb()
		return
	var axis := input.climb_axis()
	velocity.y = axis * config.climb_speed
	if _climbable.allows_horizontal_movement():
		velocity.x = input.move_x * config.climb_speed
		if input.move_x != 0:
			facing = input.move_x
	else:
		velocity.x = 0.0
		if input.move_x != 0:
			_leave_climb()
			facing = input.move_x
			velocity.x = input.move_x * config.ladder_release_speed
			return
	# Climbing out of the top: stand on the surface at the top of the climbable.
	if velocity.y < 0.0 and global_position.y + velocity.y * delta <= _climbable.top_y():
		global_position.y = _climbable.top_y()
		velocity.y = 0.0
		_leave_climb()


func _leave_climb() -> void:
	_climbable = null
	_regrab_timer = config.regrab_delay
	_restore_one_way = true
	_restore_players = true
	_set_state(State.AIRBORNE)


func _climbable_at(point: Vector2) -> Climbable:
	_point_query.position = point
	for hit in get_world_2d().direct_space_state.intersect_point(_point_query, 4):
		if hit.collider is Climbable:
			return hit.collider
	return null


# --- Knight-to-knight interaction --------------------------------------------------

## Pushes the knight directly ahead at `push_speed`, then caps this knight's speed to
## match, so both move together without impulses. Walls stop the pushed knight.
func _push_other_knights(delta: float) -> void:
	if input.move_x == 0:
		return
	var hit := move_and_collide(Vector2(input.move_x, 0.0), true)
	if hit == null or absf(hit.get_normal().x) < 0.7:
		return
	var other := hit.get_collider() as Knight
	if other == null:
		return
	other.receive_push(input.move_x * config.push_speed * delta)
	velocity.x = clampf(velocity.x, -config.push_speed, config.push_speed)


func _riders() -> Array[Knight]:
	var riders: Array[Knight] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		var k := node as Knight
		if k != self and k.floor_knight == self and k.state != State.CLIMBING:
			riders.append(k)
	return riders


func _carry_riders(dx: float) -> void:
	if absf(dx) < 0.001:
		return
	for rider in _riders():
		rider.move_and_collide(Vector2(dx, 0.0))


## Called when the knight underneath jumps: this knight is lifted with it (D-3).
func _lift(vertical_velocity: float) -> void:
	if state == State.CLIMBING or state == State.DISABLED or state == State.DEAD:
		return
	if state == State.CROUCHING and not _can_stand():
		return
	velocity.y = minf(velocity.y, vertical_velocity)
	_jump_cut_available = false
	_coyote_timer = 0.0
	_set_state(State.AIRBORNE)
	move_and_collide(Vector2(0.0, vertical_velocity * get_physics_process_delta_time()))


func _suppress_players_collision() -> void:
	set_collision_layer_value(3, false)
	set_collision_mask_value(3, false)
	_restore_players = true


# --- After-move bookkeeping --------------------------------------------------------

func _classify_floor() -> void:
	floor_knight = null
	if not is_on_floor():
		floor_kind = FloorKind.NONE
		return
	var solid := false
	var one_way := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().dot(up_direction) < 0.7:
			continue
		var collider := collision.get_collider()
		if collider is Knight:
			floor_knight = collider
			continue
		var layer := PhysicsServer2D.body_get_collision_layer(collision.get_collider_rid())
		if layer & WORLD_BIT:
			solid = true
		elif layer & ONE_WAY_BIT:
			one_way = true
	if solid:
		floor_kind = FloorKind.SOLID
	elif floor_knight != null:
		floor_kind = FloorKind.KNIGHT
	elif one_way:
		floor_kind = FloorKind.ONE_WAY
	elif floor_kind == FloorKind.NONE:
		floor_kind = FloorKind.SOLID  # snapped to the floor without a reported collision


func _update_state_after_move() -> void:
	match state:
		State.CLIMBING:
			if input.climb_axis() > 0 and is_on_floor():
				_leave_climb()
				_set_state(State.GROUNDED)
			elif not _climbable.holds(_body_centre()):
				_leave_climb()
		State.GROUNDED, State.AIRBORNE:
			if is_on_floor():
				if state == State.AIRBORNE:
					_set_state(State.GROUNDED)
					landed.emit()
			else:
				_set_state(State.AIRBORNE)


func _update_collision_restores(delta: float) -> void:
	if _drop_active:
		_drop_timer += delta
		var cleared := global_position.y >= _drop_surface_y + config.drop_clear_distance
		if cleared or _drop_timer >= config.drop_max_time:
			_end_drop()
	if state == State.CLIMBING:
		return
	if _restore_one_way and not _drop_active and not _body_overlaps(ONE_WAY_BIT):
		set_collision_mask_value(2, true)
		_restore_one_way = false
	if _restore_players and not _body_overlaps(PLAYERS_BIT):
		set_collision_layer_value(3, true)
		set_collision_mask_value(3, true)
		_restore_players = false


# --- Body shape --------------------------------------------------------------------

func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	if next == State.CROUCHING:
		_set_body_size(config.crouch_size)
	elif previous == State.CROUCHING:
		_set_body_size(config.standing_size)
	state_changed.emit(previous, next)


func _set_body_size(size: Vector2) -> void:
	var rect := body_shape.shape as RectangleShape2D
	rect.size = size
	body_shape.position = Vector2(0.0, -size.y * 0.5)
	hurtbox.set_box(size, body_shape.position)


func _body_height() -> float:
	return (body_shape.shape as RectangleShape2D).size.y


func _body_centre() -> Vector2:
	return global_position + body_shape.position


## True when the standing box fits above the feet without touching terrain or a knight.
func _can_stand() -> bool:
	var size := config.standing_size
	var query_size := Vector2(size.x - 2.0, size.y - 1.0)
	return not _shape_overlaps(query_size, Vector2(0.0, -(size.y + 1.0) * 0.5),
		WORLD_BIT | (PLAYERS_BIT if get_collision_mask_value(3) else 0))


## True when the current body (shrunk by a pixel so plain contact does not count)
## overlaps anything on `mask`.
func _body_overlaps(mask: int) -> bool:
	var size := (body_shape.shape as RectangleShape2D).size
	return _shape_overlaps(size - Vector2(1.0, 1.0), body_shape.position, mask)


func _shape_overlaps(size: Vector2, local_offset: Vector2, mask: int) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position + local_offset)
	params.collision_mask = mask
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


# --- Presentation ------------------------------------------------------------------

func _apply_palette() -> void:
	var palette := sprite.material as ShaderMaterial
	palette.set_shader_parameter(&"target_tunic", profile.tunic_color)
	palette.set_shader_parameter(&"target_plume", profile.plume_color)
	debug_tag.add_theme_color_override(&"font_color", profile.tunic_color.lightened(0.35))


func _on_hit_received(event: DamageEvent) -> void:
	health.take_damage(event)


func _on_damaged(_amount: int) -> void:
	if state == State.DEAD or not health.is_alive():
		return
	_hurt_timer = HURT_ANIMATION_TIME
	sprite.play(&"hurt")
	sprite.frame = 0


## Health reached zero: stop moving and attacking, play the death animation.
## Campaign-wide consequences belong to Phase 8.
func _on_depleted() -> void:
	if state == State.DEAD:
		return
	if state == State.CLIMBING:
		_leave_climb()
	combat.cancel()
	combat.enabled = false
	_jump_buffer_timer = 0.0
	_hurt_timer = 0.0
	velocity.x = 0.0
	_set_state(State.DEAD)
	sprite.self_modulate.a = 1.0
	sprite.play(&"death")
	died.emit()


func _update_animation(delta: float) -> void:
	sprite.flip_h = facing < 0
	if state == State.DEAD:
		_play(&"death")
		return
	var blink_off := health.is_invulnerable() and int(health.invulnerability_left() / BLINK_PERIOD) % 2 == 0
	sprite.self_modulate.a = BLINK_ALPHA if blink_off else 1.0
	if _hurt_timer > 0.0:
		_play(&"hurt")
		return
	match state:
		State.CLIMBING:
			_play(&"climb")
			_climb_travel += velocity.length() * delta
			if _climb_travel >= CLIMB_FLIP_STEP:
				_climb_travel = 0.0
				_climb_flip = not _climb_flip
			sprite.flip_h = _climb_flip
		State.CROUCHING:
			_play(&"crouch")
		State.AIRBORNE, State.DISABLED:
			_play(&"jump" if velocity.y < 0.0 else &"fall")
		_:
			_play(&"run" if absf(velocity.x) > 8.0 else &"idle")


func _play(animation: StringName) -> void:
	if sprite.animation != animation:
		sprite.play(animation)
