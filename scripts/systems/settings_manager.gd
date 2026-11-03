class_name SettingsManager
extends RefCounted
## Player preferences, stored in user://settings.cfg (ConfigFile). Completely separate from
## the campaign saves in user://saves/: deleting a slot, a team wipe or a new campaign never
## touches this file, and this class never touches the saves.
##
## - Every value is validated on its own. A missing or malformed file, or one bad value, falls
##   back to the defaults for what is wrong and keeps everything else.
## - Audio values are bus volumes (0-100 %) applied to the real Master / Music / SFX buses.
## - Display: windowed or fullscreen, and a window scale (640x360 times 1, 2, 3, ...). The
##   game always renders at 640x360 and is scaled by whole numbers with letterboxing
##   (project stretch settings), so no setting can stretch or blur the pixel art.
## - Changes apply immediately and are saved at once (write to a temporary file, then
##   replace), so a crash never leaves a half-written settings file.

signal changed(key: String)

const PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_DISPLAY := "display"
const LOGICAL_SIZE := Vector2i(640, 360)
const MAX_SCALE := 8
const FORMAT_VERSION := 1

const DEFAULTS := {
	"master_volume": 80,
	"music_volume": 70,
	"sfx_volume": 80,
	"fullscreen": false,
	"window_scale": 2,
}
const AUDIO_KEYS: Array[String] = ["master_volume", "music_volume", "sfx_volume"]
const DISPLAY_KEYS: Array[String] = ["fullscreen", "window_scale"]
const BUS_FOR := {"master_volume": &"Master", "music_volume": &"Music", "sfx_volume": &"SFX"}

var path := PATH
var values := DEFAULTS.duplicate()
## Problems found by the last load (bad values replaced by defaults).
var warnings := PackedStringArray()
## What the last apply_display() asked the window for: {"fullscreen": bool, "size": Vector2i}.
var last_display_request := {}
var last_error := ""
## false: apply_display() records the request but leaves the window alone (tests).
var touch_window := true


func _init(settings_path := PATH) -> void:
	path = settings_path


# --- Loading and saving ------------------------------------------------------------------

## Reads the file. Missing file: defaults. Returns OK, or ERR_PARSE_ERROR when lines were
## unreadable (defaults are used for everything that could not be read; invalid values are
## replaced by defaults and listed in `warnings`). The file is parsed here line by line rather than with
## ConfigFile.load(), so a damaged line is skipped on its own and never stops the others.
func load_settings() -> Error:
	values = DEFAULTS.duplicate()
	warnings.clear()
	if not FileAccess.file_exists(path):
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		warnings.append("settings file unreadable (%s); defaults used" % error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	var data := parse_ini(file.get_as_text(), warnings)
	file.close()
	var unreadable := not warnings.is_empty()
	for key: String in AUDIO_KEYS:
		_read(data, SECTION_AUDIO, key)
	for key: String in DISPLAY_KEYS:
		_read(data, SECTION_DISPLAY, key)
	return ERR_PARSE_ERROR if unreadable else OK


## The subset of the ConfigFile text format this file uses: [section] lines and key=value
## lines whose value is an integer, a decimal number, true/false or a quoted string.
## Returns {section: {key: value}}; unreadable lines are reported in `problems` and skipped.
static func parse_ini(text: String, problems: PackedStringArray) -> Dictionary:
	var data := {}
	var section := ""
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]") and line.length() > 2:
			section = line.substr(1, line.length() - 2).strip_edges()
			continue
		var eq := line.find("=")
		if eq <= 0 or section == "":
			problems.append("line %d unreadable" % number)
			continue
		var value: Variant = _parse_value(line.substr(eq + 1).strip_edges())
		if value == null:
			problems.append("line %d has an unreadable value" % number)
			continue
		if not data.has(section):
			data[section] = {}
		data[section][line.substr(0, eq).strip_edges()] = value
	return data


