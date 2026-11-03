class_name UiStack
extends Control
## The navigation stack of menu screens and dialogs (the NavigationController).
## - Only the top screen is interactive; the others have focus and mouse input disabled.
## - An opaque screen hides everything below it; a dialog leaves the screen below visible.
## - Escape (ui_cancel) goes to the top screen's back(); nothing below ever sees it.
## - Popping a screen re-activates the one below, which restores its previous focus.

signal top_changed(screen: MenuScreen)

var screens: Array[MenuScreen] = []


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func top() -> MenuScreen:
	return screens.back() if not screens.is_empty() else null


func is_empty() -> bool:
	return screens.is_empty()


func push(screen: MenuScreen, app: GameApp = null) -> MenuScreen:
	var below := top()
	if below != null:
		below.deactivate()
	screen.stack = self
	if app != null:
		screen.app = app
	screens.append(screen)
	add_child(screen)
	_refresh_visibility()
	screen.activate()
	top_changed.emit(screen)
	return screen


## Removes `screen` (and anything above it).
func pop(screen: MenuScreen) -> void:
	var index := screens.find(screen)
	if index < 0:
		return
	while screens.size() > index:
		var removed: MenuScreen = screens.pop_back()
		remove_child(removed)
		removed.closed.emit(removed)
		removed.queue_free()
	_refresh_visibility()
	var now := top()
	if now != null:
		now.activate()
	top_changed.emit(now)


func clear() -> void:
	if not screens.is_empty():
		pop(screens[0])


## The first screen of a given script class on the stack, or null.
func find_screen(script_class: Script) -> MenuScreen:
	for s in screens:
		if s.get_script() == script_class:
			return s
	return null


func _refresh_visibility() -> void:
	var hidden := false
	for i in range(screens.size() - 1, -1, -1):
		screens[i].visible = not hidden
		if screens[i].opaque:
			hidden = true


func _unhandled_input(event: InputEvent) -> void:
	if screens.is_empty() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	top().back()
