class_name ControlsScreen
extends MenuScreen
## Both players' keys side by side (fixed controls, GDD D-14) plus the few rules worth
## knowing: context-sensitive Up/Down, attack direction, no extra interact button.

const ROWS := [
	["Up / Jump / Climb", "W", "Up Arrow"],
	["Left", "A", "Left Arrow"],
	["Down / Crouch / Drop", "S", "Down Arrow"],
	["Right", "D", "Right Arrow"],
	["Attack", "V", "Left Alt / Right Alt"],
]

const NOTES := [
	"Both players share one keyboard: Player One on the left, Player Two on the right.",
	"Up and Down depend on where you are: climb a ladder, jump from the ground, drop through a thin platform, or crouch.",
	"Attacks go the way you last moved. Hold Up or Down while attacking to strike up or down (down only in the air or on a ladder).",
	"Keep attack held after a slash until you glint, then release: a heavy slash that breaks shields and cracked stone. Strike down in the air to bounce.",
	"Hit the same enemy together for a co-op strike. Jump off your partner's head to reach higher.",
	"There is no interact button: stand on plates and strike switches to work mechanisms.",
	"Esc pauses the game.",
]

var back_button: UiButton


func build() -> void:
	name = "ControlsScreen"
	add_child(MenuScreen.dimmer(0.92))
	var box := MenuScreen.centered_panel(self, 470)
	box.add_child(MenuScreen.label("CONTROLS", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.name = "Keys"
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 4)
	box.add_child(grid)
	grid.add_child(MenuScreen.label("Action", &"DimLabel"))
	var p1 := MenuScreen.label("PLAYER 1", &"HeaderLabel")
	p1.add_theme_color_override(&"font_color", UiTheme.P1)
	grid.add_child(p1)
	var p2 := MenuScreen.label("PLAYER 2", &"HeaderLabel")
	p2.add_theme_color_override(&"font_color", UiTheme.P2)
	grid.add_child(p2)
	for row: Array in ROWS:
		grid.add_child(MenuScreen.label(row[0]))
		var k1 := MenuScreen.label(row[1], &"HeaderLabel")
		k1.add_theme_color_override(&"font_color", UiTheme.P1.lightened(0.3))
		grid.add_child(k1)
		var k2 := MenuScreen.label(row[2], &"HeaderLabel")
		k2.add_theme_color_override(&"font_color", UiTheme.P2.lightened(0.3))
		grid.add_child(k2)
	box.add_child(HSeparator.new())
	for note: String in NOTES:
		box.add_child(MenuScreen.wrapped("- " + note, 470, &"DimLabel"))
	back_button = UiButton.new("Back")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.custom_minimum_size.x = 120
	back_button.confirm_cue = &"ui_cancel"
	back_button.pressed.connect(close)
	box.add_child(back_button)


func first_focus() -> Control:
	return back_button


## Every key named on this screen, for the accuracy test.
static func listed_keys() -> Dictionary:
	var keys := {1: [], 2: []}
	for row: Array in ROWS:
		keys[1].append(row[1])
		keys[2].append(row[2])
	return keys
