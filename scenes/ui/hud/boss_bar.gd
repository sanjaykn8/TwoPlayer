class_name BossBar
extends Control
## The boss health bar at the bottom of the HUD: the boss's name and a bar that drains as it is
## hit, with a trailing "recent damage" segment. Shown from the moment a mini-boss or the final
## boss engages until shortly after it is defeated. Driven by GameHud (boss_listeners group).

const WIDTH := 220.0
const HIDE_DELAY := 1.2

var boss_name := ""
var current := 1
var maximum := 1
var _trail := 1.0
var _hide_left := 0.0


func _init() -> void:
	name = "BossBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 20)
	visible = false


func show_boss(display_name: String, hp: int, max_hp: int) -> void:
	boss_name = display_name
	maximum = maxi(max_hp, 1)
	current = clampi(hp, 0, maximum)
	_trail = float(current) / maximum
	_hide_left = 0.0
	visible = true
	queue_redraw()


func set_health(hp: int, max_hp: int) -> void:
	maximum = maxi(max_hp, 1)
	current = clampi(hp, 0, maximum)
	queue_redraw()


func defeated() -> void:
	current = 0
	_hide_left = HIDE_DELAY
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	var target := float(current) / maximum
	_trail = move_toward(_trail, target, delta * 0.6)
	if _hide_left > 0.0:
		_hide_left -= delta
		if _hide_left <= 0.0:
			visible = false
	queue_redraw()


func _draw() -> void:
	var font := UiTheme.FONT_BOLD
	draw_string(font, Vector2(0, 8), boss_name, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 8, Color(1.0, 0.9, 0.75))
	var bar := Rect2(0, 13, WIDTH, 6)
	draw_rect(bar.grow(1.0), Color(0.05, 0.04, 0.05))
	draw_rect(bar, Color(0.18, 0.1, 0.12))
	draw_rect(Rect2(bar.position, Vector2(WIDTH * _trail, bar.size.y)), Color(0.95, 0.85, 0.5))
	draw_rect(Rect2(bar.position, Vector2(WIDTH * float(current) / maximum, bar.size.y)), Color(0.85, 0.2, 0.25))
