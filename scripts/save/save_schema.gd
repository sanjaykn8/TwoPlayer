class_name SaveSchema
extends RefCounted
## The save file format. Plain, inspectable JSON (no objects, resources or callables):
##
##   TKCSAVE <format_version> <sha256 of the body text>\n
##   { "format_version": 1, "header": {...}, "run": {...}, "world": {...} }
##
## The checksum covers the exact body text, so truncation or any changed byte is detected
## (JSON numbers come back as floats, so re-serialising cannot be used for checking).
## header  slot, campaign_id, saved_at (unix + ISO), game_version, world_id, level_id,
##         playtime, coins, per-player health summary (metadata without loading the world)
## run     RunState.snapshot(): coins, collected ids, both PlayerStats (health, upgrades,
##         poison tier, timed effects with remaining seconds and charges), puzzle registry
##         (completed locks, latched gates/switches, defeated enemies), campaign position
## world   WorldSnapshot of the current level ({} for a level not yet started)

const MAGIC := "TKCSAVE"
const FORMAT_VERSION := 1
const GAME_VERSION := "dev-phase10"
const MAX_COINS := 10000000
const MAX_PLAYTIME := 1.0e8


static func build(slot: int, run: RunState, world: Dictionary) -> Dictionary:
	var players := {}
	for id in RunState.PLAYER_IDS:
		var stats := run.player(id)
		var hp := stats.health.current_health if stats.health != null and is_instance_valid(stats.health) else stats.current_health
		players[str(id)] = {"health": hp, "max_health": stats.max_health()}
	var now := Time.get_unix_time_from_system()
	return {
		"format_version": FORMAT_VERSION,
		"header": {
			"slot": slot,
			"campaign_id": run.campaign.campaign_id,
			"saved_at_unix": now,
			"saved_at": Time.get_datetime_string_from_unix_time(int(now), true),
			"game_version": GAME_VERSION,
			"world_id": run.campaign.world_id,
			"level_id": run.campaign.level_id,
			"playtime": run.campaign.playtime,
			"coins": run.coins,
			"players": players,
			"finished": bool(run.campaign.flags.get("finished", false)),
			"levels_completed": run.campaign.completed_levels.size(),
		},
		"run": run.snapshot(),
		"world": world,
	}


static func encode(doc: Dictionary) -> String:
	var body := JSON.stringify(doc, "\t", true)
	return "%s %d %s\n%s" % [MAGIC, FORMAT_VERSION, body.sha256_text(), body]


## Parses and fully validates file text. Returns {"ok": bool, "error": String, "doc": Dictionary}.
static func decode(text: String, expected_slot: int) -> Dictionary:
	var newline := text.find("\n")
	if text.is_empty():
		return _fail("empty file")
	if newline < 0:
		return _fail("missing header line")
	var head := text.substr(0, newline).split(" ")
	if head.size() != 3 or head[0] != MAGIC:
		return _fail("not a save file")
	if not head[1].is_valid_int():
		return _fail("bad format version")
	var version := head[1].to_int()
	var body := text.substr(newline + 1)
	if body.sha256_text() != head[2]:
		return _fail("checksum mismatch (file damaged or edited)")
	var json := JSON.new()  # the instance parser reports errors to us instead of the log
	if json.parse(body) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _fail("body is not valid JSON")
	var parsed: Dictionary = json.data
	var doc := migrate(parsed, version)
	if doc.is_empty():
		return _fail("unsupported format version %d" % version)
	var problem := validate(doc, expected_slot)
	if problem != "":
		return _fail(problem)
	return {"ok": true, "error": "", "doc": doc}


## Upgrades an older format to the current one. Returns {} when it cannot (newer or unknown
## versions are refused rather than guessed). Version 1 is the first disk format.
static func migrate(doc: Dictionary, version: int) -> Dictionary:
	if version != FORMAT_VERSION or int(doc.get("format_version", -1)) != version:
		return {}
	return doc


## "" when `doc` is a complete, consistent save for `expected_slot`; else the first problem.
static func validate(doc: Dictionary, expected_slot: int) -> String:
	for key in ["format_version", "header", "run", "world"]:
		if not doc.has(key):
			return "%s missing" % key
	var header: Variant = doc.header
	if typeof(header) != TYPE_DICTIONARY:
		return "header malformed"
	for key in ["slot", "campaign_id", "saved_at_unix", "game_version", "world_id", "level_id", "playtime", "coins", "players"]:
		if not header.has(key):
			return "header.%s missing" % key
	if int(header.slot) != expected_slot:
		return "save belongs to slot %d, not %d" % [int(header.slot), expected_slot]
	if not LevelCatalog.is_known_level(str(header.level_id)) or not LevelCatalog.is_known_world(str(header.world_id)):
		return "unknown world or level id (saved by a different campaign build)"
	var coins := float(header.coins)
	var time := float(header.playtime)
	if coins < 0 or coins > MAX_COINS or time < 0.0 or time > MAX_PLAYTIME:
		return "coins or playtime out of range"
	var run: Variant = doc.run
	if typeof(run) != TYPE_DICTIONARY or not run.has("campaign") or typeof(run.campaign) != TYPE_DICTIONARY:
		return "run section malformed"
	if str(run.campaign.get("campaign_id", "")) != str(header.campaign_id):
		return "header and run belong to different campaigns"
	if str(run.campaign.get("level_id", "")) != str(header.level_id):
		return "header and run disagree on the level"
	if int(run.get("coins", -1)) != int(header.coins) or float(run.get("coins", -1)) > MAX_COINS:
		return "coin totals disagree"
	# Every run field is validated by a throw-away RunState (nothing live changes).
	if not RunState.new().restore(run):
		return "run data invalid"
	for id in RunState.PLAYER_IDS:
		var player: Variant = run.players.get(str(id))
		if typeof(player) != TYPE_DICTIONARY or int(player.get("current_health", 0)) < 1:
			return "player %d is not alive in the save" % id
	for entry: Variant in run.collected:
		if not SaveIds.is_valid_id(str(entry.id)):
			return "invalid collectible id %s" % entry.id
	return WorldSnapshot.validate(doc.world, str(header.level_id))


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "doc": {}}
