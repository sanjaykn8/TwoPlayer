class_name SaveTestUtil
extends RefCounted
## Helpers for Phase 8 tests. Tests only ever use folders under user://test_saves*/ , never
## the player's user://saves/.

const DIR := "user://test_saves/"
const GAME := "res://scenes/campaign/campaign_game.tscn"


## Deletes every file in `dir` (creating it if needed).
static func clean(dir := DIR) -> void:
	# Phase 8-9 save tests are written against the two development levels.
	LevelCatalog.use_development()
	RunState.reset()
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + file)


static func read(dir: String, file: String) -> String:
	return FileAccess.get_file_as_string(dir + file) if FileAccess.file_exists(dir + file) else ""


static func write(dir: String, file: String, text: String) -> void:
	var f := FileAccess.open(dir + file, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Re-signs an edited body so it passes the checksum (to test the validation behind it).
static func resign(body: String) -> String:
	return "%s %d %s\n%s" % [SaveSchema.MAGIC, SaveSchema.FORMAT_VERSION, body.sha256_text(), body]


static func body_of(text: String) -> String:
	return text.substr(text.find("\n") + 1)


## A CampaignGame added to `parent` but not begun (call begin()).
static func make_game(parent: Node, slot: int, mode: CampaignGame.StartMode, dir := DIR, overwrite := false) -> CampaignGame:
	var game := (load(GAME) as PackedScene).instantiate() as CampaignGame
	game.save_dir = dir
	game.slot = slot
	game.start_mode = mode
	game.overwrite = overwrite
	game.auto_begin = false
	game.wipe_delay = 0.1
	parent.add_child(game)
	return game