static func _parse_value(text: String) -> Variant:
	if text == "true" or text == "false":
		return text == "true"
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return null


func save_settings() -> Error:
	var file := ConfigFile.new()
	file.set_value("meta", "version", FORMAT_VERSION)
	for key: String in AUDIO_KEYS:
		file.set_value(SECTION_AUDIO, key, values[key])
	for key: String in DISPLAY_KEYS:
		file.set_value(SECTION_DISPLAY, key, values[key])
	var temp := path + ".tmp"
	var err := file.save(temp)
	if err == OK:
		err = DirAccess.rename_absolute(temp, path)
	if err != OK:
		last_error = "could not save settings: %s" % error_string(err)
		push_warning(last_error)
	return err


func _read(data: Dictionary, section: String, key: String) -> void:
	if not data.has(section) or not data[section].has(key):
		return
	var raw: Variant = data[section][key]
	var clean: Variant = sanitize(key, raw)
	if clean == null:
		warnings.append("%s: invalid value %s; default used" % [key, str(raw)])
		return
	values[key] = clean


## Returns the valid form of `value` for `key`, or null when it cannot be used.
static func sanitize(key: String, value: Variant) -> Variant:
	match key:
		"master_volume", "music_volume", "sfx_volume":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return null
			if is_nan(float(value)) or float(value) < 0.0 or float(value) > 100.0:
				return null
			return roundi(float(value))
		"fullscreen":
			return value if typeof(value) == TYPE_BOOL else null
		"window_scale":
			if typeof(value) != TYPE_INT or int(value) < 1 or int(value) > MAX_SCALE:
				return null
			return int(value)
	return null


# --- Reading and changing values ----------------------------------------------------------

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


## Validates, stores, applies and saves one value. Returns false (nothing changes) if invalid.
func set_value(key: String, value: Variant, save := true) -> bool:
	if not DEFAULTS.has(key):
		return false
	var clean: Variant = sanitize(key, value)
	if clean == null:
		return false
	if key == "window_scale":
		clean = clampi(int(clean), 1, int(available_scales().back()))
	if values[key] == clean:
		return true
	values[key] = clean
	if key in AUDIO_KEYS:
		apply_audio()
	else:
		apply_display()
	if save:
		save_settings()
	changed.emit(key)
	return true


func reset_audio() -> void:
	for key: String in AUDIO_KEYS:
		set_value(key, DEFAULTS[key], false)
	save_settings()


func reset_display() -> void:
	for key: String in DISPLAY_KEYS:
		set_value(key, DEFAULTS[key], false)
	save_settings()


# --- Applying -------------------------------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	apply_display()


func apply_audio() -> void:
	for key: String in AUDIO_KEYS:
		AudioManager.set_bus_percent(BUS_FOR[key], int(values[key]))


## Fullscreen, or a centred window of 640x360 times the chosen scale.
func apply_display() -> void:
	var fullscreen: bool = values.fullscreen
	var scale := clampi(int(values.window_scale), 1, int(available_scales().back()))
	var size := LOGICAL_SIZE * scale
	last_display_request = {"fullscreen": fullscreen, "size": size}
	if not touch_window or DisplayServer.get_name() == "headless":
		return
	var window := (Engine.get_main_loop() as SceneTree).root
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window.size = size
	window.move_to_center()


## Window scales that fit the current screen (always includes 1). Without a known screen
## (headless), 1-3.
static func available_scales() -> Array[int]:
	var scales: Array[int] = [1]
	var usable := DisplayServer.screen_get_usable_rect().size
	if usable.x <= 0 or usable.y <= 0:
		return [1, 2, 3]
	for s in range(2, MAX_SCALE + 1):
		if LOGICAL_SIZE.x * s <= usable.x and LOGICAL_SIZE.y * s <= usable.y:
			scales.append(s)
	return scales


static func resolution_label(scale: int) -> String:
	var size := LOGICAL_SIZE * scale
	return "%d x %d" % [size.x, size.y]
