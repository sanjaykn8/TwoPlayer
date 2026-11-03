class_name HealthDisplay
extends Control
## One heart per health point, up to any maximum (green jars raise it): full hearts for
## current health, empty hearts for missing health, wrapping after HEARTS_PER_ROW. Drawn in
## _draw() and redrawn only when a value changes, so nothing is rebuilt during play.
## A dead knight shows only greyed empty hearts.

const HEARTS_PER_ROW := 10
const STEP := 9

var current := 0
var maximum := 0
var dead := false
## Mirror the layout for the right-hand (Player Two) panel.
var right_aligned := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_health(value: int, max_value: int) -> void:
	var is_dead := value <= 0
	if value == current and max_value == maximum and is_dead == dead:
		return
	current = maxi(value, 0)
	maximum = maxi(max_value, 0)
	dead = is_dead
	var rows := maxi(1, ceili(float(maximum) / HEARTS_PER_ROW))
	var cols := mini(maximum, HEARTS_PER_ROW)
	custom_minimum_size = Vector2(maxi(cols, 1) * STEP - 1, rows * STEP - 1)
	queue_redraw()


func full_hearts() -> int:
	return 0 if dead else current


func empty_hearts() -> int:
	return maximum - full_hearts()


func _draw() -> void:
	var full := UiTheme.icon(UiTheme.ICON_HEART)
	var empty := UiTheme.icon(UiTheme.ICON_HEART_EMPTY)
	var tint := Color(0.55, 0.55, 0.6) if dead else Color.WHITE
	for i in maximum:
		var col := i % HEARTS_PER_ROW
		var row := i / HEARTS_PER_ROW
		var x := col * STEP
		if right_aligned:
			x = int(size.x) - (col + 1) * STEP + 1
		draw_texture(full if i < full_hearts() else empty, Vector2(x, row * STEP), tint)
