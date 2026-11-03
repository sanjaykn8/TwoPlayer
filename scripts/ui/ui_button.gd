class_name UiButton
extends Button
## The game's menu button: the theme's gold frame plus a pointer arrow when focused (so the
## selection never relies on colour alone), menu sounds, and mouse hover that moves the
## keyboard focus (mouse and keyboard always agree on the selected button).

## Plays no "move" sound for focus changes made by code (opening a screen, restoring focus).
static var quiet := false

var confirm_cue := &"ui_confirm"


func _init(label := "", variation := &"") -> void:
	text = label
	theme_type_variation = variation
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(0, 15)


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func() -> void:
		if not disabled and focus_mode != FOCUS_NONE and not has_focus():
			grab_focus())
	pressed.connect(func() -> void:
		if confirm_cue != &"":
			Sfx.cue(confirm_cue, self, true))


## Focuses `control` without the navigation sound.
static func focus_quietly(control: Control) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	quiet = true
	control.grab_focus()
	quiet = false


func _on_focus_entered() -> void:
	queue_redraw()
	if not quiet:
		Sfx.cue(&"ui_move", self, true)


func _draw() -> void:
	if has_focus() and not disabled:
		var arrow := UiTheme.icon(UiTheme.ICON_ARROW)
		draw_texture(arrow, Vector2(-9, floorf((size.y - 8.0) * 0.5)))
