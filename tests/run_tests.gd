extends SceneTree
## Headless test runner. No plugins required.
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
## Optional filter: append `-- <substring>` to run only matching test files.
## Exit code is the number of failed tests (0 = all passed).

const TEST_DIRS := ["res://tests/unit", "res://tests/gameplay"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter := ""
	if not OS.get_cmdline_user_args().is_empty():
		filter = OS.get_cmdline_user_args()[0]
	var passed := 0
	var failed := 0
	var failures: PackedStringArray = []
	for path in _find_test_files():
		if filter != "" and not path.contains(filter):
			continue
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			failures.append("%s: could not load (parse error?)" % path)
			continue
		var suite := script.new() as GameTestCase
		if suite == null:
			failed += 1
			failures.append("%s: does not extend GameTestCase" % path)
			continue
		suite.name = path.get_file().get_basename()
		root.add_child(suite)
		print("\n%s" % path)
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			LevelCatalog.use_production()  # tests needing the Phase 8 levels switch to development
			RunState.reset()  # every test starts a fresh run (no progression leaks between tests)
			await suite.before_each()
			await suite.call(test_name)
			await suite.after_each()
			var errors := suite.take_failures()
			if errors.is_empty():
				passed += 1
				print("  PASS %s" % test_name)
			else:
				failed += 1
				print("  FAIL %s" % test_name)
				for e in errors:
					print("       - %s" % e)
					failures.append("%s.%s: %s" % [suite.name, test_name, e])
		suite.queue_free()
		await process_frame
	print("\n==== %d passed, %d failed ====" % [passed, failed])
	for f in failures:
		print("FAILED: ", f)
	RunState.clear()  # nothing left in a static at exit
	# With --fixed-fps, frames run faster than real time but the audio thread does not: give
	# it 0.5 s of wall-clock time to release sounds started by the last test, or they are
	# reported as leaked at exit.
	var until := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < until:
		await process_frame
	quit(failed)


func _find_test_files() -> PackedStringArray:
	var files: PackedStringArray = []
	for dir_path in TEST_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.begins_with("test_") and file.ends_with(".gd"):
				files.append(dir_path.path_join(file))
	files.sort()
	return files
