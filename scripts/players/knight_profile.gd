class_name KnightProfile
extends Resource
## Identity of one player: id, InputMap action names and palette.
## Knight scenes are identical; only the profile differs between Player One and Player Two.

@export_range(1, 2) var player_id := 1
@export var display_name := "Knight 1"

@export_group("Actions")
@export var action_left: StringName = &"p1_move_left"
@export var action_right: StringName = &"p1_move_right"
@export var action_up: StringName = &"p1_move_up"
@export var action_down: StringName = &"p1_move_down"
@export var action_attack: StringName = &"p1_attack"

@export_group("Palette")
## Replaces the knight sheet's green tunic (#0a7030).
@export var tunic_color := Color("0a7030")
## Replaces the knight sheet's red plume (#d2202c).
@export var plume_color := Color("d2202c")


func actions() -> Array[StringName]:
	return [action_left, action_right, action_up, action_down, action_attack]


## Returns the action names that are missing from the InputMap.
func missing_actions() -> PackedStringArray:
	var missing := PackedStringArray()
	for action in actions():
		if not InputMap.has_action(action):
			missing.append(action)
	return missing
