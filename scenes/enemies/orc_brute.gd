class_name OrcBrute
extends Enemy
## A heavy orc: slow, barely moved by hits, and its overhead smash (long, obvious wind-up) sends
## a shockwave along the ground in both directions. Jump the waves; punish the long recovery.

const SHOCKWAVE := preload("res://scenes/enemies/projectiles/shockwave.tscn")


func _start_attack() -> void:
	Sfx.cue(&"slam", self)
	Fx.shake(self, 2.5, 0.25)
	Fx.dust(self, global_position + Vector2(facing * 14, 0), 8)
	for dir in [-1, 1]:
		var wave := SHOCKWAVE.instantiate() as Shockwave
		get_parent().add_child(wave)
		wave.launch(global_position + Vector2(dir * 10, 0), dir, stats.special_speed, stats.special_range)


func _anim_for_state() -> Array:
	match state:
		State.WINDUP:
			return [&"smash", 1 if _state_time < stats.windup_time * 0.5 else 2]
		State.ATTACK:
			return [&"smash", 3]
		State.RECOVER:
			return [&"smash", 4 if _state_time < stats.recovery_time * 0.5 else 5]
	return super()


func _attack_tick(_delta: float) -> void:
	_strike_rect(stats.attack_rect)
