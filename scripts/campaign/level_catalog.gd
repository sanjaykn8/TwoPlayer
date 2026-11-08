class_name LevelCatalog
extends RefCounted
## The campaign registry: the only map from campaign ids to scenes, and the authority for
## level order, worlds, display names and music. Save files store ids, never paths, and an id
## that is not in the active campaign is rejected, so a save file can never make the game
## load an arbitrary scene.
##
## Two campaigns exist (CampaignDefinition resources written by tools/build_phase10_content.gd):
##   production  six worlds x four levels, the real game (default)
##   development the two Phase 8 test levels (w1_l1, w1_l2) used by the Phase 8-9 tests
## Only one is active at a time; tests that need the development levels call
## use_development() (the test runner switches back to production before every test).
## Only the active campaign's metadata is loaded; level scenes load one at a time.

const PRODUCTION_PATH := "res://resources/campaign/production_campaign.tres"
const DEVELOPMENT_PATH := "res://resources/campaign/development_campaign.tres"

## Saved enemy / object type ids -> scenes (used when an object must be re-created).
const ENTITY_SCENES := {
	"green_slime": "res://scenes/enemies/green_slime.tscn",
	"purple_slime": "res://scenes/enemies/purple_slime.tscn",
	"orc_grunt": "res://scenes/enemies/orc_grunt.tscn",
	"orc_brute": "res://scenes/enemies/orc_brute.tscn",
	"orc_guard": "res://scenes/enemies/orc_guard.tscn",
	"hollow_archer": "res://scenes/enemies/hollow_archer.tscn",
	"cave_bat": "res://scenes/enemies/cave_bat.tscn",
	"ember_slime": "res://scenes/enemies/ember_slime.tscn",
	"orc_warchief": "res://scenes/enemies/boss/orc_warchief.tscn",
	"hollow_captain": "res://scenes/enemies/boss/hollow_captain.tscn",
	"crowned_hollow": "res://scenes/enemies/boss/crowned_hollow.tscn",
	"dropped_coin": "res://scenes/objects/dropped_coin.tscn",
}

static var _path := PRODUCTION_PATH
static var _campaign: CampaignDefinition
static var _levels := {}
static var _worlds := {}
static var _order: Array[String] = []


static func use_production() -> void:
	_select(PRODUCTION_PATH)


static func use_development() -> void:
	_select(DEVELOPMENT_PATH)


static func _select(path: String) -> void:
	if path != _path:
		_path = path
		_campaign = null


static func campaign() -> CampaignDefinition:
	if _campaign == null:
		_campaign = load(_path) as CampaignDefinition
		_levels.clear()
		_worlds.clear()
		_order.clear()
		if _campaign == null:
			push_error("LevelCatalog: campaign %s missing" % _path)
			_campaign = CampaignDefinition.new()
		for world in _campaign.worlds:
			_worlds[world.id] = world
			for level in world.levels:
				_levels[level.id] = level
				_order.append(level.id)
	return _campaign


static func is_development() -> bool:
	return campaign().development


static func first_level() -> String:
	campaign()
	return _order[0] if not _order.is_empty() else ""


static func first_world() -> String:
	return world_of(first_level())


static func is_known_world(world_id: String) -> bool:
	campaign()
	return _worlds.has(world_id)


static func is_known_level(level_id: String) -> bool:
	campaign()
	return _levels.has(level_id)


static func level(level_id: String) -> LevelDefinition:
	campaign()
	return _levels.get(level_id)


static func world(world_id: String) -> WorldDefinition:
	campaign()
	return _worlds.get(world_id)


static func world_of(level_id: String) -> String:
	var def := level(level_id)
	return def.world_id if def != null else ""


static func scene_for(level_id: String) -> String:
	var def := level(level_id)
	return def.scene_path if def != null else ""


## The level after `level_id` in campaign order ("" after the last one).
static func next_level(level_id: String) -> String:
	campaign()
	var i := _order.find(level_id)
	return _order[i + 1] if i >= 0 and i + 1 < _order.size() else ""


static func previous_level(level_id: String) -> String:
	campaign()
	var i := _order.find(level_id)
	return _order[i - 1] if i > 0 else ""


static func is_final_level(level_id: String) -> bool:
	campaign()
	return not _order.is_empty() and _order.back() == level_id


static func all_levels() -> Array[String]:
	campaign()
	return _order.duplicate()


static func world_ids() -> Array[String]:
	var ids: Array[String] = []
	for w in campaign().worlds:
		ids.append(w.id)
	return ids


static func levels_of(world_id: String) -> Array[String]:
	var ids: Array[String] = []
	var w := world(world_id)
	if w != null:
		for l in w.levels:
			ids.append(l.id)
	return ids


static func world_title(world_id: String) -> String:
	var w := world(world_id)
	return w.title if w != null else world_id.to_upper()


static func level_title(level_id: String) -> String:
	var def := level(level_id)
	return def.title if def != null else level_id.to_upper()


## "Ancient Forest - The Mossy Gate" for a level id ("" for an unknown id).
static func location_title(level_id: String) -> String:
	if not is_known_level(level_id):
		return ""
	return "%s - %s" % [world_title(world_of(level_id)), level_title(level_id)]


## AudioConfig track for a level ("" when neither the level nor its world names one).
static func music_track(level_id: String) -> String:
	var def := level(level_id)
	if def == null:
		return ""
	if def.music_track != "":
		return def.music_track
	var w := world(def.world_id)
	return w.music_track if w != null else ""
