extends SceneTree
## Builds the production campaign (Phase 10) and both campaign registries.
## Run:  godot --headless --path . --script res://tools/build_phase10_content.gd [-- world_n ...]
## Writes:
##   scenes/worlds/world_0N_<name>/level_NN.tscn       one scene per level spec
##   resources/campaign/production_campaign.tres      worlds and levels in order (registry)
##   resources/campaign/development_campaign.tres     the two Phase 8 test levels (tests only)
## Level specs: tools/campaign/world_1.gd .. world_6.gd. Edit the specs, then re-run this.

const Builder := preload("res://tools/campaign/campaign_builder.gd")
const Themes := preload("res://tools/campaign/themes.gd")
const WORLD_SCRIPTS := [
	"res://tools/campaign/world_1.gd", "res://tools/campaign/world_2.gd", "res://tools/campaign/world_3.gd",
	"res://tools/campaign/world_4.gd", "res://tools/campaign/world_5.gd", "res://tools/campaign/world_6.gd",
]
const PRODUCTION := "res://resources/campaign/production_campaign.tres"
const DEVELOPMENT := "res://resources/campaign/development_campaign.tres"


func _initialize() -> void:
	var campaign := CampaignDefinition.new()
	campaign.id = "main"
	campaign.title = "Main campaign"
	var order := 0
	var failed := false
	for path: String in WORLD_SCRIPTS:
		if not ResourceLoader.exists(path):
			print("skip %s (not written yet)" % path)
			continue
		var script: GDScript = load(path)
		var w: Dictionary = script.get(&"WORLD")
		var world := WorldDefinition.new()
		world.id = w.id
		world.title = w.title
		world.theme = w.theme
		world.music_track = w.music
		for spec: Dictionary in script.call(&"levels"):
			order += 1
			var builder := Builder.new()
			var root := builder.build(spec, Themes.THEMES[w.theme])
			var scene_path := "res://scenes/worlds/%s/level_%02d.tscn" % [w.dir, order]
			DirAccess.make_dir_recursive_absolute(scene_path.get_base_dir())
			var packed := PackedScene.new()
			var err := packed.pack(root)
			if err == OK:
				err = ResourceSaver.save(packed, scene_path)
			if err != OK or not builder.errors.is_empty():
				failed = true
				printerr("FAILED %s: %s %s" % [spec.id, error_string(err), builder.errors])
			world.levels.append(_definition(spec, w, order, scene_path, root, builder))
			print("built %s %-24s %s" % [spec.id, spec.title, scene_path])
			root.free()
		campaign.worlds.append(world)
	_save(campaign, PRODUCTION)
	_save(_development(), DEVELOPMENT)
	quit(1 if failed else 0)


func _definition(spec: Dictionary, w: Dictionary, order: int, scene_path: String, root: Node2D, builder) -> LevelDefinition:
	var def := LevelDefinition.new()
	def.id = spec.id
	def.title = spec.title
	def.world_id = w.id
	def.order = order
	def.scene_path = scene_path
	def.difficulty = spec.difficulty
	def.estimated_minutes = spec.minutes
	def.theme = w.theme
	def.spawn_p1 = (root.get_node("SpawnP1") as Node2D).position
	def.spawn_p2 = (root.get_node("SpawnP2") as Node2D).position
	def.camera_bounds = Rect2(Vector2.ZERO, Vector2(spec.width, spec.height) * 16.0)
	var optional := PackedStringArray()
	for node in root.find_children("*", "", true, false):
		if node is Collectible and node.collectible_id != "":
			optional.append(node.collectible_id)
		elif node is BossSlime:
			optional.append(node.save_id)
			def.boss_id = node.save_id
	def.optional_content = optional
	return def


## The Phase 8 test levels as their own small campaign (used only by tests and dev rooms).
func _development() -> CampaignDefinition:
	var dev := CampaignDefinition.new()
	dev.id = "development"
	dev.title = "Development campaign"
	dev.development = true
	var world := WorldDefinition.new()
	world.id = "w1"
	world.title = "World 1"
	world.theme = "forest"
	world.music_track = "world_1"
	for i in 2:
		var def := LevelDefinition.new()
		def.id = "w1_l%d" % (i + 1)
		def.title = "Level %d" % (i + 1)
		def.world_id = "w1"
		def.order = i + 1
		def.scene_path = "res://scenes/levels/w1/w1_l%d.tscn" % (i + 1)
		def.theme = "forest"
		def.spawn_p1 = Vector2(40, 448)
		def.spawn_p2 = Vector2(72, 448)
		world.levels.append(def)
	dev.worlds.append(world)
	return dev


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	print("%s %s" % ["wrote" if err == OK else "FAILED", path])
