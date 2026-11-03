class_name CampaignState
extends RefCounted
## Campaign progression of one run (owned by RunState, so a team wipe's RunState.reset()
## clears it with everything else): where the knights are, what is completed, play time,
## flags, and the run's unique `campaign_id`.
##
## `campaign_id` identifies this run. It is written into every save and is the token that
## rejects stale save requests and makes a run invalidated by a team wipe unloadable.

var campaign_id := ""
var world_id := LevelCatalog.FIRST_WORLD
var level_id := LevelCatalog.FIRST_LEVEL
var completed_levels: Array[String] = []
## Seconds of actual play (counts only while a campaign scene runs unpaused).
var playtime := 0.0
## Campaign-wide flags (string -> bool / number / string), e.g. "finished".
var flags := {}


func _init() -> void:
	campaign_id = new_campaign_id()


static func new_campaign_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


func complete_level(id: String) -> void:
	if id != "" and not completed_levels.has(id):
		completed_levels.append(id)


func enter_level(id: String) -> bool:
	if not LevelCatalog.is_known_level(id):
		return false
	level_id = id
	world_id = LevelCatalog.world_of(id)
	return true


func snapshot() -> Dictionary:
	return {
		"campaign_id": campaign_id,
		"world_id": world_id,
		"level_id": level_id,
		"completed_levels": completed_levels.duplicate(),
		"playtime": playtime,
		"flags": flags.duplicate(true),
	}


## Validates first; nothing changes on failure.
static func is_valid_snapshot(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	for key in ["campaign_id", "world_id", "level_id", "completed_levels", "playtime", "flags"]:
		if not data.has(key):
			return false
	var id := str(data.campaign_id)
	if id.length() < 8 or id.length() > 64 or not id.is_valid_hex_number():
		return false
	if not LevelCatalog.is_known_level(str(data.level_id)):
		return false
	if LevelCatalog.world_of(str(data.level_id)) != str(data.world_id):
		return false
	if typeof(data.completed_levels) != TYPE_ARRAY or typeof(data.flags) != TYPE_DICTIONARY:
		return false
	for level: Variant in data.completed_levels:
		if not LevelCatalog.is_known_level(str(level)):
			return false
	var time := float(data.playtime)
	return time >= 0.0 and time < 1.0e8


func restore(data: Variant) -> bool:
	if not is_valid_snapshot(data):
		return false
	campaign_id = str(data.campaign_id)
	world_id = str(data.world_id)
	level_id = str(data.level_id)
	completed_levels.clear()
	for level: Variant in data.completed_levels:
		completed_levels.append(str(level))
	playtime = float(data.playtime)
	flags = (data.flags as Dictionary).duplicate(true)
	return true
