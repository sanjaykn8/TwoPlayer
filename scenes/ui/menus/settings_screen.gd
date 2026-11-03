class_name SettingsScreen
extends MenuScreen
## Audio volumes (Master, Music, Effects) and display mode / window size. Every change goes
## to SettingsManager, which applies it at once (real audio buses, the real window) and saves
## user://settings.cfg. Opened from the main menu or the pause menu; Back returns there with
## the game still paused.

var settings: SettingsManager
var sliders := {}
var mode_option: OptionStepper
var size_option: OptionStepper
var reset_audio_button: UiButton
var reset_display_button: UiButton
var back_button: UiButton

var _scales: Array[int] = []


func build() -> void:
	name = "SettingsScreen"
	if settings == null and app != null:
		settings = app.settings
	if settings == null:
		# Opened on its own (editor preview): the player's settings, read from disk.
		settings = SettingsManager.new()
		settings.load_settings()
	add_child(MenuScreen.dimmer(0.9))
	var box := MenuScreen.centered_panel(self, 330)
	box.add_child(MenuScreen.label("SETTINGS", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(MenuScreen.label("AUDIO", &"HeaderLabel"))
	for spec: Array in [["master_volume", "Master"], ["music_volume", "Music"], ["sfx_volume", "Effects"]]:
		var s := SettingsSlider.new(spec[1], int(settings.get_value(spec[0])))
		s.name = str(spec[0]).to_pascal_case()
		s.value_changed.connect(_on_volume.bind(spec[0]))
		box.add_child(s)
		sliders[spec[0]] = s
	reset_audio_button = UiButton.new("Reset audio")
	reset_audio_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset_audio_button.custom_minimum_size.x = 110
	reset_audio_button.pressed.connect(func() -> void:
		settings.reset_audio()
		_sync())
	box.add_child(reset_audio_button)

	box.add_child(MenuScreen.label("DISPLAY", &"HeaderLabel"))
	mode_option = OptionStepper.new("Mode", PackedStringArray(["Windowed", "Fullscreen"]), 1 if settings.get_value("fullscreen") else 0)
	mode_option.name = "Mode"
	mode_option.option_changed.connect(func(i: int) -> void:
		settings.set_value("fullscreen", i == 1)
		_sync())
	box.add_child(mode_option)
	size_option = OptionStepper.new("Window size", PackedStringArray(), 0)
	size_option.name = "WindowSize"
	size_option.option_changed.connect(func(i: int) -> void:
		settings.set_value("window_scale", _scales[i]))
	box.add_child(size_option)
	box.add_child(MenuScreen.label("The picture is always scaled by whole steps to stay sharp.", &"DimLabel"))
	reset_display_button = UiButton.new("Reset display")
	reset_display_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset_display_button.custom_minimum_size.x = 110
	reset_display_button.pressed.connect(func() -> void:
		settings.reset_display()
		_sync())
	box.add_child(reset_display_button)

	back_button = UiButton.new("Back")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.custom_minimum_size.x = 120
	back_button.confirm_cue = &"ui_cancel"
	back_button.pressed.connect(close)
	box.add_child(back_button)
	_sync()


func first_focus() -> Control:
	return (sliders["master_volume"] as SettingsSlider).slider


## Shows the manager's current values and rebuilds the focus order.
func _sync() -> void:
	for key: String in sliders:
		(sliders[key] as SettingsSlider).set_value_no_signal(int(settings.get_value(key)))
	var fullscreen: bool = settings.get_value("fullscreen")
	mode_option.set_options(PackedStringArray(["Windowed", "Fullscreen"]), 1 if fullscreen else 0)
	_scales = SettingsManager.available_scales()
	var labels := PackedStringArray()
	for s in _scales:
		labels.append(SettingsManager.resolution_label(s))
	size_option.set_options(labels, maxi(_scales.find(int(settings.get_value("window_scale"))), 0))
	size_option.button.disabled = fullscreen
	size_option.button.focus_mode = Control.FOCUS_NONE if fullscreen else Control.FOCUS_ALL
	var order: Array = []
	for key in ["master_volume", "music_volume", "sfx_volume"]:
		order.append((sliders[key] as SettingsSlider).slider)
	order.append(reset_audio_button)
	order.append(mode_option.button)
	if not fullscreen:
		order.append(size_option.button)
	order.append(reset_display_button)
	order.append(back_button)
	MenuScreen.link_vertical(order)


func _on_volume(value: int, key: String) -> void:
	settings.set_value(key, value)
	# Preview: an effects sound at the new volume (music is already playing).
	if key != "music_volume":
		Sfx.cue(&"ui_move", self, true)
