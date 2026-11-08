class_name CaveBat
extends Enemy
## A cave bat (drawn in code). It roosts at its spawn point until a knight comes within its
## detection radius, screeches (the telegraph), then swoops along a curve that passes through
## the knight's body height where the knight stood, and flies back to roost. One hit kills it.
## Up attacks and jumps meet it; stepping aside dodges it.

var _from := Vector2.ZERO
var _control := Vector2.ZERO
var _to := Vector2.ZERO
var _flap := 0.0


func _on_ready() -> void:
	alert_label.offset_top = -20.0
	alert_label.offset_bottom = -12.0


func _think(delta: float) -> void:
	_flap += delta
	match state:
		State.IDLE, State.PATROL:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			if target != null and _attack_cooldown <= 0.0:
				_enter(State.ALERT)
				Sfx.cue(&"bat", self)
		State.ALERT:
			velocity = Vector2.ZERO
			if target == null:
				_enter(State.RECOVER)
			elif _state_time >= stats.reaction_time:
				_begin_swoop()
		State.SPECIAL:
			var t := minf(_state_time / stats.special_time, 1.0)
			var p := _from.lerp(_control, t).lerp(_control.lerp(_to, t), t)
			velocity = (p - global_position) / maxf(delta, 0.001)
			_strike_rect(Rect2(-5, -7, 10, 7))
			if t >= 1.0:
				_attack_cooldown = stats.attack_cooldown
				_enter(State.RECOVER)
		State.RECOVER:
			var to_home := home - global_position
			if to_home.length() < 3.0:
				global_position = home
				velocity = Vector2.ZERO
				_enter(State.IDLE, stats.idle_time)
			else:
				velocity = to_home.normalized() * stats.special_speed * 0.6
		State.STUNNED:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if _state_time >= _stun_time:
				_enter(State.RECOVER)
		_:
			velocity = Vector2.ZERO


func _begin_swoop() -> void:
	_struck.clear()
	_from = global_position
	var aim := target.global_position + Vector2(0, -9)
	var dir := signf(aim.x - _from.x)
	if dir == 0.0:
		dir = facing
	facing = int(dir)
	_to = Vector2(aim.x + dir * stats.special_range * 0.5, _from.y)
	# Quadratic curve whose midpoint passes through the aim point.
	_control = 2.0 * aim - 0.5 * (_from + _to)
	_enter(State.SPECIAL)


func _contact_active() -> bool:
	return state == State.SPECIAL and stats.contact_damage > 0


func _blocked(_dir: int) -> bool:
	return false


func _anim_for_state() -> Array:
	return [&"", -1]


func _update_visuals() -> void:
	super()
	queue_redraw()


func _draw() -> void:
	super()
	if state == State.DEAD and _death_left <= 0.0:
		return
	var outline := Color(0.08, 0.06, 0.1)
	var body := Color(0.32, 0.24, 0.42) * sprite.modulate
	var wing := Color(0.45, 0.34, 0.58) * sprite.modulate
	var alpha := sprite.modulate.a
	body.a = alpha
	wing.a = alpha
	var roosting := state == State.IDLE or state == State.ALERT
	if roosting:
		# Hanging upside down, wings folded.
		draw_rect(Rect2(-3, -12, 6, 8), outline)
		draw_rect(Rect2(-2, -11, 4, 6), body)
		draw_rect(Rect2(-1, -6, 1, 1), Color(0.95, 0.25, 0.25, alpha))
		draw_rect(Rect2(1, -6, 1, 1), Color(0.95, 0.25, 0.25, alpha))
		return
	var up := int(_flap * 14.0) % 2 == 0
	draw_rect(Rect2(-3, -8, 6, 6), outline)
	draw_rect(Rect2(-2, -7, 4, 4), body)
	for side in [-1, 1]:
		var y := -10 if up else -5
		draw_rect(Rect2(Vector2(side * 3 + (0 if side > 0 else -5), y), Vector2(5, 3)), outline)
		draw_rect(Rect2(Vector2(side * 3 + (0 if side > 0 else -5) + 1, y + 1), Vector2(3, 1)), wing)
	draw_rect(Rect2(-2, -6, 1, 1), Color(0.95, 0.25, 0.25, alpha))
	draw_rect(Rect2(1, -6, 1, 1), Color(0.95, 0.25, 0.25, alpha))
