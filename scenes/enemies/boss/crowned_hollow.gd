class_name CrownedHollow
extends HollowCaptain
## The final boss (level 24): the Crowned Hollow. Three phases:
##   1  the captain's dash, volley and guard
##   2  (two thirds health) summons two hollow archers once and adds a ground slam whose
##      shockwaves run both ways
##   3  (one third) everything faster, double dashes and long volleys
## Its defeat opens the way to the campaign's end.

const SHOCKWAVE := preload("res://scenes/enemies/projectiles/shockwave.tscn")


func _moves() -> Array[StringName]:
	match phase:
		1:
			return [&"dash", &"volley", &"guard"]
		2:
			return [&"dash", &"slam", &"volley", &"guard"]
	return [&"dash", &"slam", &"volley", &"slam"]


func _on_custom_attack(name: StringName) -> void:
	if name != &"slam":
		return
	Sfx.cue(&"slam", self)
	Fx.shake(self, 3.5, 0.3)
	for dir in [-1, 1]:
		var wave := SHOCKWAVE.instantiate() as Shockwave
		get_parent().add_child(wave)
		wave.launch(global_position + Vector2(dir * 18, 0), dir, 150.0, 200.0)


func _attack_tick(_delta: float) -> void:
	if _move == &"slam":
		_strike_rect(Rect2(0, -40, 40, 40))


func _tempo() -> float:
	return 1.0 - 0.15 * (phase - 1)


func _update_visuals() -> void:
	super()
	queue_redraw()


func _draw() -> void:
	super()
	if state == State.DEAD:
		return
	# The crown: three gold points above the helmet.
	var top := -stats.body_size.y - 6.0
	var gold := Color(1.0, 0.82, 0.3, sprite.modulate.a)
	draw_rect(Rect2(-7, top + 3, 14, 3), Color(0.1, 0.08, 0.05, sprite.modulate.a))
	draw_rect(Rect2(-6, top + 3, 12, 2), gold)
	for x in [-6, -1, 4]:
		draw_rect(Rect2(x, top, 2, 3), gold)
