class_name MenuScreen
extends Control
## Base class of every menu screen and dialog. Screens live on a UiStack; only the top screen
## is interactive. A screen builds its widgets in build(), names the control that gets focus
## first in first_focus(), and reacts to Escape in back() (default: close).
##
## - `opaque` screens hide the screens below them; dialogs (opaque = false) keep them visible
##   but disabled, so nothing behind a dialog can be focused, clicked or activated.
## - Returning to a screen restores the control that had focus when it was covered.
## - Screens never read save files or change campaign state themselves: they call GameApp
##   (`app`), which uses SaveManager, CampaignGame, SettingsManager and AudioManager.

signal closed(screen: MenuScreen)

var app: GameApp
var stack: UiStack
var opaque := true

var _remembered: Control
var _built := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	if not _built:
		_built = true
		build()


## Creates the screen's widgets (called once, on entering the tree).
func build() -> void:
	pass


## The control that receives focus when the screen opens.
func first_focus() -> Control:
	return null


## Escape. Default: close this screen.
func back() -> void:
	Sfx.cue(&"ui_cancel", self, true)
	close()


func close() -> void:
	if stack != null:
		stack.pop(self)


func is_top() -> bool:
	return stack != null and stack.top() == self


## Called by the stack when this screen becomes the top one.
func activate() -> void:
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	var target := _remembered if _can_focus(_remembered) else first_focus()
	if not _can_focus(target):
		target = _find_focusable(self)
	UiButton.focus_quietly(target)


## Called by the stack when another screen covers this one.
func deactivate() -> void:
	var owner_now := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner_now != null and is_ancestor_of(owner_now):
		_remembered = owner_now
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED


static func _can_focus(control: Control) -> bool:
	return control != null and is_instance_valid(control) and control.is_visible_in_tree() \
		and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and (control as BaseButton).disabled)


static func _find_focusable(root: Node) -> Control:
	for child in root.get_children():
		if child is Control and _can_focus(child):
			return child
		var found := _find_focusable(child)
		if found != null:
			return found
	return null


# --- Building helpers ---------------------------------------------------------------------

static func label(text: String, variation := &"", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrapped(text: String, width: float, variation := &"", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, variation, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


## A centred column of buttons. Up/Down wrap around at the ends.
static func link_vertical(buttons: Array) -> void:
	var usable: Array[Control] = []
	for b: Control in buttons:
		if b != null:
			usable.append(b)
	for i in usable.size():
		var prev := usable[(i - 1 + usable.size()) % usable.size()]
		var next := usable[(i + 1) % usable.size()]
		usable[i].focus_neighbor_top = usable[i].get_path_to(prev)
		usable[i].focus_neighbor_bottom = usable[i].get_path_to(next)
		usable[i].focus_previous = usable[i].get_path_to(prev)
		usable[i].focus_next = usable[i].get_path_to(next)


## A row of buttons. Left/Right wrap around; Up/Down stay in the row.
static func link_horizontal(buttons: Array) -> void:
	var usable: Array[Control] = []
	for b: Control in buttons:
		if b != null:
			usable.append(b)
	for i in usable.size():
		var prev := usable[(i - 1 + usable.size()) % usable.size()]
		var next := usable[(i + 1) % usable.size()]
		usable[i].focus_neighbor_left = usable[i].get_path_to(prev)
		usable[i].focus_neighbor_right = usable[i].get_path_to(next)
		usable[i].focus_previous = usable[i].get_path_to(prev)
		usable[i].focus_next = usable[i].get_path_to(next)
		usable[i].focus_neighbor_top = usable[i].get_path_to(usable[i])
		usable[i].focus_neighbor_bottom = usable[i].get_path_to(usable[i])


## A full-screen dark backing for screens drawn over gameplay.
static func dimmer(alpha := 0.72) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(UiTheme.BG, alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


## A centred panel with a vertical box inside; returns the box.
static func centered_panel(parent: Control, min_width: float, variation := &"") -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.custom_minimum_size.x = min_width
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	return box
