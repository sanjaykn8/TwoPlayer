class_name OptionStepper
extends HBoxContainer
## "Window size   < 1280 x 720 >": picks one of a few options without a popup. With focus,
## Left/Right (or Enter, or a click) step through the options; the choice applies at once.

signal option_changed(index: int)

var button: UiButton
var options: PackedStringArray = []
var index := 0


func _init(caption: String, choices: PackedStringArray, selected := 0) -> void:
	add_theme_constant_override(&"separation", 8)
	var title := MenuScreen.label(caption)
	title.custom_minimum_size.x = 92
	add_child(title)
	options = choices
	index = clampi(selected, 0, maxi(choices.size() - 1, 0))
	button = UiButton.new()
	button.name = "Value"
	button.custom_minimum_size.x = 190
	button.confirm_cue = &""
	add_child(button)
	button.pressed.connect(step.bind(1))
	button.gui_input.connect(_on_gui_input)
	_show()


func set_options(choices: PackedStringArray, selected: int) -> void:
	options = choices
	index = clampi(selected, 0, maxi(choices.size() - 1, 0))
	_show()


func step(direction: int) -> void:
	if options.size() < 2 or button.disabled:
		return
	index = wrapi(index + direction, 0, options.size())
	_show()
	Sfx.cue(&"ui_move", button, true)
	option_changed.emit(index)


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left", true):
		step(-1)
		button.accept_event()
	elif event.is_action_pressed(&"ui_right", true):
		step(1)
		button.accept_event()


func _show() -> void:
	var text := options[index] if index < options.size() else "-"
	button.text = "<  %s  >" % text if options.size() > 1 else text
