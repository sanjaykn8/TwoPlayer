class_name CampaignState
extends RefCounted
## Campaign progression of one run (owned by RunState, so a team wipe's RunState.reset()
## clears it with everything else): where the knights are, what is completed, play time,
## flags, and the run's unique `campaign_id`.
##
## `campaign_id` identifies this run. It is written into every save and is the token that
## rejects stale save requests and makes a run invalidated by a team wipe unloadable.

var campaign_id := ""
var world_id := LevelCatalog.first_world()
var level_id := LevelCatalog.first_level()
var completed_levels: Array[String] = []
## Seconds of actual play (counts only while a campaign scene runs unpaused).
var playtime := 0.0
## Campaign-wide flags (string -> bool / number / string), e.g. "finished".
var flags := {}
## Seconds of play each completed level took (level id -> seconds), measured from `playtime`.
var level_times := {}
## `playtime` when the current level was entered.
var level_started_at := 0.0


func _init() -> void:
	campaign_id = new_campaign_id()


static func new_campaign_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


func complete_level(id: String) -> void:
	if id != "" and not completed_levels.has(id):
		completed_levels.append(id)
		level_times[id] = maxf(playtime - level_started_at, 0.0)


func enter_level(id: String) -> bool:
	if not LevelCatalog.is_known_level(id):
		return false
	level_id = id
	world_id = LevelCatalog.world_of(id)
	level_started_at = playtime
	return true


func snapshot() -> Dictionary:
	return {
		"campaign_id": campaign_id,
		"world_id": world_id,
		"level_id": level_id,
		"completed_levels": completed_levels.duplicate(),
		"playtime": playtime,
		"flags": flags.duplicate(true),
		"level_times": level_times.duplicate(),
		"level_started_at": level_started_at,
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
	if time < 0.0 or time >= 1.0e8:
		return false
	# Optional (added in Phase 10): per-level completion times.
	if data.has("level_times"):
		if typeof(data.level_times) != TYPE_DICTIONARY:
			return false
		for key: Variant in data.level_times:
			var t := float(data.level_times[key])
			if not LevelCatalog.is_known_level(str(key)) or t < 0.0 or t > time + 1.0:
				return false
	var started := float(data.get("level_started_at", 0.0))
	return started >= 0.0 and started <= time + 1.0


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
	level_times.clear()
	for key: Variant in data.get("level_times", {}):
		level_times[str(key)] = float(data.level_times[key])
	level_started_at = float(data.get("level_started_at", 0.0))
	return true
