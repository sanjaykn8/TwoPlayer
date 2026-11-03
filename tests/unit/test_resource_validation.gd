extends GameTestCase
## Static validation: every script parses, every scene/resource loads and instantiates,
## exported NodePaths resolve, signal connections are valid, collision shapes exist,
## and game code contains no network APIs (offline requirement).

const SKIP_DIRS := ["res://.godot", "res://addons", "res://tools"]
const NETWORK_TOKENS := ["HTTPRequest", "HTTPClient", "StreamPeerTCP", "StreamPeerTLS",
	"WebSocketPeer", "ENetMultiplayerPeer", "PacketPeerUDP", "http://", "https://"]


func _collect(dir_path: String, extensions: PackedStringArray, out: PackedStringArray) -> void:
	if dir_path in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension() in extensions:
			out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), extensions, out)


func test_all_scripts_parse() -> void:
	var scripts: PackedStringArray = []
	_collect("res://", ["gd"], scripts)
	assert_gt(scripts.size(), 10, "found project scripts")
	# A script with parse or compile errors fails to load or cannot be instantiated.
	# (Calling reload() on scripts that are in use is unsafe, so it is not used here.)
	for path in scripts:
		var script := load(path) as GDScript
		if script == null:
			fail("%s failed to load" % path)
			continue
		assert_true(script.can_instantiate(), "%s compiles" % path)


func test_all_resources_and_scenes_load() -> void:
	var files: PackedStringArray = []
	_collect("res://", ["tscn", "tres", "gdshader"], files)
	assert_gt(files.size(), 8, "found project resources")
	for path in files:
		var res := load(path)
		assert_true(res != null, "%s loads" % path)
		for dep in ResourceLoader.get_dependencies(path):
			var dep_path := dep.get_slice("::", 2) if dep.contains("::") else dep
			assert_true(ResourceLoader.exists(dep_path), "%s dependency exists: %s" % [path, dep_path])


func test_scenes_instantiate_with_valid_paths_signals_and_shapes() -> void:
	var scenes: PackedStringArray = []
	_collect("res://scenes", ["tscn"], scenes)
	for path in scenes:
		var packed := load(path) as PackedScene
		if packed == null:
			fail("%s is not a PackedScene" % path)
			continue
		var instance := packed.instantiate()
		if instance == null:
			fail("%s failed to instantiate" % path)
			continue
		add_child(instance)
		await get_tree().physics_frame
		_check_tree(instance, path)
		instance.queue_free()
		await get_tree().process_frame


func _check_tree(node: Node, scene_path: String) -> void:
	for prop in node.get_property_list():
		if prop.type == TYPE_NODE_PATH and prop.usage & PROPERTY_USAGE_STORAGE:
			var np: NodePath = node.get(prop.name)
			if not np.is_empty() and node.get_node_or_null(np) == null:
				fail("%s: %s.%s points to missing node %s" % [scene_path, node.name, prop.name, np])
	for sig in node.get_signal_list():
		for connection in node.get_signal_connection_list(sig.name):
			var callable: Callable = connection.callable
			if not callable.is_valid():
				fail("%s: %s.%s has an invalid connection" % [scene_path, node.name, sig.name])
	if node is CollisionShape2D and (node as CollisionShape2D).shape == null:
		fail("%s: %s has no shape" % [scene_path, node.get_path()])
	if node is CollisionObject2D and node.get_shape_owners().is_empty():
		fail("%s: %s has no collision shapes" % [scene_path, node.get_path()])
	for child in node.get_children(true):
		_check_tree(child, scene_path)


func test_game_code_is_offline() -> void:
	var scripts: PackedStringArray = []
	_collect("res://scenes", ["gd"], scripts)
	_collect("res://scripts", ["gd"], scripts)
	_collect("res://components", ["gd"], scripts)
	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		for token: String in NETWORK_TOKENS:
			assert_false(text.contains(token), "%s must not use %s" % [path, token])


func test_knight_sprite_frames() -> void:
	var frames: SpriteFrames = load("res://resources/players/knight_frames.tres")
	for anim: StringName in [&"idle", &"run", &"jump", &"fall", &"crouch", &"climb", &"hurt", &"death"]:
		assert_true(frames.has_animation(anim), "animation %s exists" % anim)
	assert_eq(frames.get_frame_count(&"idle"), 4, "idle frames")
	assert_eq(frames.get_frame_count(&"run"), 16, "run frames")
	assert_eq(frames.get_frame_count(&"hurt"), 4, "hurt frames")
	# Label cells in the sheet ("IDLE", "RUN", "ROLL", "HIT", "DEATH") must never be used.
	var label_cells := [Vector2i(4, 0), Vector2i(5, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 4),
		Vector2i(1, 4), Vector2i(4, 6), Vector2i(5, 6), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7)]
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			var tex := frames.get_frame_texture(anim, i) as AtlasTexture
			var cell := Vector2i(tex.region.position / 32.0)
			assert_false(cell in label_cells, "%s frame %d uses label cell %s" % [anim, i, cell])
