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
	var a := sprite.modulate.a
	var tint := Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b)
	var outline := Color(0.06, 0.04, 0.08, a)
	var body := Color(0.42, 0.32, 0.55) * tint
	var wing := Color(0.62, 0.5, 0.78) * tint
	var eye := Color(1.0, 0.3, 0.25, a)
	body.a = a
	wing.a = a
	if state == State.IDLE or state == State.ALERT:
		# Hanging upside down from the ceiling, wings wrapped around the body; the eyes glow.
		draw_rect(Rect2(-1, -16, 2, 3), outline)
		draw_rect(Rect2(-5, -13, 10, 11), outline)
		draw_rect(Rect2(-4, -12, 8, 9), wing)
		draw_rect(Rect2(-2, -12, 4, 8), body)
		draw_rect(Rect2(-2, -6, 1, 1), eye)
		draw_rect(Rect2(1, -6, 1, 1), eye)
		return
	var up := int(_flap * 14.0) % 2 == 0
	var wy := -12 if up else -6
	for side in [-1, 1]:
		var wx := 3 if side > 0 else -11
		draw_rect(Rect2(wx, wy, 8, 4), outline)
		draw_rect(Rect2(wx + 1, wy + 1, 6, 2), wing)
		draw_rect(Rect2(wx + (6 if side > 0 else 0), wy + (3 if up else -1), 2, 2), outline)
	draw_rect(Rect2(-4, -10, 8, 8), outline)
	draw_rect(Rect2(-3, -9, 6, 6), body)
	draw_rect(Rect2(-3, -12, 2, 2), outline)
	draw_rect(Rect2(1, -12, 2, 2), outline)
	draw_rect(Rect2(-2, -7, 1, 1), eye)
	draw_rect(Rect2(1, -7, 1, 1), eye)
