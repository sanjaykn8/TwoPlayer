class_name HollowCaptain
extends BossEnemy
## Mini-boss (level 20): a giant hollow soldier. Moves, each with a clear wind-up:
##   dash    sword raised (flash), then a fast lunge with the blade out; jump over or get clear
##   volley  draws the bow, then looses arrows one after another at set heights: chest height
##           (crouch or jump), ankle height (jump) and head height (stay down)
##   guard   raises its guard for a while: light hits from the front are blocked; hit it from
##           behind, from above, or break the guard with a heavy slash
## From phase 2 it dashes twice in a row and its volleys get longer.

const ARROW := preload("res://scenes/enemies/projectiles/arrow.tscn")
const GUARD_TIME := 1.8
const DASH_TIME := 0.38
const VOLLEY_GAP := 0.22
const CHEST := 14.0
const ANKLE := 5.0
const HEAD := 27.0

var _move := &"dash"
var _cycle := 0
var _dashes_left := 0
var _volley: Array[float] = []
var _next_arrow := 0.0


func _moves() -> Array[StringName]:
	return [&"dash", &"volley", &"guard"]


func _volley_heights() -> Array[float]:
	if phase >= 2:
		return [ANKLE, CHEST, HEAD, ANKLE, CHEST]
	return [CHEST, ANKLE, CHEST]


func _chase(delta: float) -> void:
	var d := target.global_position - global_position
	_face(d.x)
	if _attack_cooldown > 0.0:
		_walk_toward(target.global_position.x, stats.patrol_speed, delta)
		return
	var moves := _moves()
	var move: StringName = moves[_cycle % moves.size()]
	_cycle += 1
	if move == &"dash" and absf(d.y) > SAME_LEVEL_HEIGHT:
		move = &"volley"
	_begin(move)


func _begin(move: StringName) -> void:
	_move = move
	match move:
		&"dash":
			_windup_time = 0.55 * _tempo()
			_dashes_left = 2 if phase >= 2 else 1
		&"volley":
			_windup_time = 0.8 * _tempo()
			Sfx.cue(&"bow_draw", self)
		&"guard":
			_windup_time = 0.25
		&"slam":
			_windup_time = 0.8 * _tempo()
	_active_time = 0.12
	_recovery_time = 0.6
	_enter(State.WINDUP)


func _start_attack() -> void:
	match _move:
		&"dash":
			Sfx.cue(&"attack_heavy", self)
			_enter(State.SPECIAL)
		&"volley":
			_volley = _volley_heights()
			_next_arrow = 0.0
			_enter(State.SPECIAL)
		&"guard":
			Sfx.cue(&"shield_block", self)
			_enter(State.SPECIAL)
		_:
			_on_custom_attack(_move)


## Subclass hook for extra moves started from the wind-up.
func _on_custom_attack(_name: StringName) -> void:
	pass


func _attack_tick(_delta: float) -> void:
	pass


func _special_tick(delta: float) -> bool:
	match _move:
		&"dash":
			velocity.x = facing * stats.special_speed
			_strike_rect(stats.attack_rect)
			if _state_time >= DASH_TIME or _blocked(facing) or is_on_wall():
				velocity.x = 0.0
				_dashes_left -= 1
				if _dashes_left > 0 and target != null:
					_struck.clear()
					_face(target.global_position.x - global_position.x)
					_windup_time = 0.3
					_enter(State.WINDUP)
					return false
				return true
		&"volley":
			_slow_down(delta)
			_next_arrow -= delta
			if _next_arrow <= 0.0 and not _volley.is_empty():
				_fire(_volley.pop_front())
				_next_arrow = VOLLEY_GAP
			return _volley.is_empty() and _next_arrow <= 0.0
		&"guard":
			_slow_down(delta)
			return _state_time >= GUARD_TIME
	return true


func _fire(height: float) -> void:
	Sfx.cue(&"arrow_shot", self)
	var arrow := ARROW.instantiate() as EnemyArrow
	get_parent().add_child(arrow)
	arrow.launch(global_position + Vector2(facing * 22, -height), Vector2(facing, 0), 200.0, stats.special_range, self)


func _blocks(event: DamageEvent) -> bool:
	if not (state == State.SPECIAL and _move == &"guard"):
		return false
	if event.blast or event.direction.y != 0 or event.direction.x != -facing:
		return false
	if event.heavy:
		stun(1.4)  # guard broken: wide open
	return true


func _anim_for_state() -> Array:
	match state:
		State.WINDUP:
			if _move == &"volley":
				return [&"draw", int(clampf(_state_time / windup_duration(), 0.0, 0.999) * 7.0)]
			if _move == &"slam":
				return [&"chop", 1 if _state_time < windup_duration() * 0.5 else 2]
			return [&"slash", 1 if _state_time < windup_duration() * 0.5 else 2]
		State.ATTACK:
			return [&"chop", 3] if _move == &"slam" else [&"slash", 3]
		State.SPECIAL:
			match _move:
				&"dash":
					return [&"slash", 3 if int(_state_time * 20.0) % 2 == 0 else 4]
				&"volley":
					return [&"release", 0 if _next_arrow > VOLLEY_GAP * 0.5 else 1]
				&"guard":
					return [&"hurt", 3]
		State.RECOVER:
			return [&"chop", 5] if _move == &"slam" else [&"slash", 5]
		State.PATROL, State.CHASE:
			return [&"walk", -1]
		State.STUNNED:
			return [&"hurt", 0]
	return [&"idle", -1]


func _update_visuals() -> void:
	super()
	if state == State.SPECIAL and _move == &"guard":
		sprite.modulate = Color(0.85, 0.95, 1.6)
	queue_redraw()


func _draw() -> void:
	super()
	if state == State.SPECIAL and _move == &"guard":
		var x := facing * 18.0
		draw_rect(Rect2(x - 2, -42, 4, 38), Color(0.75, 0.85, 1.0, 0.75))
