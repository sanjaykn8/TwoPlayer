class_name SettingsSlider
extends HBoxContainer
## "Music   [=====----]  70%": a labelled 0-100 slider. Left/Right change it by `step`
## while it has focus; the value shows as a number, and changes are reported at once
## (the settings screen applies them immediately, so the effect is heard while adjusting).

signal value_changed(value: int)

var slider: HSlider
var _value_label: Label


func _init(caption: String, value: int, step := 5) -> void:
	add_theme_constant_override(&"separation", 8)
	var title := MenuScreen.label(caption)
	title.custom_minimum_size.x = 92
	add_child(title)
	slider = HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(150, 12)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	add_child(slider)
	_value_label = MenuScreen.label("", &"", HORIZONTAL_ALIGNMENT_RIGHT)
	_value_label.custom_minimum_size.x = 32
	add_child(_value_label)
	_show(value)
	slider.value_changed.connect(func(v: float) -> void:
		_show(int(v))
		value_changed.emit(int(v)))
	slider.focus_entered.connect(func() -> void:
		_mark(title, true)
		if not UiButton.quiet:
			Sfx.cue(&"ui_move", slider, true))
	slider.focus_exited.connect(_mark.bind(title, false))


func set_value_no_signal(value: int) -> void:
	slider.set_value_no_signal(value)
	_show(value)


func value() -> int:
	return int(slider.value)


## Focus is shown by the gold frame, a pointer arrow and a gold caption.
func _mark(title: Label, focused: bool) -> void:
	if focused:
		title.add_theme_color_override(&"font_color", UiTheme.GOLD)
	else:
		title.remove_theme_color_override(&"font_color")
	queue_redraw()


func _draw() -> void:
	if slider != null and slider.has_focus():
		draw_texture(UiTheme.icon(UiTheme.ICON_ARROW), Vector2(-9, floorf((size.y - 8.0) * 0.5)))


func _show(value: int) -> void:
	_value_label.text = "%d%%" % value if value > 0 else "OFF"
