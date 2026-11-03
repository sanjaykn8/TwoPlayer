class_name LevelCatalog
extends RefCounted
## The only map from campaign ids to scenes. Save files store ids, never paths, and an id
## that is not listed here is rejected, so a save file can never make the game load an
## arbitrary scene. Production worlds are added here in Phase 10.

const FIRST_WORLD := "w1"
const FIRST_LEVEL := "w1_l1"

## world id -> ordered level ids
const WORLDS := {
	"w1": ["w1_l1", "w1_l2"],
}

## level id -> scene (development campaign levels for Phase 8)
const LEVELS := {
	"w1_l1": "res://scenes/levels/w1/w1_l1.tscn",
	"w1_l2": "res://scenes/levels/w1/w1_l2.tscn",
}

## Display names (HUD, save-slot cards, victory screen). Plain structural names until the
## production worlds get their final names in Phase 10.
const WORLD_TITLES := {
	"w1": "World 1",
}
const LEVEL_TITLES := {
	"w1_l1": "Level 1",
	"w1_l2": "Level 2",
}
## The catalog currently holds only the two development levels built for Phase 8 testing,
## not the 24-level campaign. Screens say so instead of claiming a finished campaign.
const DEVELOPMENT_CAMPAIGN := true

## Saved enemy / object type ids -> scenes (used when an object must be re-created).
const ENTITY_SCENES := {
	"green_slime": "res://scenes/enemies/green_slime.tscn",
	"purple_slime": "res://scenes/enemies/purple_slime.tscn",
	"dropped_coin": "res://scenes/objects/dropped_coin.tscn",
}


static func is_known_world(world_id: String) -> bool:
	return WORLDS.has(world_id)


static func is_known_level(level_id: String) -> bool:
	return LEVELS.has(level_id)


static func world_of(level_id: String) -> String:
	for world_id: String in WORLDS:
		if (WORLDS[world_id] as Array).has(level_id):
			return world_id
	return ""


static func scene_for(level_id: String) -> String:
	return LEVELS.get(level_id, "")


## The level after `level_id` in campaign order ("" after the last one).
static func next_level(level_id: String) -> String:
	var order := all_levels()
	var i := order.find(level_id)
	return order[i + 1] if i >= 0 and i + 1 < order.size() else ""


static func all_levels() -> Array[String]:
	var order: Array[String] = []
	for world_id: String in WORLDS:
		for level_id: String in WORLDS[world_id]:
			order.append(level_id)
	return order


static func world_title(world_id: String) -> String:
	return WORLD_TITLES.get(world_id, world_id.to_upper())


static func level_title(level_id: String) -> String:
	return LEVEL_TITLES.get(level_id, level_id.to_upper())


## "World 1 - Level 2" for a level id ("" for an unknown id).
static func location_title(level_id: String) -> String:
	if not is_known_level(level_id):
		return ""
	return "%s - %s" % [world_title(world_of(level_id)), level_title(level_id)]
