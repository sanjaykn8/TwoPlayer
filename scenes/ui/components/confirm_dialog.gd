class_name ConfirmDialog
extends MenuScreen
## A modal question with Cancel and Confirm (or a single OK for messages).
## Destructive questions (`danger`) start with focus on Cancel and show Confirm in red, so an
## accidental Enter never erases anything. Escape always cancels. The screen behind stays
## visible but cannot be focused or clicked until the dialog closes.

signal confirmed
signal cancelled

var title := ""
var message := ""
var confirm_text := "Confirm"
## "" = message box with a single button (confirm_text).
var cancel_text := "Cancel"
var danger := false

var confirm_button: UiButton
var cancel_button: UiButton
var _answered := false


static func create(dialog_title: String, text: String, confirm_label := "Confirm", cancel_label := "Cancel", destructive := false) -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d.title = dialog_title
	d.message = text
	d.confirm_text = confirm_label
	d.cancel_text = cancel_label
	d.danger = destructive
	d.opaque = false
	return d


func build() -> void:
	name = "ConfirmDialog"
	add_child(MenuScreen.dimmer(0.6))
	var box := MenuScreen.centered_panel(self, 300, &"DialogPanel")
	box.add_child(MenuScreen.label(title, &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(MenuScreen.wrapped(message, 300, &"", HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	box.add_child(row)
	if cancel_text != "":
		cancel_button = UiButton.new(cancel_text)
		cancel_button.name = "Cancel"
		cancel_button.custom_minimum_size.x = 90
		cancel_button.confirm_cue = &"ui_cancel"
		cancel_button.pressed.connect(_answer.bind(false))
		row.add_child(cancel_button)
	confirm_button = UiButton.new(confirm_text, &"DangerButton" if danger else &"")
	confirm_button.name = "Confirm"
	confirm_button.custom_minimum_size.x = 90
	confirm_button.pressed.connect(_answer.bind(true))
	row.add_child(confirm_button)
	MenuScreen.link_horizontal([cancel_button, confirm_button])


func first_focus() -> Control:
	return cancel_button if danger and cancel_button != null else confirm_button


func back() -> void:
	Sfx.cue(&"ui_cancel", self, true)
	_answer(false)


func _answer(yes: bool) -> void:
	if _answered:
		return
	_answered = true
	close()
	if yes or cancel_text == "":
		confirmed.emit()
	else:
		cancelled.emit()
