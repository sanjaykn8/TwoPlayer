class_name OrcWarchief
extends BossEnemy
## Mini-boss (level 12): a giant orc. Moves, each with its own clear wind-up:
##   combo   two axe sweeps, the second quicker (step back twice)
##   slam    overhead smash, shockwaves both ways (jump them)
##   charge  stamps (dust, flash), then charges across the floor; if it hits a wall it is
##           dazed and open for a long time. Step aside or jump over.
## At half health it calls two grunts once and its wind-ups get shorter.

const SHOCKWAVE := preload("res://scenes/enemies/projectiles/shockwave.tscn")

var _move := &"combo"
var _combo_step := 0
var _cycle := 0


func _chase(delta: float) -> void:
	var d := target.global_position - global_position
	_face(d.x)
	if _attack_cooldown > 0.0:
		_walk_toward(target.global_position.x, stats.patrol_speed, delta)
		return
	_cycle += 1
	if absf(d.x) > 80.0 and _cycle % 2 == 0:
		_begin(&"charge", 0.7)
	elif _cycle % 3 == 0 or absf(d.y) > SAME_LEVEL_HEIGHT:
		_begin(&"slam", 0.85)
	elif absf(d.x) <= stats.attack_range:
		_combo_step = 0
		_begin(&"combo", 0.6)
	else:
		_cycle -= 1
		_walk_toward(target.global_position.x, stats.chase_speed(), delta)


func _begin(move: StringName, windup: float) -> void:
	_move = move
	_windup_time = windup * _tempo()
	_active_time = 0.16
	_recovery_time = 0.5 if move == &"combo" else 0.9
	if move == &"charge":
		Fx.dust(self, global_position, 10)
		Sfx.cue(&"slam", self)
	_enter(State.WINDUP)


func _start_attack() -> void:
	match _move:
		&"slam":
			Sfx.cue(&"slam", self)
			Fx.shake(self, 3.5, 0.3)
			for dir in [-1, 1]:
				var wave := SHOCKWAVE.instantiate() as Shockwave
				get_parent().add_child(wave)
				wave.launch(global_position + Vector2(dir * 20, 0), dir, stats.special_speed, stats.special_range)
		&"charge":
			Sfx.cue(&"orc_swing", self)
			_enter(State.SPECIAL)
		_:
			Sfx.cue(&"orc_swing", self)


func _attack_tick(_delta: float) -> void:
	if _move == &"slam":
		_strike_rect(Rect2(0, -40, 46, 40))
	else:
		_strike_rect(stats.attack_rect)


func _think(delta: float) -> void:
	# The second sweep of the combo follows straight after the first one's recovery begins.
	if state == State.RECOVER and _move == &"combo" and _combo_step == 0 and _state_time >= 0.15:
		_combo_step = 1
		_windup_time = 0.32 * _tempo()
		if target != null:
			_face(target.global_position.x - global_position.x)
		_enter(State.WINDUP)
		return
	super(delta)


func _special_tick(_delta: float) -> bool:
	velocity.x = facing * stats.special_speed
	_strike_rect(Rect2(-6, -40, 34, 40))
	if _blocked(facing) or is_on_wall():
		velocity.x = 0.0
		Sfx.cue(&"slam", self)
		Fx.shake(self, 4.0, 0.35)
		Fx.dust(self, global_position + Vector2(facing * 20, -10), 12)
		stun(1.6)  # dazed against the wall: the big opening
		return false
	if _state_time >= stats.special_time:
		velocity.x = 0.0
		return true
	return false


func _anim_for_state() -> Array:
	var sheet := &"smash" if _move == &"slam" else &"sweep"
	match state:
		State.WINDUP:
			return [sheet, 1 if _state_time < windup_duration() * 0.5 else 2]
		State.ATTACK:
			return [sheet, 3]
		State.RECOVER:
			return [sheet, 4 if _state_time < 0.25 else 5]
		State.SPECIAL:
			return [&"walk", -1]
	return super()
