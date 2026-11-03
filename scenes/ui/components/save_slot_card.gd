class_name SaveSlotCard
extends UiButton
## One save slot on the slot screen. Shows what SaveManager.get_slot_metadata() reports:
## slot number, status (EMPTY / ACTIVE / RECOVERED / CORRUPTED / INVALIDATED, always as a
## word, never colour alone), location, coins, both knights' health, play time and the
## local time of the last save. It never reads files itself.

const COIN_SHEET := preload("res://assets/sprites/coin.png")

const STATUS := {
	"EMPTY": ["EMPTY", UiTheme.TEXT_DIM, "No campaign in this slot."],
	"VALID": ["ACTIVE", UiTheme.OK_GREEN, ""],
	"RECOVERED": ["RECOVERED", UiTheme.WARNING, "Latest save damaged; this backup will load."],
	"CORRUPTED": ["CORRUPTED", UiTheme.DANGER, "The save file is damaged and cannot be loaded."],
	"INVALIDATED": ["INVALIDATED", UiTheme.DANGER, "This campaign was lost in a team wipe."],
}

var slot := 0
var meta := {}

var _title: Label
var _badge: Label
var _location: Label
var _p1: Label
var _p2: Label
var _coins: Label
var _time: Label
var _detail: Label
var _stats_row: HBoxContainer


func _init(slot_number := 1) -> void:
	super._init("", &"SlotCard")
	slot = slot_number
	name = "Slot%d" % slot
	custom_minimum_size = Vector2(440, 44)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	add_child(margin)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override(&"separation", 3)
	margin.add_child(lines)

	var top := _row(lines)
	_title = MenuScreen.label("SLOT %d" % slot, &"HeaderLabel")
	top.add_child(_title)
	_badge = MenuScreen.label("")
	top.add_child(_badge)
	_location = MenuScreen.label("", &"", HORIZONTAL_ALIGNMENT_RIGHT)
	_location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_location)

	_stats_row = _row(lines)
	_p1 = _stat(_stats_row, UiTheme.icon(UiTheme.ICON_HEART), UiTheme.P1)
	_p2 = _stat(_stats_row, UiTheme.icon(UiTheme.ICON_HEART), UiTheme.P2)
	_coins = _stat(_stats_row, UiTheme.sprite(COIN_SHEET, Rect2(4, 4, 8, 8)), UiTheme.TEXT)
	_time = MenuScreen.label("", &"", HORIZONTAL_ALIGNMENT_RIGHT)
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_row.add_child(_time)

	_detail = MenuScreen.label("", &"DimLabel")
	lines.add_child(_detail)


func status() -> String:
	return str(meta.get("status", "EMPTY"))


func status_word() -> String:
	return STATUS.get(status(), ["UNKNOWN"])[0]


func is_loadable() -> bool:
	return status() == "VALID" or status() == "RECOVERED"


func update_meta(data: Dictionary) -> void:
	meta = data
	var info: Array = STATUS.get(status(), ["UNKNOWN", UiTheme.DANGER, "Unknown slot state."])
	_badge.text = "[%s]" % info[0]
	_badge.add_theme_color_override(&"font_color", info[1])
	var valid := bool(meta.get("valid", false))
	_stats_row.visible = valid
	if valid:
		_location.text = LevelCatalog.location_title(str(meta.level_id))
		_p1.text = "P1 %d/%d" % [int(meta.p1_health), int(meta.p1_max_health)]
		_p2.text = "P2 %d/%d" % [int(meta.p2_health), int(meta.p2_max_health)]
		_coins.text = str(int(meta.coins))
		_time.text = "Time " + format_playtime(float(meta.playtime))
		var saved := "Saved " + format_local_time(float(meta.saved_at_unix))
		if bool(meta.get("finished", false)):
			saved = "CAMPAIGN COMPLETE - " + saved
		_detail.text = saved if str(info[2]) == "" else "%s %s" % [info[2], saved]
	else:
		_location.text = ""
		_detail.text = info[2]
		if status() == "CORRUPTED" and str(meta.get("warnings", [])).contains("different campaign build"):
			_detail.text = "Saved by an earlier development build; it cannot be loaded here."
	_detail.add_theme_color_override(&"font_color", UiTheme.TEXT_DIM if status() in ["VALID", "EMPTY"] else info[1])
	tooltip_text = ""


## "1:02:03" (hours:minutes:seconds) or "2:03" under an hour.
static func format_playtime(seconds: float) -> String:
	var total := maxi(int(seconds), 0)
	var h := total / 3600
	var m := (total / 60) % 60
	var s := total % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]


## A save time (UTC unix seconds) in the computer's local time: "2026-11-03 14:22".
static func format_local_time(unix_utc: float) -> String:
	if unix_utc <= 0.0:
		return "-"
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(unix_utc) + bias_minutes * 60)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]


static func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	parent.add_child(row)
	return row


static func _stat(parent: Control, icon_texture: Texture2D, colour: Color) -> Label:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 3)
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var l := MenuScreen.label("")
	l.add_theme_color_override(&"font_color", colour)
	box.add_child(l)
	parent.add_child(box)
	return l
