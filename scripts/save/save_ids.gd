class_name SaveIds
extends RefCounted
## Stable identities for saved state. Nothing saved ever depends on NodePaths or instance ids:
## every persistent entity carries an explicit id (`save_id`, `puzzle_id`, `collectible_id`)
## that is unique within its level, and the level is identified by its catalog id.

## Registry key prefix for enemies recorded as defeated in the run (PuzzleRegistry store).
const ENEMY_PREFIX := "enemy:"


## The id of the level `node` belongs to: the nearest ancestor's "level_id" metadata, else
## the nearest ancestor scene path ("" when not in a level).
static func level_key(node: Node) -> String:
	var at := node.get_parent()
	while at != null:
		if at.has_meta(&"level_id"):
			return str(at.get_meta(&"level_id"))
		if at.scene_file_path != "":
			return at.scene_file_path
		at = at.get_parent()
	return ""


## True for ids safe to store and compare: 1-64 chars of a-z, 0-9, _ - . : / and nothing
## path-like ("://" or ".."). Ids are only ever dictionary keys, never loaded as paths.
static func is_valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64 or id.contains("://") or id.contains(".."):
		return false
	for c in id:
		if not (c in "abcdefghijklmnopqrstuvwxyz0123456789_-.:/"):
			return false
	return true


## Every persistent id in `level` with the node(s) using it; ids used more than once are
## reported as "kind:id -> [paths]" (development validation; helpful error messages).
static func find_duplicates(level: Node) -> PackedStringArray:
	var seen := {}
	for node in level.find_children("*", "", true, false):
		var key := ""
		if node is PuzzleSource and node.puzzle_id != "":
			key = "puzzle:" + node.puzzle_id
		elif node is Collectible and node.collectible_id != "":
			key = "collectible:" + node.collectible_id
		elif "save_id" in node and str(node.get(&"save_id")) != "":
			key = "entity:" + str(node.get(&"save_id"))
		if key == "":
			continue
		if not seen.has(key):
			seen[key] = []
		seen[key].append(str(level.get_path_to(node)))
	var problems := PackedStringArray()
	for key: String in seen:
		if seen[key].size() > 1:
			problems.append("%s used by %s" % [key, ", ".join(seen[key])])
	return problems
