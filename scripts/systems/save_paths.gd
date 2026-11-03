class_name SavePaths
extends RefCounted
## Permanent save location (GDD section 18, D-12).
## `user://` resolves to %APPDATA%\TwoKnightCoop\ because project.godot sets
## application/config/use_custom_user_dir and custom_user_dir_name = "TwoKnightCoop".
## The Phase 8 SaveManager builds on this; nothing writes save data yet.

const USER_DIR_NAME := "TwoKnightCoop"
const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 4


static func slot_path(slot: int) -> String:
	assert(slot >= 1 and slot <= SLOT_COUNT, "Save slot must be 1-4")
	return SAVE_DIR + "slot_%d.json" % slot


## Creates user://saves/ if needed. Returns OK or the DirAccess error.
static func ensure_save_dir() -> Error:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return OK
	return DirAccess.make_dir_recursive_absolute(SAVE_DIR)


static func absolute_save_dir() -> String:
	return ProjectSettings.globalize_path(SAVE_DIR)
